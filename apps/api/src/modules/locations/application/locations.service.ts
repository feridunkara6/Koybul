import { Inject, Injectable } from '@nestjs/common';
import { LOCATIONS_REPOSITORY, LocationsRepository } from '../domain/locations.repository';
import { PIN_CAP, parseBbox, quantizeBbox } from '../domain/bbox';
import { CLUSTER_CAP, MIN_PIN_ZOOM, clusterCellSizeDeg, parseZoom } from '../domain/cluster';
import { NM_TO_M, parseNearbyQuery } from '../domain/nearby';
import { normalizeSearch, sanitizeAmenities } from '../domain/search';
import { parseReviewsLimit } from '../domain/reviews';
import {
  LocationDetail,
  LocationSummary,
  MapResult,
  OccupancyLevel,
  OccupancySummary,
  ReviewItem,
} from '../domain/location.types';
import { pickLabel } from '../../../common/i18n/locale';
import { AppProblem } from '../../../common/problem/problem';

/** i18n satırından name/description seçer: istenen → 'en' → temel (null atlanır). */
function pickI18nField(
  rows: { locale: string; name: string | null; description: string | null }[],
  locale: string,
  field: 'name' | 'description',
  fallback: string | null,
): string | null {
  return (
    rows.find((r) => r.locale === locale)?.[field] ??
    rows.find((r) => r.locale === 'en')?.[field] ??
    fallback
  );
}

/** Harita/lokasyon sorguları — doğrulama + tavan/truncation orkestrasyonu. */
@Injectable()
export class LocationsService {
  constructor(@Inject(LOCATIONS_REPOSITORY) private readonly repo: LocationsRepository) {}

  /**
   * Harita bbox sorgusu (docs/23 §9.5). Ham bbox doğrulanır, %1 grid'e kuantalanır.
   * zoom < 9 → cluster modu (balonlar); aksi halde (zoom ≥ 9 veya yok) → pin modu.
   */
  async map(
    rawBbox: string | undefined,
    rawZoom: string | undefined,
    types: string[] | undefined,
  ): Promise<MapResult> {
    const bbox = parseBbox(rawBbox);
    const zoom = parseZoom(rawZoom);
    const quantized = quantizeBbox(bbox);

    if (zoom !== undefined && zoom < MIN_PIN_ZOOM) {
      const cellDeg = clusterCellSizeDeg(zoom);
      const found = await this.repo.findClusters(quantized, types, cellDeg, CLUSTER_CAP + 1);
      const clusters = found.length > CLUSTER_CAP ? found.slice(0, CLUSTER_CAP) : found;
      return { clusters, locations: [], truncated: false };
    }

    const rows = await this.repo.findPinsInBbox(quantized, types, PIN_CAP + 1);
    const truncated = rows.length > PIN_CAP;
    return { clusters: [], locations: truncated ? rows.slice(0, PIN_CAP) : rows, truncated };
  }

  /**
   * Yakınımdaki lokasyonlar (docs/23 §9.6). Query doğrulanır; radiusNm metreye
   * çevrilir; sonuç mesafeye göre artan sıralı döner.
   */
  async nearby(
    raw: { lat?: string; lon?: string; radiusNm?: string; limit?: string },
    types: string[] | undefined,
  ): Promise<{ data: LocationSummary[] }> {
    const q = parseNearbyQuery(raw);
    const data = await this.repo.findNearby({
      lat: q.lat,
      lon: q.lon,
      radiusMeters: q.radiusNm * NM_TO_M,
      types,
      limit: q.limit,
    });
    return { data };
  }

  /**
   * Metinle arama (docs/23 §9, S-07). Query normalize edilir; q anlamlı uzunlukta
   * değilse boş sonuç (422 değil — akıcı UX). Aksi halde ad/şehir/su-alanı araması.
   */
  async search(
    rawQ: string | undefined,
    types: string[] | undefined,
    amenities: string[] | undefined,
    rawLimit: string | undefined,
  ): Promise<{ data: LocationSummary[] }> {
    const query = normalizeSearch({ q: rawQ, limit: rawLimit });
    const amens = sanitizeAmenities(amenities);
    // Gelişmiş arama: metin YA DA olanak filtresi yeterlidir — kullanıcı hiç
    // yazmadan "yakıtı olan yerler" diye keşif yapabilir (S-07 genişletme).
    if (!query.searchable && amens.length === 0) return { data: [] };
    const data = await this.repo.findSearch({
      q: query.searchable ? query.q : '',
      types,
      amenities: amens.length > 0 ? amens : undefined,
      limit: query.limit,
    });
    return { data };
  }

