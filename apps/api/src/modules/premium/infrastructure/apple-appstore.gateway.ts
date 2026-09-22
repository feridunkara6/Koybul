import { Injectable, Logger } from '@nestjs/common';
import { SignJWT, importPKCS8, KeyLike } from 'jose';
import { EnvService } from '../../../config/env.service';
import { AppProblem } from '../../../common/problem/problem';
import { AppleSubscriptionGateway, AppleSubscriptionState } from '../domain/apple.types';
import { decodeJwsPayload } from '../domain/jws';

/** App Store Server API taban adresleri (Apple dokümanı). */
const BASE_URL = {
  production: 'https://api.storekit.itunes.apple.com',
  sandbox: 'https://api.storekit-sandbox.itunes.apple.com',
} as const;

/** API JWT ömrü — Apple en fazla 60 dk kabul eder; kısa tutulur. */
const TOKEN_TTL_SEC = 300;

/** Erişim hakkı veren Apple durumları: 1 = aktif, 4 = fatura grace dönemi. */
const ENTITLED_STATUSES = new Set([1, 4]);

/**
 * App Store Server API istemcisi (P2, kurucu onayı 2026-09-21).
 *
 * TEK GÜVEN KAYNAĞI budur: premium yazan her yol durumu buradan sorar
 * (bkz. domain/jws.ts güvenlik modeli). ES256 JWT, projedeki mevcut `jose`
 * ile imzalanır — yeni bağımlılık yok. Yapılandırma yoksa `configured=false`;
 * fetchState çağrılırsa 503 (uçlar zaten çağırmadan 503 döner).
 */
@Injectable()
export class AppleAppStoreGateway implements AppleSubscriptionGateway {
  private readonly logger = new Logger(AppleAppStoreGateway.name);
  private readonly cfg: EnvService['appleIap'];
  private key: KeyLike | null = null;

  constructor(env: EnvService) {
    this.cfg = env.appleIap;
  }

  get configured(): boolean {
    return this.cfg !== null;
  }

  async fetchState(originalTransactionId: string): Promise<AppleSubscriptionState | null> {
    const cfg = this.cfg;
    if (!cfg) {
      throw new AppProblem('service-unavailable', 'Abonelik doğrulama henüz yapılandırılmadı.');
    }

    const token = await this.signApiToken(cfg);
    const url = `${BASE_URL[cfg.environment]}/inApps/v1/subscriptions/${encodeURIComponent(
      originalTransactionId,
    )}`;
    const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });

    if (res.status === 404) return null; // Apple bu işlemi tanımıyor.
    if (!res.ok) {
      // 401 (anahtar), 429 (hız), 5xx — hepsi bizim değil Apple/yapılandırma
      // sorunudur; kullanıcıya dürüst 503, loga ayrıntı.
      this.logger.error({ status: res.status, event: 'apple_api_error' });
      throw new AppProblem(
        'service-unavailable',
        'Apple abonelik servisine şu an ulaşılamıyor; birazdan tekrar deneyin.',
      );
    }

    const body = (await res.json()) as {
      data?: {
        lastTransactions?: {
          originalTransactionId?: string;
          status?: number;
          signedTransactionInfo?: string;
        }[];
      }[];
    };

    // P3 notu: Apple bu uca HERHANGİ bir işlem kimliğiyle sorulmayı destekler
    // (istemci ilk satın almada türev transactionId gönderebilir). Yanıttaki
    // originalTransactionId KANONİK kimliktir ve veritabanına O yazılır; eşleşme
    // varsa tercih edilir, yoksa ilk kayıt kullanılır (yanıt zaten bu aboneye aittir).
    let fallback: AppleSubscriptionState | null = null;
    for (const group of body.data ?? []) {
      for (const t of group.lastTransactions ?? []) {
        const info = t.signedTransactionInfo ? decodeJwsPayload(t.signedTransactionInfo) : null;
        const canonical =
          typeof t.originalTransactionId === 'string'
            ? t.originalTransactionId
            : typeof info?.originalTransactionId === 'string'
              ? info.originalTransactionId
              : originalTransactionId;
        const expiresMs = typeof info?.expiresDate === 'number' ? info.expiresDate : null;
        const status = typeof t.status === 'number' ? t.status : 0;
        const state: AppleSubscriptionState = {
          originalTransactionId: canonical,
          productId: typeof info?.productId === 'string' ? info.productId : null,
          // Bitiş tarihi ÇÖZÜLEMEDİYSE hak da verilmez: premiumUntil'siz
          // "aktif" yazmak tutarsız durum üretir (uydurma tarih de yazılmaz).
          entitled: ENTITLED_STATUSES.has(status) && expiresMs !== null,
          appleStatus: status,
          expiresAt: expiresMs !== null ? new Date(expiresMs) : null,
        };
        if (canonical === originalTransactionId) return state;
        fallback ??= state;
      }
    }
    return fallback;
  }

  /** ES256 App Store Server API JWT'si (aud sabit, bid = uygulama kimliği). */
  private async signApiToken(cfg: NonNullable<EnvService['appleIap']>): Promise<string> {
    this.key ??= await importPKCS8(cfg.privateKeyP8, 'ES256');
    const now = Math.floor(Date.now() / 1000);
    return new SignJWT({ bid: cfg.bundleId })
      .setProtectedHeader({ alg: 'ES256', kid: cfg.keyId, typ: 'JWT' })
      .setIssuer(cfg.issuerId)
      .setIssuedAt(now)
      .setExpirationTime(now + TOKEN_TTL_SEC)
      .setAudience('appstoreconnect-v1')
      .sign(this.key);
  }
}
