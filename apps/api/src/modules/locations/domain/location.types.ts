/** Coğrafi nokta (WGS84). */
export interface GeoPoint {
  lat: number;
  lon: number;
}

/** Doluluk bildirimi yapılabilen türler (kullanıcı kararı 2026-07):
 * yalnız BAĞLANMA YERLERİ ve RESTORAN İSKELELERİ — marina/liman gibi işletmeli
 * yerlerde doluluğu işletme bilir, kullanıcı bildirimi yanlış bilgi üretir. */
export const OCCUPANCY_SUPPORTED_TYPES: readonly string[] = [
  'mooring_point',
  'buoy',
  'guest_mooring',
  'restaurant_pier',
];

/**
 * `typeDetails.kind = 'anchorage'` ÜRETİLEBİLECEK tipler.
 *
 * NEDEN GEREKLİ (veri turu 2026-08): zemin (holding_type) fiziksel olarak
 * `anchorage_details` tablosunda durur, ama zemin bilgisi bir BALIKÇI
 * BARINAĞI ya da belediye limanı için de geçerlidir — kaptan orada da demir
 * atar. Satırı o limanlara da yazmak istiyoruz; ancak `anchorage_details`
 * satırının varlığı eskiden doğrudan `kind: 'anchorage'` üretiyordu ve o kart
 * `isFree` alanını "Ücretsiz" rozeti olarak basıyordu. `is_free` kolonu
 * NOT NULL DEFAULT true olduğundan, ücretli bir belediye limanı sırf zemin
 * bilgisi eklendi diye "Ücretsiz" görünecekti — sahte iddia.
 *
 * Çözüm: `kind: 'anchorage'` YALNIZ gerçek demirleme tiplerinde üretilir;
 * zemin ise tipten bağımsız olarak üst düzey `seabed` alanıyla taşınır.
 */
export const ANCHORAGE_KIND_TYPES: readonly string[] = ['mooring_point', 'buoy', 'guest_mooring'];

/** Koy doluluk düzeyi (2026-07 ayrıştırma paketi ①). */
export type OccupancyLevel = 'empty' | 'moderate' | 'full';

/**
 * Doluluk özeti: son 6 saat penceresindeki bildirimlerden türetilir.
 * `level` EN SON bildirimdir (stale koruması: en yeni kazanır),
 * `reportCount` penceredeki bildirim sayısı, `reportedAt` en son bildirim anı.
 * Pencerede bildirim yoksa alan hiç dönmez (null) — tahmin gösterilmez.
 */
export interface OccupancySummary {
  level: OccupancyLevel;
  reportedAt: string;
  reportCount: number;
}

/** Harita pin'i — minimum bayt seti (docs/23 §11.1). */
export interface LocationPin {
  id: string;
  name: string;
  /** location_type kodu (istemci ikon/renk eşler). */
  type: string;
  position: GeoPoint;
  ratingAvg: number | null;
  priceTier: string;
  /** Kabul limitleri (null = bilinmiyor) — istemci tekne-uyum rozetini haritada çizer. */
  maxBoatLengthM: number | null;
  maxDraftM: number | null;
  /** Son 6 saatte bildirim varsa doluluk özeti; yoksa null. */
  occupancy: OccupancySummary | null;
}

/** Sınırlayıcı kutu (`minLon,minLat,maxLon,maxLat`, docs/23 §9.5). */
export interface Bbox {
  minLon: number;
  minLat: number;
  maxLon: number;
  maxLat: number;
}

/** Harita balonu (docs/23 §9.5, cluster modu). `bbox` = balonun hücre kapsamı;
 * istemci dokununca bu bbox ile yeniden sorgular (S-06 kamera uçuşu). */
export interface Cluster {
  position: GeoPoint;
  count: number;
  /** [minLon, minLat, maxLon, maxLat] */
  bbox: [number, number, number, number];
  /** ISO-3166 alpha-2 (TR/GR…) — balonlar ülkeye göre ayrılır ve renklenir. */
  countryCode: string;
}

