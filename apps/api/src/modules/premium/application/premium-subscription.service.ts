import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { Principal, roleAtLeast } from '../../../core/auth/principal';
import {
  APPLE_SUBSCRIPTION_GATEWAY,
  AppleSubscriptionGateway,
  AppleSubscriptionState,
} from '../domain/apple.types';
import { decodeJwsPayload } from '../domain/jws';
import { PREMIUM_REPOSITORY, PremiumRepository } from '../domain/premium.repository';
import { EXPLORATION_MONTHLY_LIMIT, PremiumAccessService } from './premium-access.service';

/** GET /premium/me gövdesi — mobil profil/paket ekranlarının tek kaynağı. */
export interface PremiumMe {
  premium: { active: boolean; until: string | null; productId: string | null };
  exploration: { remaining: number; limit: number; monthKey: string };
}

/**
 * Apple abonelik yönetimi (P2, kurucu onayı 2026-09-21).
 *
 * AKIŞ: mobil satın alma/geri yükleme sonrası originalTransactionId'yi
 * /premium/apple/link'e gönderir → durum APPLE'DAN sorulur → hesaba yazılır.
 * App Store bildirimleri (/premium/apple/notifications) yalnız TETİKTİR:
 * içinden id çıkar, durum yine Apple'dan sorulur (domain/jws.ts güvenlik
 * modeli). İstemcinin beyanına hiçbir yerde güvenilmez.
 */
@Injectable()
export class PremiumSubscriptionService {
  private readonly logger = new Logger(PremiumSubscriptionService.name);

  constructor(
    @Inject(PREMIUM_REPOSITORY) private readonly repo: PremiumRepository,
    @Inject(APPLE_SUBSCRIPTION_GATEWAY) private readonly apple: AppleSubscriptionGateway,
  ) {}

  /** Profil/paket ekranı durumu. */
  async me(principal: Principal, now: Date = new Date()): Promise<PremiumMe> {
    const sub = await this.repo.findSubscription(principal.userId);
    const monthKey = PremiumAccessService.monthKey(now);
    const used = await this.repo.countUnlocks(principal.userId, monthKey);
    // YÖNETİCİ = PREMIUM (kurucu talebi 2026-09-25): erişim kararıyla aynı
    // kural (premium-access.service). Tarih yazılmaz — rol sürdükçe etkindir.
    const roleActive = roleAtLeast(principal.role, 'admin');
    return {
      premium: {
        active:
          roleActive || (sub.premiumUntil !== null && sub.premiumUntil.getTime() > now.getTime()),
        until: sub.premiumUntil?.toISOString() ?? null,
        productId: sub.productId,
      },
      exploration: {
        remaining: Math.max(0, EXPLORATION_MONTHLY_LIMIT - used),
        limit: EXPLORATION_MONTHLY_LIMIT,
        monthKey,
      },
    };
  }

  /**
   * Satın alma / geri yükleme sonrası abonelik-hesap bağlama.
   * Kurallar: (1) durum Apple'dan doğrulanır, beyana güvenilmez;
   * (2) bir abonelik TEK hesaba bağlanır — başka hesaba bağlıysa 409;
   * (3) bitmiş abonelik de bağlanabilir (geri yükleme dürüstlüğü) ama
   * premium vermez — yanıt gerçek durumu söyler.
   */
  async link(
    principal: Principal,
    originalTransactionId: string,
  ): Promise<{ active: boolean; until: string | null; productId: string | null }> {
    if (!this.apple.configured) {
      throw new AppProblem('service-unavailable', 'Abonelik doğrulama henüz yapılandırılmadı.');
    }

    const state = await this.apple.fetchState(originalTransactionId);
    if (!state) {
      throw new AppProblem('validation-error', 'Apple bu abonelik işlemini tanımadı.', [
        {
          field: 'originalTransactionId',
          code: 'unknown_transaction',
          message: 'Abonelik Apple tarafında bulunamadı.',
        },
      ]);
    }

    const owner = await this.repo.findUserIdByOriginalTransactionId(originalTransactionId);
    if (owner !== null && owner !== principal.userId) {
      throw new AppProblem(
        'conflict-state',
        'Bu abonelik başka bir Koybul hesabına bağlı. Aboneliğin sahibi o hesapla giriş yapıp "Satın alımları geri yükle" demeli.',
      );
    }

    await this.saveState(principal.userId, state);
    return {
      active: state.entitled,
      until: state.expiresAt?.toISOString() ?? null,
      productId: state.productId,
    };
  }

  /**
   * App Store Server Notification V2 işleyici. HER ZAMAN sessizce başarılıdır
   * (Apple 2xx dışında yeniden dener); işlenemeyen gövde loglanır ve geçilir.
   * Dönen değer yalnız test edilebilirlik içindir.
   */
  async handleNotification(body: unknown): Promise<'updated' | 'ignored'> {
    if (!this.apple.configured) return 'ignored';

    const signedPayload =
      typeof body === 'object' && body !== null && 'signedPayload' in body
        ? (body as { signedPayload: unknown }).signedPayload
        : null;
    if (typeof signedPayload !== 'string') return 'ignored';

    const payload = decodeJwsPayload(signedPayload);
    const data =
      typeof payload?.data === 'object' && payload.data !== null
        ? (payload.data as Record<string, unknown>)
        : null;
    const txInfo =
      typeof data?.signedTransactionInfo === 'string'
        ? decodeJwsPayload(data.signedTransactionInfo)
        : null;
    const originalTransactionId =
      typeof txInfo?.originalTransactionId === 'string' ? txInfo.originalTransactionId : null;
    if (!originalTransactionId) return 'ignored';

    const userId = await this.repo.findUserIdByOriginalTransactionId(originalTransactionId);
    if (!userId) return 'ignored'; // Henüz hiçbir hesaba bağlanmamış — link bekler.

    // Gerçek durum HER ZAMAN Apple'dan (bildirim gövdesine güvenilmez).
    const state = await this.apple.fetchState(originalTransactionId);
    if (!state) return 'ignored';

    await this.saveState(userId, state);
    this.logger.log({
      event: 'apple_subscription_updated',
      appleStatus: state.appleStatus,
      entitled: state.entitled,
    });
    return 'updated';
  }

  private async saveState(userId: string, state: AppleSubscriptionState): Promise<void> {
    await this.repo.saveSubscription(userId, {
      // Hak yoksa premiumUntil bitiş tarihi (geçmiş) olarak yazılır: "eski
      // abone" izi kalır, kayıtlar salt-okunur korunur (rapor §3 kutu).
      premiumUntil: state.expiresAt,
      productId: state.productId,
      originalTransactionId: state.originalTransactionId,
    });
  }
}