  /**
   * Bir lokasyonun onaylı yorumları (docs/23 §11.3). id veya slug ile; en yeni
   * önce, limit [1,50] varsayılan 10. Lokasyon yoksa boş liste.
   */
  async reviews(idOrSlug: string, rawLimit: string | undefined): Promise<{ data: ReviewItem[] }> {
    const data = await this.repo.findReviews(idOrSlug, parseReviewsLimit(rawLimit));
    return { data };
  }

  /**
   * Liman detayı (docs/23 §11.3, S-09). id veya slug ile; bulunamazsa 404.
   * name/description + olanak/hizmet etiketleri locale'e göre çözülür; `typeDetails`
   * (alt-tip birleşimi) ve `rating.dimensions` (yorum-türevli) dahil.
   * `media.cover`/`userContext` ilgili alt sistemlerle gelecek (şimdilik null).
   */
  async detail(idOrSlug: string, locale: string): Promise<LocationDetail> {
    const d = await this.repo.findDetail(idOrSlug);
    if (!d) throw new AppProblem('not-found');

    return {
      id: d.id,
      slug: d.slug,
      type: d.type,
      status: d.status,
      name: pickI18nField(d.i18n, locale, 'name', d.baseName) ?? d.baseName,
      description: pickI18nField(d.i18n, locale, 'description', d.baseDescription),
      position: { lat: d.lat, lon: d.lon },
      geo: { countryCode: d.countryCode, adminArea: d.adminArea, waterBody: d.waterBody },
      dimensions: d.dimensions,
      priceTier: d.priceTier,
      is24h: d.is24h,
      verifiedAt: d.verifiedAt,
      rating: { avg: d.ratingAvg, count: d.ratingCount, dimensions: d.ratingDimensions },
      amenities: d.amenities.map((a) => ({
        code: a.code,
        label: pickLabel(a.translations, locale, a.code),
        category: a.category,
      })),
      services: d.services.map((s) => ({
        code: s.code,
        label: pickLabel(s.translations, locale, s.code),
      })),
      contacts: d.contacts,
      hours: d.hours,
      seasons: d.seasons,
      typeDetails: d.typeDetails,
      media: { cover: d.cover, count: d.photoCount },
      occupancy: d.occupancy ?? null,
      windExposedDirs: d.windExposedDirs ?? null,
      seabed: d.seabed ?? null,
      userContext: null,
      counts: { reviews: d.reviewCount, photos: d.photoCount },
    };
  }

  /**
   * Doluluk bildirimi (2026-07 ayrıştırma paketi ①): HESAP ister (guard
   * denetler); kullanıcı başına lokasyon başına tek satır — yeni bildirim
   * üstüne yazar. Dönen değer güncel özettir (istemci ekranı hemen tazeler).
   */
  /** İstemci kuralı 5 NM; sunucu 6 NM (11.112 m) — GPS sapması payı. */
  static readonly MAX_REPORT_DISTANCE_M = 11_112;

  async reportOccupancy(
    idOrSlug: string,
    userId: string,
    level: OccupancyLevel,
    reporterPos: { lat: number; lon: number },
  ): Promise<{ occupancy: OccupancySummary }> {
    const result = await this.repo.reportOccupancy(
      idOrSlug,
      userId,
      level,
      reporterPos,
      LocationsService.MAX_REPORT_DISTANCE_M,
    );
    if (!result) throw new AppProblem('not-found');
    if (result === 'unsupported') {
      // Marina/liman gibi işletmeli türlerde doluluk bildirimi kapalıdır.
      throw new AppProblem('validation-error', 'Bu konum türü için doluluk bildirimi kapalıdır.', [
        {
          field: 'type',
          code: 'type_not_supported',
          message: 'Doluluk yalnız bağlanma yerleri ve restoran iskeleleri için bildirilebilir.',
        },
      ]);
    }
    if (result === 'too-far') {
      // Yanlış bilgi trafiğine karşı: yalnız yakınında olduğun koy bildirilebilir.
      throw new AppProblem('validation-error', 'Bildirim için koyun yakınında olmalısınız.', [
        { field: 'position', code: 'too_far', message: 'Konum, bildirilen koydan çok uzak.' },
      ]);
    }
    return { occupancy: result };
  }
}