/**
 * Harita yanıtı (docs/23 §9.5). zoom ≥ 9 → `locations` dolu, `clusters` boş;
 * zoom < 9 → `clusters` dolu, `locations` boş. `truncated` yalnız pin modunda
 * anlamlı (tavan aşımı).
 */
export interface MapResult {
  clusters: Cluster[];
  locations: LocationPin[];
  truncated: boolean;
}

/**
 * Kart/detay kapak görseli (docs/23 §11.2). `url` barındırılan varyant CDN URL'i
 * ya da dış (CC/Commons) görsel URL'idir. `credit`/`license`/`sourceUrl` yalnız
 * dış lisanslı görsellerde dolar ve istemcide GÖSTERİLMESİ zorunludur (CC atfı).
 */
export interface CoverMedia {
  url: string;
  blurhash: string | null;
  credit: string | null;
  license: string | null;
  sourceUrl: string | null;
}

/**
 * Kart/liste öğesi (docs/23 §11.2) = Pin + zenginleştirme.
 * `coverMedia` medya alt sistemi (§12) gelene dek `null` (v1'de lokasyon medyası
 * henüz doldurulmadı). `isFavorite` yalnız kimlikli bağlamda eklenir — bu anonim
 * uçta yer almaz.
 */
export interface LocationSummary {
  id: string;
  name: string;
  type: string;
  position: GeoPoint;
  slug: string;
  coverMedia: CoverMedia | null;
  ratingAvg: number | null;
  ratingCount: number;
  priceTier: string;
  city: string | null;
  waterBodyName: string | null;
  distanceNm: number;
  amenityCodes: string[];
  /** Kabul edilen maks. tekne boyu (m) — tekne-uygunluğu filtresi için. */
  maxBoatLengthM: number | null;
  /** Kabul edilen maks. su çekimi (m) — tekne-uygunluğu filtresi için. */
  maxDraftM: number | null;
}

/** Doğrulanmış nearby sorgu parametreleri (metreye çevrilmiş yarıçapla). */
export interface NearbyParams {
  lat: number;
  lon: number;
  radiusMeters: number;
  types?: string[];
  limit: number;
}

/** Doğrulanmış metin-arama parametreleri (docs/23 §9 — S-07). */
export interface SearchParams {
  /** Normalize edilmiş arama metni (kırpılmış, >= MIN_SEARCH_LEN). */
  q: string;
  types?: string[];
  limit: number;
  /** Olanak kodları (AND: hepsi bulunmalı); boş/yok = filtre yok. */
  amenities?: string[];
}

/** Yayınlanmış (onaylı, silinmemiş) bir yorum — misafir okuma (docs/23 §11.3). */
export interface ReviewItem {
  id: string;
  /** Yazarın görünen adı; profil yoksa anonim fallback. */
  authorName: string;
  /** Genel puan 1..5. */
  rating: number;
  title: string | null;
  body: string | null;
  /** Ziyaret tarihi "YYYY-MM-DD" ya da null. */
  visitedOn: string | null;
  /** Oluşturulma zamanı (ISO 8601). */
  createdAt: string;
  helpfulCount: number;
}

// --- LocationDetail (S-09, docs/23 §11.3) ---

export interface AdminAreaRef {
  id: string;
  name: string;
  province: string | null;
}

export interface WaterBodyRef {
  id: string;
  name: string;
  type: string;
}

export interface GeoBlock {
  countryCode: string;
  adminArea: AdminAreaRef | null;
  waterBody: WaterBodyRef | null;
}

export interface Dimensions {
  maxBoatLengthM: number | null;
  maxDraftM: number | null;
  depthMinM: number | null;
  depthMaxM: number | null;
  capacity: number | null;
}

export interface RatingDimensionAvg {
  code: string;
  avg: number;
}

export interface RatingBlock {
  avg: number | null;
  count: number;
  dimensions: RatingDimensionAvg[];
}

export interface AmenityLabeled {
  code: string;
  label: string;
  category: string | null;
}

export interface ServiceLabeled {
  code: string;
  label: string;
}

