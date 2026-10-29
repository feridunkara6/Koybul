import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { uuidv7 } from 'uuidv7';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { DeletionAudit, UserRepository } from '../domain/user.repository';
import {
  CaptainContribution,
  FollowedCaptain,
  PublicCaptain,
  UpdateMeInput,
  UserMe,
} from '../domain/user.types';
import { RoleCode } from '../../../core/auth/principal';

const ANONYMIZED_DISPLAY_NAME = 'Silinmiş Kullanıcı';
const DEFAULT_DISPLAY_NAME = 'Kaptan';

type UserWithRelations = Prisma.UserGetPayload<{
  include: { role: true; profile: true; settings: true };
}>;

@Injectable()
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string): Promise<UserMe | null> {
    return this.prisma.withUserContext(userId, async (tx) => {
      const user = await tx.user.findFirst({
        where: { id: userId, deletedAt: null },
        include: { role: true, profile: true, settings: true },
      });
      if (!user) return null;

      // Lazy init: ilk erişimde varsayılan profil/ayar satırları oluşturulur.
      // Rıza zamanları kayıt anındaki kabule dayanır (S-03 KVKK metni — docs/21).
      if (!user.profile) {
        await tx.userProfile.create({
          data: { userId, displayName: this.defaultDisplayName(userId) },
        });
      }
      if (!user.settings) {
        const now = new Date();
        await tx.userSetting.create({
          data: { userId, termsAcceptedAt: now, privacyAcceptedAt: now },
        });
      }
      if (!user.profile || !user.settings) {
        const fresh = await tx.user.findUniqueOrThrow({
          where: { id: userId },
          include: { role: true, profile: true, settings: true },
        });
        return this.toMe(fresh);
      }
      return this.toMe(user);
    });
  }

  /**
   * HERKESE AÇIK kaptan kartı (Hafta 1B). Kullanıcı bağlamı KULLANILMAZ:
   * okuma kamuya açıktır ve uygulama katmanı birincil yetkidir (ADR-003,
   * notlar deposundaki desenle aynı). PII seçilmez — select listesi kart
   * modeliyle birebir sınırlıdır.
   */
  async getPublic(userId: string): Promise<PublicCaptain | null> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null, status: 'active' },
      select: {
        id: true,
        createdAt: true,
        profile: {
          select: { displayName: true, bio: true, experienceYears: true },
        },
        reputation: {
          select: {
            points: true,
            levelCode: true,
            approvedCount: true,
            helpfulReceived: true,
          },
        },
        badges: {
          where: { revokedAt: null },
          select: { badgeCode: true },
          orderBy: { awardedAt: 'asc' },
        },
        // TAKİPÇİ SAYISI (SP-3a, 2026-10-31) — kartta herkese açık.
        _count: { select: { followers: true } },
      },
    });
    if (!user) return null;
    // SON KATKILAR vitrini (SP-1 Kimlik, 2026-10-29): yalnız ONAYLI ve
    // silinmemiş içerik; iki küçük sorgu (ağır birleşim yok), en yeni önce.
    const noteRows = await this.prisma.$queryRaw<
      { title: string | null; noteKind: string; createdAt: Date }[]
    >`
      SELECT l.name AS "title", n.kind::text AS "noteKind", n.created_at AS "createdAt"
      FROM location_notes n
      LEFT JOIN locations l ON l.id = n.location_id
      WHERE n.user_id = ${userId}::uuid
        AND n.status = 'approved' AND n.deleted_at IS NULL
      ORDER BY n.created_at DESC
      LIMIT 3`;
    const routeRows = await this.prisma.route.findMany({
      where: { userId, status: 'approved', deletedAt: null },
      orderBy: { createdAt: 'desc' },
      take: 2,
      select: { name: true, saveCount: true, createdAt: true },
    });
    const recent: CaptainContribution[] = [
      ...noteRows.map((n) => ({
        kind: 'note' as const,
        title: n.title,
        noteKind: n.noteKind,
        savedCount: null,
        createdAt: n.createdAt.toISOString(),
      })),
      ...routeRows.map((r) => ({
        kind: 'route' as const,
        title: r.name,
        noteKind: null,
        savedCount: r.saveCount,
        createdAt: r.createdAt.toISOString(),
      })),
    ]
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, 4);
    return {
      id: user.id,
      displayName: user.profile?.displayName ?? DEFAULT_DISPLAY_NAME,
      bio: user.profile?.bio ?? null,
      experienceYears: user.profile?.experienceYears ?? null,
      memberSince: user.createdAt.toISOString(),
      points: user.reputation?.points ?? 0,
      levelCode: user.reputation?.levelCode ?? 'new',
      approvedCount: user.reputation?.approvedCount ?? 0,
      helpfulReceived: user.reputation?.helpfulReceived ?? 0,
      badges: user.badges.map((b) => b.badgeCode),
      followerCount: user._count.followers,
      recentContributions: recent,
    };
  }

  // --- TAKİP (SP-3a, kurucu onayı 2026-10-31) ---

  async userExists(userId: string): Promise<boolean> {
    const n = await this.prisma.user.count({
      where: { id: userId, deletedAt: null, status: 'active' },
    });
    return n > 0;
  }

  async follow(followerId: string, followedId: string): Promise<void> {
    // RLS: yazma kullanıcı bağlamıyla (satır sahibi = takip eden).
    await this.prisma.withUserContext(followerId, async (tx) => {
      await tx.$executeRaw`
        INSERT INTO user_follows (follower_id, followed_id)
        VALUES (${followerId}::uuid, ${followedId}::uuid)
        ON CONFLICT (follower_id, followed_id) DO NOTHING
      `;
    });
  }

  async unfollow(followerId: string, followedId: string): Promise<void> {
    await this.prisma.withUserContext(followerId, async (tx) => {
      await tx.$executeRaw`
        DELETE FROM user_follows
        WHERE follower_id = ${followerId}::uuid AND followed_id = ${followedId}::uuid
      `;
    });
  }

  async following(userId: string): Promise<FollowedCaptain[]> {
    // Ad/seviye kart diliyle aynı kaynaktan; silinmiş hesap listeden düşer.
    const rows = await this.prisma.$queryRaw<
      { id: string; displayName: string | null; levelCode: string | null }[]
    >`
      SELECT u.id::text AS id, up.display_name AS "displayName",
             ur.level_code::text AS "levelCode"
      FROM user_follows f
      JOIN users u ON u.id = f.followed_id
        AND u.deleted_at IS NULL AND u.status = 'active'
      LEFT JOIN user_profiles up ON up.user_id = u.id
      LEFT JOIN user_reputation ur ON ur.user_id = u.id
      WHERE f.follower_id = ${userId}::uuid
      ORDER BY f.created_at DESC
      LIMIT 200
    `;
    return rows.map((r) => ({
      id: r.id,
      displayName: r.displayName ?? DEFAULT_DISPLAY_NAME,
      levelCode: r.levelCode ?? 'new',
    }));
  }

  async updateMe(userId: string, patch: UpdateMeInput): Promise<UserMe> {
    await this.prisma.withUserContext(userId, async (tx) => {
      if (patch.locale !== undefined) {
        await tx.user.update({ where: { id: userId }, data: { locale: patch.locale } });
      }
      if (patch.profile) {
        const p = patch.profile;
        await tx.userProfile.update({
          where: { userId },
          data: {
            ...(p.displayName !== undefined ? { displayName: p.displayName } : {}),
            ...(p.fullName !== undefined ? { fullName: p.fullName } : {}),
            ...(p.bio !== undefined ? { bio: p.bio } : {}),
            ...(p.experienceYears !== undefined ? { experienceYears: p.experienceYears } : {}),
          },
        });
      }
      if (patch.settings) {
        const s = patch.settings;
        await tx.userSetting.update({
          where: { userId },
          data: {
            ...(s.theme !== undefined ? { theme: s.theme === 'system' ? null : s.theme } : {}),
            ...(s.units !== undefined ? { units: s.units } : {}),
            ...(s.marketingConsent !== undefined
              ? { marketingConsentAt: s.marketingConsent ? new Date() : null }
              : {}),
          },
        });
      }
    });
    const me = await this.getMe(userId);
    if (!me) {
      // updateMe yalnız guard'lı akıştan çağrılır; satır silinmişse tutarsızlıktır.
      throw new Error('Kullanıcı güncelleme sonrası okunamadı');
    }
    return me;
  }

  async softDeleteAndAnonymize(userId: string, audit: DeletionAudit): Promise<void> {
    const now = new Date();
    await this.prisma.withUserContext(userId, async (tx) => {
      await tx.userProfile.upsert({
        where: { userId },
        create: { userId, displayName: ANONYMIZED_DISPLAY_NAME },
        update: {
          displayName: ANONYMIZED_DISPLAY_NAME,
          fullName: null,
          bio: null,
          avatarMediaId: null,
          homePortLocationId: null,
          experienceYears: null,
        },
      });
      await tx.userSetting.updateMany({
        where: { userId },
        data: { marketingConsentAt: null },
      });
      await tx.userDevice.deleteMany({ where: { userId } });
      await tx.user.update({
        where: { id: userId },
        data: {
          status: 'deleted',
          deletedAt: now,
          deletedBy: userId,
          email: null,
          emailVerifiedAt: null,
          phone: null,
          phoneVerifiedAt: null,
          // Tombstone: unique alan serbest kalır — aynı kişi dönerse YENİ hesap açılır
          // (gizlilik: silinen hesapla ilişki kurulamaz; docs/22 §1.5).
          firebaseUid: `del_${uuidv7()}`,
        },
      });
      await tx.auditLog.create({
        data: {
          occurredAt: now,
          actorType: 'user',
          actorUserId: userId,
          action: 'user.delete',
          entityType: 'user',
          entityId: userId,
          ip: audit.ip,
          requestId: audit.requestId,
        },
      });
    });
  }

  private toMe(user: UserWithRelations): UserMe {
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role.code as RoleCode,
      isGuest: user.isGuest,
      locale: user.locale,
      countryCode: user.countryCode,
      createdAt: user.createdAt.toISOString(),
      profile: {
        displayName: user.profile?.displayName ?? DEFAULT_DISPLAY_NAME,
        fullName: user.profile?.fullName ?? null,
        bio: user.profile?.bio ?? null,
        experienceYears: user.profile?.experienceYears ?? null,
      },
      settings: {
        theme: (user.settings?.theme ?? 'system') as UserMe['settings']['theme'],
        units: (user.settings?.units ?? 'metric') as UserMe['settings']['units'],
        marketingConsent: user.settings?.marketingConsentAt != null,
      },
    };
  }

  /**
   * Varsayılan görünen ad — E-POSTADAN TÜRETİLMEZ.
   *
   * Eskiden e-postanın yerel kısmı kullanılıyordu: `ahmet.yilmaz@gmail.com`
   * ile giren kaptanın adı her notunun ve yorumunun yanında "ahmet.yilmaz"
   * olarak HERKESE görünüyordu — kullanıcı hiç sorulmadan, üstelik yaygın
   * alan adı tahmin edilerek adresi geri bulunabilecek şekilde. KVKK
   * açısından açık bir sorun (denetim bulgusu 2026-08, Faz 0).
   *
   * Yerine: "Kaptan" + kullanıcı kimliğinden türeyen kısa, kararlı bir sonek.
   * Sonek kişisel veri DEĞİLDİR (kimliğin rastgele parçası) ve `authorId`
   * olarak yanıtlarda zaten görünür; ama iki kaptanı birbirinden ayırmaya
   * yetiyor, yani topluluk ve moderasyon kullanılabilir kalıyor.
   *
   * SON dört hane alınır, İLK dört değil: kimlikler uuidv7'dir ve onun ilk
   * 12 hanesi ZAMAN DAMGASIDIR — baştan dört hane yaklaşık 50 günde bir
   * değişir, yani aynı dönemde kaydolan herkes "Kaptan 019F" olurdu
   * (inceleme bulgusu 2026-08). Son haneler rastgele bölümden gelir.
   */
  private defaultDisplayName(userId: string): string {
    const suffix = userId.replace(/-/g, '').slice(-4).toUpperCase();
    return suffix.length === 4 ? `${DEFAULT_DISPLAY_NAME} ${suffix}` : DEFAULT_DISPLAY_NAME;
  }
}
