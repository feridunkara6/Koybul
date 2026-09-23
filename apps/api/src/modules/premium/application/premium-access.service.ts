import { Inject, Injectable } from '@nestjs/common';
import { EnvService } from '../../../config/env.service';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { PREMIUM_REPOSITORY, PremiumRepository } from '../domain/premium.repository';

/**
 * Keşif hakkı aylık tavanı (kurucu onayı 2026-09-21, premium v3 raporu K2):
 * ücretsiz ÜYE her takvim ayında 3 koyu tam açabilir.
 */
export const EXPLORATION_MONTHLY_LIMIT = 3;

/** Detay erişim düzeyi: 'full' = tam veri, 'teaser' = vitrin (kilitli). */
export type DetailAccess = 'full' | 'teaser';

/** Erişim kararı + (üye-teaser durumunda) kalan keşif hakkı. */
export interface AccessDecision {
  access: DetailAccess;
  /**
   * Kalan keşif hakkı — YALNIZ hesaplı (misafir olmayan) ve teaser gören
   * kullanıcıda dolar; anonim/misafir/premium/tam-erişimde null. Mobil, kilit
   * ekranındaki "Keşif hakkınla aç (2 kaldı)" satırını bununla çizer.
   */
  explorationRemaining: number | null;
}

/**
 * Premium erişim kararları (P1). Kilit SUNUCUDAN zorlanır: karar burada verilir,
 * kilitli veri istemciye hiç inmez (premium v3 raporu §9). PREMIUM_ENFORCE
 * kapalıyken her istek 'full' — bugünkü davranış birebir korunur.
 */
@Injectable()
export class PremiumAccessService {
  constructor(
    private readonly env: EnvService,
    @Inject(PREMIUM_REPOSITORY) private readonly repo: PremiumRepository,
  ) {}

  /**
   * Bayrak açık mı? (P5) Kilitli okuma uçları (yorumlar, notlar) pahalı erişim
   * kararına girmeden önce buna bakar — bayrak kapalıyken sıfır ek sorgu.
   */
  get enforced(): boolean {
    return this.env.premiumEnforce;
  }

  /** UTC takvim ayı anahtarı: 'YYYY-MM'. Sunucu saati esastır. */
  static monthKey(now: Date = new Date()): string {
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, '0');
    return `${y}-${m}`;
  }

  /** premiumUntil gelecekte mi? (Apple yansıması — P2 bu alanı canlı tutar.) */
  async isPremium(userId: string, now: Date = new Date()): Promise<boolean> {
    const until = await this.repo.findPremiumUntil(userId);
    return until !== null && until.getTime() > now.getTime();
  }

  /**
   * Bir lokasyon detayı için erişim kararı.
   * Sıra: bayrak kapalı → full; kimliksiz → teaser; premium → full;
   * hesaplı üye + bu ay bu koyu açmış → full; aksi halde teaser (+ kalan hak).
   * Misafir (anonim Firebase) oturum hesap SAYILMAZ — keşif hakkı üyeliğe bağlı.
   */
  async accessFor(
    principal: Principal | null | undefined,
    locationId: string,
    now: Date = new Date(),
  ): Promise<AccessDecision> {
    if (!this.env.premiumEnforce) return { access: 'full', explorationRemaining: null };
    if (!principal) return { access: 'teaser', explorationRemaining: null };

    if (await this.isPremium(principal.userId, now)) {
      return { access: 'full', explorationRemaining: null };
    }
    if (principal.isGuest) return { access: 'teaser', explorationRemaining: null };

    const month = PremiumAccessService.monthKey(now);
    if (await this.repo.hasUnlock(principal.userId, locationId, month)) {
      return { access: 'full', explorationRemaining: null };
    }
    const used = await this.repo.countUnlocks(principal.userId, month);
    return {
      access: 'teaser',
      explorationRemaining: Math.max(0, EXPLORATION_MONTHLY_LIMIT - used),
    };
  }

  /**
   * Keşif hakkı kullan (POST /locations/:idOrSlug/unlock arkası).
   * Premium kullanıcıda hak TÜKETİLMEZ (zaten tam erişimi var). Aynı koyu aynı
   * ay yeniden açmak da tüketmez. Tavan dolunca 'quota-exceeded' problemi (403)
   * fırlar — mobil bu tipe paywall gösterir.
   */
  async unlock(
    principal: Principal,
    locationId: string,
    now: Date = new Date(),
  ): Promise<{ remaining: number }> {
    if (await this.isPremium(principal.userId, now)) {
      return { remaining: 0 };
    }
    const month = PremiumAccessService.monthKey(now);
    const result = await this.repo.createUnlock(
      principal.userId,
      locationId,
      month,
      EXPLORATION_MONTHLY_LIMIT,
    );
    if (result === 'quota') {
      throw new AppProblem(
        'quota-exceeded',
        'Bu ayın keşif hakları doldu. Gelecek ay 3 yeni hakkın olacak — ya da Premium ile tüm koylar sınırsız açık.',
      );
    }
    const used = await this.repo.countUnlocks(principal.userId, month);
    return { remaining: Math.max(0, EXPLORATION_MONTHLY_LIMIT - used) };
  }
}
