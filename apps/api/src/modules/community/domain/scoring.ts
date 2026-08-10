/**
 * Denizci itibarı — SAF puanlama çekirdeği (topluluk tasarımı §7).
 *
 * Buradaki hiçbir fonksiyon veritabanına, saate ya da ağa dokunmaz: girdi ver,
 * sayı al. Sebebi, puanlamanın ürünün en kolay suistimal edilen parçası olması —
 * tamamı birim testiyle kilitlenebilmeli.
 *
 * TASARIM İLKESİ: puan ÖDÜL DEĞİLDİR. Hiçbir ayrıcalık açmaz; yalnız okuyan
 * kaptana "bu bilgiyi ne kadar deneyimli birinden alıyorum" sinyalini verir.
 * Bu yüzden tavanlar bilinçli olarak DÜŞÜK: amaç çok katkı değil, doğru katkı.
 */

/** Puan üreten davranışlar. `contribution_type` enum'uyla birebir eşleşir. */
export type ContributionAction =
  | 'occupancy_reported'
  | 'note_approved'
  | 'hazard_confirmed'
  | 'helpful_received'
  | 'review_created'
  | 'photo_approved'
  | 'suggestion_approved'
  | 'report_confirmed'
  | 'trip_shared'
  | 'content_rejected';

/** Not tipleri farklı puan taşır: emniyet bilgisi en değerlisidir. */
export type NoteKind = 'status' | 'hazard' | 'experience' | 'passage';

/** Bir davranışın taban puanı (güven katsayısıyla çarpılmadan önce). */
export const BASE_POINTS: Record<ContributionAction, number> = {
  occupancy_reported: 2,
  note_approved: 0, // tipe göre belirlenir → notePoints()
  hazard_confirmed: 3,
  helpful_received: 2,
  review_created: 0, // uzunluğa göre belirlenir → reviewPoints()
  photo_approved: 10,
  suggestion_approved: 40,
  report_confirmed: 15,
  trip_shared: 5,
  content_rejected: -10,
};

/** Not tipine göre taban puan. Uyarı en yüksek: ürünün en değerli çıktısı. */
export const NOTE_POINTS: Record<NoteKind, number> = {
  status: 5,
  hazard: 20,
  experience: 12,
  passage: 10,
};

/** Kısa yorumun eşiği ve puanı — "güzel yer" tipi yorumu caydırır, engellemez. */
export const REVIEW_LONG_MIN_CHARS = 120;
export const REVIEW_LONG_POINTS = 8;
export const REVIEW_SHORT_POINTS = 3;

/** Günde puanlanan azami OLAY sayısı (fazlası kaydedilir ama puan üretmez). */
export const DAILY_EVENT_CAPS: Record<ContributionAction, number> = {
  occupancy_reported: 3,
  note_approved: 3,
  hazard_confirmed: 3,
  helpful_received: 25, // alınan oy; içerik başına ayrı tavan da var
  review_created: 2,
  photo_approved: 3,
  suggestion_approved: 1,
  report_confirmed: 2,
  trip_shared: 2,
  content_rejected: 999, // ceza sınırlanmaz
};

export const DAILY_POINT_CAP = 50;
export const WEEKLY_POINT_CAP = 200;
/** Tek bir içerik ömrü boyunca "faydalı" oyundan kazanılabilecek azami puan. */
export const HELPFUL_POINTS_PER_CONTENT_CAP = 20;

export function notePoints(kind: NoteKind): number {
  return NOTE_POINTS[kind];
}

export function reviewPoints(bodyLength: number): number {
  return bodyLength >= REVIEW_LONG_MIN_CHARS ? REVIEW_LONG_POINTS : REVIEW_SHORT_POINTS;
}

/** Aynı koya 24 saat içinde tekrar bildirim: 2. yarım, 3. ve sonrası puansız. */
export function occupancyFreshnessFactor(sameLocationReportsToday: number): number {
  if (sameLocationReportsToday <= 0) return 1;
  if (sameLocationReportsToday === 1) return 0.5;
  return 0;
}

export interface AwardContext {
  /** Taban puan (notePoints/reviewPoints ile hesaplanmış olabilir). */
  base: number;
  /** Kullanıcının güven katsayısı (0.00–1.50). */
  trust: number;
  /** Bugün bu davranıştan kaç kez PUAN ALDI. */
  todayEventsOfAction: number;
  /** Bugün toplam kaç puan aldı. */
  todayPoints: number;
  /** Bu hafta toplam kaç puan aldı. */
  weekPoints: number;
  /** Yalnız yer durumu için tazelik çarpanı (varsayılan 1). */
  freshness?: number;
}

