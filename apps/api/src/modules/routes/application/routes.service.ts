import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from 'uuidv7';
import { AppProblem } from '../../../common/problem/problem';
import { EnvService } from '../../../config/env.service';
import { Principal, roleAtLeast } from '../../../core/auth/principal';
import { PremiumAccessService } from '../../premium/application/premium-access.service';
import {
  CreateRouteInput,
  ROUTE_FREE_MONTHLY_LIMIT,
  ROUTE_STOPS_MAX,
  ROUTE_STOPS_MIN,
  ROUTES_REPOSITORY,
  RouteDetail,
  RouteRow,
  RouteSort,
  RouteSummary,
  RoutesRepository,
} from '../domain/route.types';

/** Listeye eklenen "kendi bekleyenlerim" tavanı — liste şişmez. */
const OWN_PENDING_LIMIT = 5;

/**
 * ROTA PAYLAŞIMI iş kuralları (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24).
 *
 * - OKUMA herkese açık (S-C akışı gibi): liste + onaylı detay kimliksiz.
 * - YAZMA hesap ister; her rota MODERASYON onayından geçer (pending doğar) —
 *   yorumlarla aynı katılık: rota tavsiyesi emniyet içeriğidir.
 * - Ücretsiz tavan: ayda ROUTE_FREE_MONTHLY_LIMIT rota (bayrak açıkken;
 *   admin+ ve Premium muaf) — plan §10 "topluluğun temeli ücretsiz" dengesi.
 * - İtibar puanı BİLİNÇLİ yok (S-C ile aynı karar) — V2'de değerlendirilir.
 */
@Injectable()
export class RoutesService {
  constructor(
    private readonly env: EnvService,
    private readonly premium: PremiumAccessService,
    @Inject(ROUTES_REPOSITORY) private readonly repo: RoutesRepository,
  ) {}

  private toSummary(row: RouteRow): RouteSummary {
    return {
      id: row.id,
      name: row.name,
      authorId: row.userId,
      authorName: row.authorName ?? 'Koybul Kaptanı',
      startName: row.startName ?? '—',
      endName: row.endName ?? '—',
      stopCount: Number(row.stopCount),
      distanceNm: Number(row.distanceNm),
      durationHours: row.durationHours === null ? null : Number(row.durationHours),
      season: row.season,
      saveCount: row.saveCount,
      doneCount: row.doneCount,
      createdAt: row.createdAt.toISOString(),
      status: row.status,
    };
  }

  /**
   * Keşif listesi — herkese açık; yalnız onaylı rotalar. Kimlik GELDİYSE
   * bakanın KENDİ bekleyen rotaları listenin BAŞINA eklenir (saha isteği
   * 2026-10-27: "paylaştım ama görünmüyor") — başkasının bekleyeni asla
   * sızmaz, rozet için durum alanı dolu döner.
   */
  async list(
    principal: Principal | null,
    sort: RouteSort,
    locationId: string | null,
    limit: number,
  ): Promise<RouteSummary[]> {
    const rows = await this.repo.list(sort, locationId, limit);
    const approved = rows.map((r) => this.toSummary(r));
    // Koy süzgeçli liste ("buradan geçen rotalar") bekleyen TAŞIMAZ — bekleyen
    // rota durak bilgisiyle eşlenmeden her koyda görünürdü (yanlış temsil).
    if (principal === null || locationId !== null) return approved;
    const own = await this.repo.listOwnPending(principal.userId, OWN_PENDING_LIMIT);
    return [...own.map((r) => this.toSummary(r)), ...approved];
  }

  /** Detay — onaylı herkese; bekleyen yalnız sahibine (varlık sızdırılmaz). */
  async detail(principal: Principal | null, routeId: string): Promise<RouteDetail> {
    const row = await this.repo.findRoute(routeId);
    if (!row || row.status === 'rejected') throw new AppProblem('not-found');

    const mine = principal !== null && principal.userId === row.userId;
    if (row.status === 'pending' && !mine) throw new AppProblem('not-found');

    const viewerId = principal?.userId ?? null;
    const [stops, savedByMe, doneByMe] = await Promise.all([
      this.repo.stopsFor(routeId),
      viewerId ? this.repo.savedBy(routeId, viewerId) : Promise.resolve(false),
      viewerId ? this.repo.doneBy(routeId, viewerId) : Promise.resolve(false),
    ]);

    return {
      ...this.toSummary(row),
      body: row.body,
      boatSuggestion: row.boatSuggestion,
      status: row.status,
      stops,
      mine,
      savedByMe,
      doneByMe,
    };
  }

