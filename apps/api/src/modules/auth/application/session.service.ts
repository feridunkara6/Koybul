import { Inject, Injectable, Logger } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { uuidv7 } from 'uuidv7';
import { EnvService } from '../../../config/env.service';
import { TokenSigner } from '../../../infrastructure/jwt/token.signer';
import {
  FIREBASE_TOKEN_VERIFIER,
  FirebaseIdentity,
  FirebaseTokenVerifier,
} from '../../../infrastructure/firebase/firebase-token.verifier';
import { JtiBlacklistService } from '../../../infrastructure/redis/jti-blacklist.service';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { RequestMeta, SessionBundle, UserAccount } from '../domain/auth.types';
import { SESSION_REPOSITORY, SessionRepository } from '../domain/session.repository';
import { USER_ACCOUNT_REPOSITORY, UserAccountRepository } from '../domain/user-account.repository';
import { parseModeratorEmails, shouldPromoteToModerator } from '../domain/moderator-allowlist';

const REFRESH_TOKEN_PREFIX = 'rt_';
const REFRESH_TOKEN_BYTES = 32;
/** Hesap başına eşzamanlı oturum (cihaz) tavanı — docs/30 §11. */
const MAX_ACTIVE_FAMILIES = 5;

/**
 * Oturum yaşam döngüsü (docs/23 §3): Firebase köprüsü → RS256 JWT + rotating refresh.
 * Refresh token yalnız SHA-256 hash'iyle saklanır; reuse tespiti tüm aileyi düşürür.
 */
@Injectable()
export class SessionService {
  private readonly logger = new Logger(SessionService.name);
  private readonly refreshTtlMs: number;
  /** MODERATOR_EMAILS — açılışta bir kez ayrıştırılır (her girişte değil). */
  private readonly moderatorEmails: string[];

  constructor(
    @Inject(FIREBASE_TOKEN_VERIFIER) private readonly firebase: FirebaseTokenVerifier,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(USER_ACCOUNT_REPOSITORY) private readonly users: UserAccountRepository,
    private readonly signer: TokenSigner,
    private readonly blacklist: JtiBlacklistService,
    env: EnvService,
  ) {
    this.refreshTtlMs = env.get('REFRESH_TOKEN_TTL_DAYS') * 24 * 60 * 60 * 1000;
    this.moderatorEmails = parseModeratorEmails(env.get('MODERATOR_EMAILS'));
  }

  /** Kayıt + giriş + misafir tek uç (docs/23 §3.4). Yeni oturum = yeni aile. */
  async createSession(firebaseIdToken: string, meta: RequestMeta): Promise<SessionBundle> {
    const identity = await this.firebase.verify(firebaseIdToken);
    const upserted = await this.users.upsertFromIdentity(uuidv7(), identity);
    const account = await this.applyModeratorAllowlist(upserted, identity);
    return this.issueBundle(account, uuidv7(), meta);
  }

  /**
   * MODERATOR_EMAILS listesindeki hesabı, GİRİŞ ANINDA moderatöre yükseltir.
   *
   * Neden burada: rol JWT'nin içine yazılır. Yükseltme token üretilmeden ÖNCE
   * olmazsa kullanıcı bir kez daha çıkıp girmek zorunda kalırdı. Yükseltme
   * veritabanına yazıldığı için sonraki oturumlarda tekrar sorgulanmaz.
   *
   * Yükseltme BAŞARISIZ olursa giriş düşmez: kaptan uygulamaya girebilmeli,
   * yalnız Moderasyon ekranını görmez. Sessiz kalmaz — log'a yazılır.
   */
  private async applyModeratorAllowlist(
    account: UserAccount,
    identity: Pick<FirebaseIdentity, 'email' | 'emailVerified' | 'provider'>,
  ): Promise<UserAccount> {
    if (
      !shouldPromoteToModerator({
        email: identity.email,
        emailVerified: identity.emailVerified,
        provider: identity.provider,
        isGuest: account.isGuest,
        role: account.role,
        list: this.moderatorEmails,
      })
    ) {
      return account;
    }
    try {
      const role = await this.users.promoteToModerator(account.id);
      if (role !== 'moderator') {
        // UPDATE hiçbir satıra dokunmadı (hesap askıya alınmış, silinmiş ya da
        // `roles` tablosu eksik). BAŞARI GİBİ LOGLANMAZ: yetki verildiğini
        // söyleyen bir kayıt, verilmediği hâlde en yanıltıcı iz olurdu.
        this.logger.warn(
          { event: 'server_error', scope: 'moderator_promote', userId: account.id, role },
          'Moderatör yükseltmesi uygulanmadı',
        );
        return account;
      }
      this.logger.log(
        { event: 'role_promoted', userId: account.id, role },
        'Hesap moderatöre yükseltildi (MODERATOR_EMAILS)',
      );
      return { ...account, role };
    } catch (err) {
      this.logger.error(
        { event: 'server_error', scope: 'moderator_promote', userId: account.id, err: String(err) },
        'Moderatör yükseltmesi yapılamadı',
      );
      return account;
    }
  }

