/**
 * SEYİR PAYLAŞIMI + "PRUVAN NETA" (SP-3b, kurucu onayı 2026-10-31).
 *
 * İLKELER:
 * - Paylaşım YALNIZ yapısal veridir: katalog kaynaklı başlangıç/bitiş adı,
 *   mesafe (plan beyanı, ≈), elle girilen süre, durak sayısı, sefer günü.
 *   Serbest metin TAŞINMAZ → moderasyon kuyruğu YOKTUR (bilinçli karar;
 *   rotalardan farkı budur).
 * - GİZLİLİK (kurucu kuralı): "Konumum" başlangıçlı seyirde başlangıç adı
 *   İSTEMCİDE düşürülür; koordinat/iz hiçbir zaman sunucuya gelmez.
 * - "Pruvan neta" ⚓ tek tür, tek dokunuş tepkidir (denizci selamı) —
 *   DM hakkı vermez, route_saves toggle deseniyle sayılır.
 * - Misafir paylaşamaz ve tepki veremez (hesap kapısı); ücretsiz üye her
 *   ikisini de yapabilir (kurucu premium kuralları, 2026-10-31).
 */

export const TRIP_NAME_MAX = 80;
export const TRIP_DISTANCE_MAX_NM = 500;
export const TRIP_DURATION_MAX_MIN = 14400;
export const TRIP_STOPS_MAX = 50;
/** Günlük paylaşım tavanı — spam freni (sayı kurucuyla konuşulabilir). */
export const TRIP_DAILY_LIMIT = 5;

export interface ShareTripInput {
  startName: string | null;
  endName: string | null;
  distanceNm: number;
  durationMin: number | null;
  stopCount: number;
  /** 'YYYY-MM-DD' — seferin yapıldığı gün (kaptanın beyanı). */
  sailedOn: string;
}

/** Paylaşılan seyir satırı — ham sorgu çıktısı (Decimal → unknown). */
export interface SharedTripRow {
  id: string;
  userId: string;
  startName: string | null;
  endName: string | null;
  distanceNm: unknown;
  durationMin: number | null;
  stopCount: number;
  sailedOn: Date;
  pruvaCount: number;
  createdAt: Date;
}

export const TRIPS_REPOSITORY = Symbol('TRIPS_REPOSITORY');

export interface TripsRepository {
  /** Bugün (UTC gün) kaç paylaşım yapılmış? — günlük tavan denetimi. */
  sharedToday(userId: string, now: Date): Promise<number>;
  share(id: string, userId: string, input: ShareTripInput): Promise<void>;
  /** Sahibin kendi paylaşımını kaldırması; satır yoksa/başkasınınsa false. */
  remove(tripId: string, userId: string): Promise<boolean>;
  /** Paylaşım var mı (silinmemiş)? — tepki öncesi varlık denetimi. */
  exists(tripId: string): Promise<boolean>;
  /** "Pruvan neta" aç/kapat — route_saves toggle deseni. */
  togglePruva(tripId: string, userId: string): Promise<{ reacted: boolean; pruvaCount: number }>;
}
