import {
  Bbox,
  Cluster,
  ContactDto,
  CoverMedia,
  Dimensions,
  HourDto,
  LocationPin,
  OccupancyLevel,
  OccupancySummary,
  LocationSummary,
  NearbyParams,
  RatingDimensionAvg,
  ReviewItem,
  SearchParams,
  SeasonDto,
  TypeDetails,
} from './location.types';

export interface TranslationRow {
  locale: string;
  name: string;
}

/** Detay için ham veri; i18n etiketleme uygulama katmanında yapılır. */
export interface DetailData {
  id: string;
  slug: string;
  type: string;
  status: string;
  baseName: string;
  baseDescription: string | null;
  i18n: { locale: string; name: string | null; description: string | null }[];
  /** Son 6 saat penceresi doluluk özeti (yoksa null/undefined). */
  occupancy?: OccupancySummary | null;
  /** Rüzgâra açık yönler (TR pusula, virgüllü) — uyarı rozeti verisi. */
  windExposedDirs?: string | null;
  /** Deniz dibi tutuş cinsi — tipten bağımsız (bkz. ANCHORAGE_KIND_TYPES). */
  seabed?: string | null;
  /** Rüzgâra KARŞI korunaklı yönler (TR pusula, virgüllü) — açık yönlerin tersi değil. */
  shelteredDirs?: string | null;
  lat: number;
  lon: number;
  countryCode: string;
  adminArea: { id: string; name: string; province: string | null } | null;
  waterBody: { id: string; name: string; type: string } | null;
  dimensions: Dimensions;
  priceTier: string;
  is24h: boolean;
  verifiedAt: string | null;
  ratingAvg: number | null;
  ratingCount: number;
  reviewCount: number;
  photoCount: number;
  cover: CoverMedia | null;
  amenities: { code: string; category: string | null; translations: TranslationRow[] }[];
  services: { code: string; translations: TranslationRow[] }[];
  contacts: ContactDto[];
  hours: HourDto[];
  seasons: SeasonDto[];
  typeDetails: TypeDetails | null;
  ratingDimensions: RatingDimensionAvg[];
}

/** Lokasyon coğrafi sorguları (PostGIS; ham SQL — ADR-005). */
export interface LocationsRepository {
  /**
   * bbox içindeki yayınlanmış (silinmemiş) lokasyonları pin olarak döndürür.
   * `types` verilirse location_type koduna göre OR filtresi. Önem sırası
   * (rating_count DESC) — tavan aşılırsa en önemli pin'ler korunur.
   */
  findPinsInBbox(bbox: Bbox, types: string[] | undefined, limit: number): Promise<LocationPin[]>;

  /**
   * Doluluk bildirimi: kullanıcı başına lokasyon başına tek satır — yeni
   * bildirim üstüne yazar. Dönen değer güncel 6 saatlik özettir.
   * Lokasyon yoksa/yayında değilse null döner (servis not-found üretir).
   */
  /** `reporterPos` koya [maxDistanceM]'den uzaksa 'too-far'; tür doluluk
   * bildirimine kapalıysa (marina/liman) 'unsupported' döner — yazılmaz. */
  reportOccupancy(
    idOrSlug: string,
    userId: string,
    level: OccupancyLevel,
    reporterPos: { lat: number; lon: number },
    maxDistanceM: number,
  ): Promise<OccupancySummary | 'too-far' | 'unsupported' | null>;

  /**
   * Bir merkeze `radiusMeters` içindeki yayınlanmış lokasyonları mesafeye göre
   * artan sıralı döndürür (docs/23 §9.6). Her öğede `distanceNm`.
   */
  findNearby(params: NearbyParams): Promise<LocationSummary[]>;

  /**
   * bbox içindeki yayınlanmış lokasyonları `cellDeg` grid'ine göre gruplar
   * (docs/23 §9.5 cluster modu). En kalabalık balonlar önce; `limit` ile tavanlanır.
   */
  findClusters(
    bbox: Bbox,
    types: string[] | undefined,
    cellDeg: number,
    limit: number,
  ): Promise<Cluster[]>;

  /**
   * Metinle arama (docs/23 §9, S-07): `q` lokasyon adı, şehir (admin_area) veya
   * su alanı adında geçen yayınlanmış (silinmemiş) lokasyonları döndürür. `types`
   * verilirse location_type koduna göre OR filtresi. Sıralama: ada baştan uyanlar
   * önce, sonra önem (rating_count DESC). Konum bağımsız olduğundan `distanceNm` = 0.
   */
  findSearch(params: SearchParams): Promise<LocationSummary[]>;

  /**
   * Yayınlanmış (silinmemiş) bir lokasyonun detay verisi (docs/23 §11.3); id veya
   * slug ile. Bulunamazsa `null`. i18n etiketleri ham döner (locale servis'te seçilir).
   */
  findDetail(idOrSlug: string): Promise<DetailData | null>;

  /**
   * Bir lokasyonun onaylı (silinmemiş) yorumları (docs/23 §11.3); id veya slug ile,
   * en yeniden eskiye, `limit` ile tavanlanır. Lokasyon yoksa boş liste.
   */
  findReviews(idOrSlug: string, limit: number): Promise<ReviewItem[]>;
}

export const LOCATIONS_REPOSITORY = Symbol('LOCATIONS_REPOSITORY');