  /** Rotating refresh: eski token iptal, yenisi aynı ailede üretilir. */
  async refreshSession(refreshToken: string, meta: RequestMeta): Promise<SessionBundle> {
    const record = await this.sessions.findByTokenHash(this.hash(refreshToken));
    if (!record) {
      throw new AppProblem('invalid-token');
    }
    if (record.revokedAt !== null) {
      // REUSE: bu token zaten döndürülmüş/iptal edilmişti — aile ele geçirilmiş olabilir.
      await this.sessions.revokeFamily(record.familyId, true);
      this.logger.warn(
        { userId: record.userId, familyId: record.familyId },
        'Refresh token reuse tespit edildi — oturum ailesi iptal edildi',
      );
      throw new AppProblem('invalid-token', 'Oturum güvenliği nedeniyle kapatıldı.');
    }
    if (record.expiresAt.getTime() <= Date.now()) {
      await this.sessions.revoke(record.id);
      throw new AppProblem('token-expired');
    }
    const account = await this.users.findActiveById(record.userId);
    if (!account) {
      await this.sessions.revokeFamily(record.familyId, false);
      throw new AppProblem('invalid-token', 'Hesap kullanıma kapalı.');
    }
    await this.sessions.revoke(record.id);
    return this.issueBundle(account, record.familyId, meta, record.id);
  }

  /** Çıkış: sunulan refresh token'ın ailesi düşürülür; idempotenttir. */
  async logout(refreshToken: string): Promise<void> {
    const record = await this.sessions.findByTokenHash(this.hash(refreshToken));
    if (record) {
      await this.sessions.revokeFamily(record.familyId, false);
    }
  }

  /** Tüm cihazlardan çıkış (docs/23 §3.4). */
  async logoutAll(userId: string): Promise<void> {
    await this.sessions.revokeAllForUser(userId);
  }

  /**
   * Acil sonlandırma (hesap silme/askıya alma): tüm refresh aileleri iptal edilir
   * ve yaşayan access token'lar jti karalistesine alınır (docs/24 §7.2).
   */
  async terminateUser(userId: string): Promise<void> {
    const activeIds = await this.sessions.listActiveSessionIds(userId);
    await this.sessions.revokeAllForUser(userId);
    await Promise.all(activeIds.map((jti) => this.blacklist.block(jti, this.signer.accessTtlSec)));
  }

  private async issueBundle(
    account: UserAccount,
    familyId: string,
    meta: RequestMeta,
    rotatedFromId?: string,
  ): Promise<SessionBundle> {
    // 5 cihaz tavanı: yeni aile açılıyorsa ve tavan doluysa en eski aile düşürülür.
    if (!rotatedFromId) {
      const activeFamilies = await this.sessions.countActiveFamilies(account.id);
      if (activeFamilies >= MAX_ACTIVE_FAMILIES) {
        const oldest = await this.sessions.findOldestActiveFamilyId(account.id);
        if (oldest) {
          await this.sessions.revokeFamily(oldest, false);
        }
      }
    }
    const sessionId = uuidv7();
    const refreshToken =
      REFRESH_TOKEN_PREFIX + randomBytes(REFRESH_TOKEN_BYTES).toString('base64url');
    await this.sessions.create({
      id: sessionId,
      userId: account.id,
      familyId,
      tokenHash: this.hash(refreshToken),
      expiresAt: new Date(Date.now() + this.refreshTtlMs),
      rotatedFromId,
      ip: meta.ip,
      userAgent: meta.userAgent,
    });
    const principal: Principal = {
      userId: account.id,
      role: account.role,
      isGuest: account.isGuest,
      familyId,
      jti: sessionId,
    };
    return {
      accessToken: await this.signer.signAccess(principal),
      expiresIn: this.signer.accessTtlSec,
      refreshToken,
      user: {
        id: account.id,
        role: account.role,
        isGuest: account.isGuest,
        locale: account.locale,
      },
    };
  }

  private hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
