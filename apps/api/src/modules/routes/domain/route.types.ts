/**
 * ROTA PAYLAŞIMI V1 (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24 plan §5).
 *
 * İLKELER:
 * - Rota = ad + duraklar (katalog lokasyonları) + deneyim metni. Çizgi ve
 *   konum geçmişi SAKLANMAZ; çizgiyi istemci kendi rotalayıcısıyla üretir.
 * - Mesafe/süre istemci hesabından gelir (beyan) — istemci bunu elle
 *   yazdırmaz; sunucu aralık doğrular. Doğrulanmış gibi sunulmaz.
 * - Her rota moderasyon ONAYINDAN geçer (yorumlarla aynı: pending doğar).
 * - Ücretsiz üye ayda EN FAZLA 2 rota paylaşır (bayrak açıkken; plan §10).
 */

export const ROUTE_NAME_MIN = 3;
export const ROUTE_NAME_MAX = 80;
export const ROUTE_BODY_MIN = 30;
export const ROUTE_BODY_MAX = 2000;
export const ROUTE_STOPS_MIN = 2;
export const ROUTE_STOPS_MAX = 8;
export const ROUTE_LIST_DEFAULT_LIMIT = 20;
export const ROUTE_LIST_MAX_LIMIT = 50;
/** Ücretsiz üyenin aylık paylaşım tavanı (bayrak açıkken; plan §10). */
export const ROUTE_FREE_MONTHLY_LIMIT = 2;

export type RouteModerationStatus = 'pending' | 'approved' | 'rejected';
export type RouteSort = 'new' | 'popular';

/** Duraklar — ad katalogdan gelir; istemci çizgiyi bu kimliklerle üretir. */
export interface RouteStopView {
  seq: number;
  locationId: string;
  name: string;
  typeCode: string;
}

/** Liste satırı — herkese açık alanlar. */
export interface RouteSummary {
  id: string;
  name: string;
  authorId: string;
  authorName: string;
  startName: string;
  endName: string;
  stopCount: number;
  distanceNm: number;
  durationHours: number | null;
  season: string | null;
  saveCount: number;
  doneCount: number;
  createdAt: string;
}

/** Detay — tam gövde + duraklar + bakanın defter durumu. */
export interface RouteDetail extends RouteSummary {
  body: string;
  boatSuggestion: string | null;
  status: RouteModerationStatus;
  stops: RouteStopView[];
  mine: boolean;
  savedByMe: boolean;
  doneByMe: boolean;
}

export interface CreateRouteInput {
  name: string;
  body: string;
  season?: string | null;
  boatSuggestion?: string | null;
  distanceNm: number;
  durationHours?: number | null;
  /** Sıralı durak kimlikleri (ROUTE_STOPS_MIN..MAX); ardışık tekrar yasak. */
  stopLocationIds: string[];
}

/** Depo satırı — SQL'den dönen ham rota (iç kullanım). */
export interface RouteRow {
  id: string;
  userId: string;
  name: string;
  body: string;
  season: string | null;
  boatSuggestion: string | null;
  distanceNm: unknown;
  durationHours: unknown;
  status: RouteModerationStatus;
  saveCount: number;
  doneCount: number;
  createdAt: Date;
  authorName: string | null;
  startName: string | null;
  endName: string | null;
  stopCount: number;
}

export const ROUTES_REPOSITORY = Symbol('ROUTES_REPOSITORY');

export interface RoutesRepository {
  /** Onaylı rotalar; sıralama yeni/popüler; locationId verilirse o duraktan geçenler. */
  list(sort: RouteSort, locationId: string | null, limit: number): Promise<RouteRow[]>;
  findRoute(routeId: string): Promise<RouteRow | null>;
  stopsFor(routeId: string): Promise<RouteStopView[]>;
  /** Verilen kimliklerden kaçı yayında katalog lokasyonu? (doğrulama) */
  publishedLocationCount(locationIds: string[]): Promise<number>;
  /** Kullanıcının bu takvim ayında oluşturduğu (silinmemiş) rota sayısı. */
  monthlyCount(userId: string, now: Date): Promise<number>;
  /** Rota + duraklar + moderasyon görevi TEK transaction. */
  create(id: string, userId: string, input: CreateRouteInput): Promise<RouteRow>;
  savedBy(routeId: string, userId: string): Promise<boolean>;
  doneBy(routeId: string, userId: string): Promise<boolean>;
  toggleSave(routeId: string, userId: string): Promise<{ saved: boolean; saveCount: number }>;
  toggleDone(routeId: string, userId: string): Promise<{ done: boolean; doneCount: number }>;
  /** Sahibin yumuşak silmesi; bekleyen moderasyon görevi kapatılır. */
  softDelete(routeId: string, userId: string): Promise<boolean>;
}
