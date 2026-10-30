import { Inject, Injectable, Optional } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { EnvService } from '../../../config/env.service';
import { Principal, roleAtLeast } from '../../../core/auth/principal';
import { NotificationsService } from '../../notifications/application/notifications.service';
import { PremiumAccessService } from '../../premium/application/premium-access.service';
import {
  MARINA_REPOSITORY,
  MarinaCommunity,
  MarinaRepository,
  MyMarinaBoat,
  UpsertMyBoatInput,
} from '../domain/marina.types';

/**
 * Marina Topluluğu iş kuralları (V1 — kurucu onayı 2026-10-23).
 *
 * ERİŞİM (kurucu kararı): SAYILAR herkese; LİSTE şu durumlarda döner —
 * bayrak kapalı / admin+ / bakanın KENDİ marinası (orada kayıtlı teknesi var)
 * / Premium üye. Aksi hâlde access='counts' ve liste istemciye hiç inmez.
 *
 * GİZLİLİK: liste yalnız 'Marinada görün' açık tekneleri taşır; boy/marka
 * shareSpecs rızasına bağlıdır. Bunların tamamı depo SQL'inde uygulanır —
 * arayüz süsü değildir. Doğrulama rozeti YOK: sayılar beyana dayalıdır ve
 * istemci bunu açıkça söyler (uydurma kesinlik sunulmaz).
 */
@Injectable()
export class MarinaService {
  constructor(
    private readonly env: EnvService,
    private readonly premium: PremiumAccessService,
    @Inject(MARINA_REPOSITORY) private readonly repo: MarinaRepository,
    /** Push tetikleri (ateşle-unut) — birim testleri vermez, yol atlanır. */
    @Optional() private readonly notifications?: NotificationsService,
  ) {}

  /** Tekne sekmesindeki Marinam kartının durumu. */
  async myBoat(principal: Principal): Promise<MyMarinaBoat | null> {
    return this.repo.findMyBoat(principal.userId);
  }

  /**
   * Tekneyi kaydet/güncelle + marinaya bağla (topluluğa katılım yolu).
   * Marina KATALOGDAN kimlikle gelir — serbest yazı yok; mükerrer marina
   * kaydı bu tasarımla imkânsızdır (kurucu konsept kararı).
   */
  async upsertMyBoat(principal: Principal, input: UpsertMyBoatInput): Promise<MyMarinaBoat> {
    const marina = await this.repo.marinaInfo(input.marinaLocationId);
    if (marina === null) {
      throw new AppProblem(
        'validation-error',
        'Seçilen yer katalogda yayında olan bir marina değil — listeden bir marina seç.',
        [{ field: 'marinaLocationId', code: 'not_marina', message: 'Marina değil' }],
      );
    }
    if (!(await this.repo.boatTypeValid(input.boatTypeCode))) {
      throw new AppProblem('validation-error', 'Geçersiz tekne tipi.', [
        { field: 'boatTypeCode', code: 'invalid', message: 'Bilinmeyen tip' },
      ]);
    }
    const saved = await this.repo.upsertMyBoat(principal.userId, input);
    // TEKNENİN HİKÂYESİ (0024): kuyruğa düşen metin adminlere duyurulur.
    if (saved.storyStatus === 'pending') this.notifications?.moderationNew('boat_story');
    return saved;
  }

  /**
   * Marina topluluğu: sayılar herkese; liste erişim kuralına göre.
   * Kilit SUNUCUDA: 'counts' yanıtında tekne listesi gövdeye hiç yazılmaz.
   */
  async community(
    principal: Principal | null,
    locationId: string,
    now: Date = new Date(),
  ): Promise<MarinaCommunity> {
    const marina = await this.repo.marinaInfo(locationId);
    if (marina === null) throw new AppProblem('not-found');

    const counts = await this.repo.counts(locationId);

    const full =
      !this.env.premiumEnforce ||
      (principal !== null &&
        !principal.isGuest &&
        (roleAtLeast(principal.role, 'admin') ||
          (await this.repo.isMemberOf(principal.userId, locationId)) ||
          (await this.premium.isPremium(principal.userId, now))));

    return {
      marina,
      total: counts.total,
      visibleCount: counts.visibleCount,
      access: full ? 'full' : 'counts',
      boats: full ? await this.repo.visibleBoats(locationId) : [],
    };
  }
}