/**
 * Bir davranışın gerçekten yazılacak puanını hesaplar.
 *
 * Sıra önemlidir: önce olay tavanı, sonra çarpanlar, sonra gün/hafta tavanı.
 * Tavan aşıldığında içerik yine kaydedilir — yalnız PUAN 0 olur. "Katkı reddedildi"
 * hissi vermemek için bu ayrım korunur.
 *
 * CEZALAR (negatif taban) hiçbir tavana tabi değildir ve güvenle çarpılmaz:
 * kötü davranış, düşük güvenli kullanıcıda ucuzlamamalıdır.
 */
export function awardablePoints(action: ContributionAction, ctx: AwardContext): number {
  if (ctx.base < 0) return ctx.base;

  if (ctx.todayEventsOfAction >= DAILY_EVENT_CAPS[action]) return 0;

  const factor = ctx.freshness ?? 1;
  const raw = Math.round(ctx.base * clampTrust(ctx.trust) * factor);
  if (raw <= 0) return 0;

  const dailyRoom = Math.max(0, DAILY_POINT_CAP - Math.max(0, ctx.todayPoints));
  const weeklyRoom = Math.max(0, WEEKLY_POINT_CAP - Math.max(0, ctx.weekPoints));
  return Math.min(raw, dailyRoom, weeklyRoom);
}

export const TRUST_MIN = 0;
export const TRUST_MAX = 1.5;
export const TRUST_DEFAULT = 1;
/** Yeni hesap indirimi: sahte hesap açıp anında puan basmayı engeller. */
export const TRUST_NEW_ACCOUNT = 0.5;
export const NEW_ACCOUNT_DAYS = 7;

export function clampTrust(v: number): number {
  if (Number.isNaN(v)) return TRUST_DEFAULT;
  return Math.min(TRUST_MAX, Math.max(TRUST_MIN, v));
}

export interface TrustStats {
  accountAgeDays: number;
  approvedCount: number;
  rejectedCount: number;
  helpfulReceived: number;
  /** Doğrulanmış şikâyet sayısı (kullanıcıya karşı). */
  confirmedReports: number;
}

/** 3 doğrulanmış ihlalde içerik üretimi 30 gün kısıtlanır (docs/12 §8.2). */
export const VIOLATIONS_FOR_RESTRICTION = 3;
export const RESTRICTION_DAYS = 30;

/**
 * Güven katsayısı. Yalnız KAZANILAN PUANI ve oy ağırlığını etkiler;
 * içeriğin görünürlüğünü ETKİLEMEZ (tasarım §8.4 — "yüksek puan = haklı" tuzağı).
 */
export function computeTrustScore(s: TrustStats): number {
  if (s.confirmedReports >= VIOLATIONS_FOR_RESTRICTION) return 0;

  // Yeni hesap: ilk onaylı katkısına kadar yarım ağırlık.
  if (s.accountAgeDays < NEW_ACCOUNT_DAYS && s.approvedCount === 0) return TRUST_NEW_ACCOUNT;

  let trust = TRUST_DEFAULT;
  const total = s.approvedCount + s.rejectedCount;
  const approvalRate = total > 0 ? s.approvedCount / total : 1;
  if (s.approvedCount >= 10 && approvalRate >= 0.9) trust += 0.2;
  if (s.helpfulReceived >= 50) trust += 0.2;

  // Red cezası birikir ama tabanı 0.40'ın altına indirmez (bu terimden).
  trust -= Math.min(0.6, s.rejectedCount * 0.05);
  trust -= s.confirmedReports * 0.25;

  return Number(clampTrust(trust).toFixed(2));
}

/** Kullanıcı yazma kısıtı altında mı (referans zaman dışarıdan verilir). */
export function isWriteRestricted(writeRestrictedUntil: Date | null, now: Date): boolean {
  return writeRestrictedUntil !== null && writeRestrictedUntil.getTime() > now.getTime();
}

export type LevelCode = 'new' | 'coastal' | 'guide' | 'master' | 'pilot';

/**
 * Seviye eşikleri. Bilinçli olarak YÜKSEK: herkesin iki haftada "Usta Kaptan"
 * olduğu bir sistemde etiket hiçbir şey anlatmaz (seviye enflasyonu).
 * Etiket metinleri istemcide, 4 dilde yaşar — sunucu yalnız kodu tutar.
 */
export const LEVELS: { code: LevelCode; minPoints: number }[] = [
  { code: 'new', minPoints: 0 },
  { code: 'coastal', minPoints: 150 },
  { code: 'guide', minPoints: 600 },
  { code: 'master', minPoints: 1500 },
  { code: 'pilot', minPoints: 4000 },
];

export function levelForPoints(points: number): LevelCode {
  let code: LevelCode = 'new';
  for (const l of LEVELS) {
    if (points >= l.minPoints) code = l.code;
  }
  return code;
}

/** Bir sonraki seviyeye kalan puan; en üstteyse null. */
export function pointsToNextLevel(points: number): number | null {
  const next = LEVELS.find((l) => l.minPoints > points);
  return next ? next.minPoints - points : null;
}