export interface ContactDto {
  type: string;
  value: string;
  isPrimary: boolean;
  // İnsan-okur etiket (ör. "Marina Ofisi", "Acil Durum"). Geriye uyumlu: yoksa null.
  label?: string | null;
}

/** Gün içi çalışma saati; kapalı günlerde opensAt/closesAt null. */
export interface HourDto {
  dayOfWeek: number;
  opensAt: string | null;
  closesAt: string | null;
}

/** Sezon aralığı "MM-DD" (docs/23 §11.3). */
export interface SeasonDto {
  opensOn: string | null;
  closesOn: string | null;
}

export interface MediaBlock {
  cover: CoverMedia | null;
  count: number;
}

// --- typeDetails ayrık birleşimi (docs/23 §11.3; donmuş alt-tip tabloları) ---

export interface MarinaTypeDetails {
  kind: 'marina';
  berthCount: number | null;
  vhfChannel: string | null;
  hasBlueFlag: boolean | null;
  travelLiftCapacityTons: number | null;
  craneCapacityTons: number | null;
  winterStorage: boolean | null;
}

export interface FuelDockTypeDetails {
  kind: 'fuelDock';
  hasDiesel: boolean | null;
  hasGasoline: boolean | null;
  hasAdblue: boolean | null;
  minDepthM: number | null;
  paymentNote: string | null;
}

export interface RestaurantDockTypeDetails {
  kind: 'restaurantDock';
  cuisine: string | null;
  berthCountFree: number | null;
  minSpendPolicy: string | null;
  reservationRecommended: boolean | null;
}

export interface AnchorageTypeDetails {
  kind: 'anchorage';
  holdingType: string | null;
  protectionN: number | null;
  protectionS: number | null;
  protectionE: number | null;
  protectionW: number | null;
  swellExposure: string | null;
  isFree: boolean;
}

export type TypeDetails =
  MarinaTypeDetails | FuelDockTypeDetails | RestaurantDockTypeDetails | AnchorageTypeDetails;

/**
 * Liman detayı (docs/23 §11.3). `typeDetails` (alt-tip birleşimi) ve
 * `rating.dimensions` (yorum-türevli) 3.1b-iv-b'de; `media.cover` medya alt
 * sistemiyle; `userContext` kimlikli bağlamda gelecek — bu anonim uçta `null`.
 */
export interface LocationDetail {
  id: string;
  slug: string;
  type: string;
  status: string;
  name: string;
  description: string | null;
  position: GeoPoint;
  geo: GeoBlock;
  dimensions: Dimensions;
  priceTier: string;
  is24h: boolean;
  verifiedAt: string | null;
  rating: RatingBlock;
  amenities: AmenityLabeled[];
  services: ServiceLabeled[];
  contacts: ContactDto[];
  hours: HourDto[];
  seasons: SeasonDto[];
  typeDetails: TypeDetails | null;
  media: MediaBlock;
  /** Son 6 saatte bildirim varsa doluluk özeti; yoksa null. */
  occupancy: OccupancySummary | null;
  /** Rüzgâra AÇIK yönler (TR pusula kodları, virgüllü: 'G,GD'); yoksa null. */
  windExposedDirs: string | null;
  /**
   * Deniz dibi tutuş cinsi: 'sand' | 'mud' | 'weed' | 'rock' | 'mixed'.
   * TİPTEN BAĞIMSIZDIR — balıkçı barınağında da demir atılır, bu yüzden
   * `typeDetails.kind` 'anchorage' olmasa da doludur.
   */
  seabed: string | null;
  /**
   * Rüzgâra KARŞI KORUNAKLI yönler (TR pusula kodları, virgüllü: 'K,GB').
   * `windExposedDirs`'in tersi DEĞİLDİR ve ondan türetilemez: kılavuzlar
   * korunağı ("sheltered from northerlies") ayrı bir bilgi olarak yazar.
   * Sekiz yön de doluysa kaynak "her yönden korunaklı" demiştir.
   */
  shelteredDirs: string | null;
  userContext: null;
  counts: { reviews: number; photos: number };
}
