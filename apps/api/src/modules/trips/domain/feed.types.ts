/**
 * TAKİP AKIŞI (SP-3b, kurucu onayı 2026-10-31) — GET /v1/feed.
 *
 * Takip edilen kaptanların HERKESE AÇIK içeriği tek zaman akışında:
 * paylaşılan seyirler + onaylı kaptan notları + onaylı rotalar. Akış yeni
 * veri ÜRETMEZ — zaten yayında olan içeriği takip grafiğiyle süzer; bu
 * yüzden gizlilik yüzeyi büyümez (PII yok, konum izi yok).
 *
 * Hesap İSTER: akış "takip ettiklerim"e göre kişiseldir; misafirin takip
 * listesi olamaz (kurucu kuralı). Boş akış istemcide keşfe davet eder.
 */

export const FEED_LIMIT = 50;
/** Not gövdesi akışta kırpılır — kart özet yüzeyidir, tam metin koyda. */
export const FEED_NOTE_BODY_MAX = 200;

export type FeedKind = 'trip' | 'note' | 'route';

/** Tek akış satırı — tür dışı alanlar null (düz model; istemci ayırır). */
export interface FeedItem {
  kind: FeedKind;
  id: string;
  authorId: string;
  authorName: string;
  levelCode: string;
  createdAt: string;
  // --- trip ---
  startName: string | null;
  endName: string | null;
  distanceNm: number | null;
  durationMin: number | null;
  stopCount: number | null;
  sailedOn: string | null;
  pruvaCount: number | null;
  /** Bakan "Pruvan neta" demiş mi? (yalnız trip; diğerlerinde null) */
  myPruva: boolean | null;
  // --- note ---
  locationId: string | null;
  locationName: string | null;
  noteKind: string | null;
  /** Kırpılmış gövde (FEED_NOTE_BODY_MAX) — tam metin koy sayfasında. */
  body: string | null;
  // --- route ---
  routeName: string | null;
  saveCount: number | null;
}

/** Ham akış satırı (Decimal/Date → unknown; servis sayıya çevirir). */
export interface FeedRow {
  kind: FeedKind;
  id: string;
  authorId: string;
  authorName: string | null;
  levelCode: string | null;
  createdAt: Date;
  startName: string | null;
  endName: string | null;
  distanceNm: unknown;
  durationMin: number | null;
  stopCount: number | null;
  sailedOn: Date | null;
  pruvaCount: number | null;
  myPruva: boolean | null;
  locationId: string | null;
  locationName: string | null;
  noteKind: string | null;
  body: string | null;
  routeName: string | null;
  saveCount: number | null;
}

export const FEED_REPOSITORY = Symbol('FEED_REPOSITORY');

export interface FeedRepository {
  /** Takip edilenlerin birleşik akışı — en yeni önce, LIMIT ile. */
  followingFeed(userId: string, limit: number): Promise<FeedRow[]>;
}