  /** Rota paylaşma — durak doğrulaması + aylık tavan + moderasyon kuyruğu. */
  async create(
    principal: Principal,
    input: CreateRouteInput,
    now: Date = new Date(),
  ): Promise<{ id: string; status: string }> {
    const stops = input.stopLocationIds;
    if (stops.length < ROUTE_STOPS_MIN || stops.length > ROUTE_STOPS_MAX) {
      throw new AppProblem(
        'validation-error',
        `Rota ${ROUTE_STOPS_MIN}-${ROUTE_STOPS_MAX} durak içermeli.`,
        [{ field: 'stopLocationIds', code: 'stop_count', message: 'Durak sayısı aralık dışı' }],
      );
    }
    // Ardışık tekrar anlamsızdır (Göcek→Göcek bacağı); gidiş-dönüşte baş/son
    // aynı olabilir — yalnız YAN YANA tekrar reddedilir.
    for (let i = 1; i < stops.length; i++) {
      if (stops[i] === stops[i - 1]) {
        throw new AppProblem('validation-error', 'Ardışık iki durak aynı olamaz.', [
          { field: 'stopLocationIds', code: 'repeated_stop', message: `Sıra ${i + 1}` },
        ]);
      }
    }
    // Duraklar katalogda YAYINDA olmalı — silinmiş/taslak koya rota yazılmaz.
    const published = await this.repo.publishedLocationCount([...new Set(stops)]);
    if (published !== new Set(stops).size) {
      throw new AppProblem('validation-error', 'Duraklardan bazıları katalogda bulunamadı.', [
        { field: 'stopLocationIds', code: 'unknown_location', message: 'Geçersiz durak' },
      ]);
    }

    // AYLIK TAVAN (bayrak açıkken): ücretsiz üye ayda 2 rota; admin+/Premium muaf.
    if (this.env.premiumEnforce && !roleAtLeast(principal.role, 'admin')) {
      const isPremium = await this.premium.isPremium(principal.userId, now);
      if (!isPremium) {
        const used = await this.repo.monthlyCount(principal.userId, now);
        if (used >= ROUTE_FREE_MONTHLY_LIMIT) {
          throw new AppProblem(
            'premium-required',
            `Ücretsiz üyelik ayda ${ROUTE_FREE_MONTHLY_LIMIT} rota paylaşabilir — ` +
              'sınırsız paylaşım Koybul Premium ile açılır.',
          );
        }
      }
    }

    const row = await this.repo.create(uuidv7(), principal.userId, input);
    return { id: row.id, status: row.status };
  }

  /** Kaydet (aç/kapa) — kendi rotası da kaydedilebilir (Defter kopyası). */
  async toggleSave(
    principal: Principal,
    routeId: string,
  ): Promise<{ saved: boolean; saveCount: number }> {
    await this.assertVisible(principal, routeId);
    return this.repo.toggleSave(routeId, principal.userId);
  }

  /** "Yaptım" (aç/kapa) — beyan; doğrulanmış gibi sunulmaz. */
  async toggleDone(
    principal: Principal,
    routeId: string,
  ): Promise<{ done: boolean; doneCount: number }> {
    await this.assertVisible(principal, routeId);
    return this.repo.toggleDone(routeId, principal.userId);
  }

  /** Sahibin silmesi — paylaşım anında yayından iner (gizlilik sözü §9). */
  async remove(principal: Principal, routeId: string): Promise<void> {
    const ok = await this.repo.softDelete(routeId, principal.userId);
    if (!ok) throw new AppProblem('not-found');
  }

  /** Etkileşim yalnız YAYINDAKİ rotada — bekleyen/reddedilen 404 (sızdırmaz). */
  private async assertVisible(principal: Principal, routeId: string): Promise<void> {
    const row = await this.repo.findRoute(routeId);
    if (!row) throw new AppProblem('not-found');
    const mine = principal.userId === row.userId;
    if (row.status !== 'approved' && !mine) throw new AppProblem('not-found');
  }
}
