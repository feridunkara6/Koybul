/**
 * ROZETLER — saf katalog ve değerlendirme (topluluk tasarımı §8.3).
 *
 * TASARIM İLKESİ: 8 rozet, ne az ne çok. Hiçbiri ayrıcalık açmaz; hepsi
 * DAVRANIŞI anlatır ("bu kaptan bu bölgeyi biliyor"), niceliği değil.
 * Bilinçli olarak YOK: seri/streak, "100. katkı", "ilk yorum", rozet sayısı
 * sıralaması — hepsi spam üretir ya da hiçbir şey anlatmaz.
 *
 * Buradaki hiçbir şey veritabanına dokunmaz: sayaçlar dışarıdan verilir,
 * karar burada üretilir. Etiket/açıklama metinleri İSTEMCİDE yaşar (4 dil).
 */

export type BadgeCode =
  | 'area_expert'
  | 'lighthouse'
  | 'first_explorer'
  | 'safety_watch'
  | 'reliable_reporter'
  | 'winter_sailor'
  | 'region_traveler'
  | 'verified_boat';

export interface BadgeDef {
  code: BadgeCode;
  /** Kazanma eşiği (ilerleme çubuğunun paydası). */
  target: number;
  /** Bölgeye bağlı mı — birden fazla kez kazanılabilir. */
  scoped: boolean;
  /**
   * Bugün OTOMATİK verilebiliyor mu. false olanların altyapısı henüz yok
   * (nokta önerme, fotoğraf, doluluk tutarlılığı) — ekranda "yakında" olarak
   * gösterilirler. Sessizce gizlemek yerine dürüstçe söylenir.
   */
  automatic: boolean;
}

export const AREA_EXPERT_MIN = 15;
export const LIGHTHOUSE_HELPFUL = 25;
export const SAFETY_WATCH_CONFIRMED = 5;
export const WINTER_MIN = 5;
export const REGION_TRAVELER_MIN = 3;

/** Kış ayları (Kasım–Mart) — sezon dışı katkıyı teşvik eder. */
export const WINTER_MONTHS = [11, 12, 1, 2, 3];

export const BADGES: readonly BadgeDef[] = [
  { code: 'area_expert', target: AREA_EXPERT_MIN, scoped: true, automatic: true },
  { code: 'lighthouse', target: LIGHTHOUSE_HELPFUL, scoped: false, automatic: true },
  { code: 'safety_watch', target: SAFETY_WATCH_CONFIRMED, scoped: false, automatic: true },
  { code: 'winter_sailor', target: WINTER_MIN, scoped: false, automatic: true },
  { code: 'region_traveler', target: REGION_TRAVELER_MIN, scoped: false, automatic: true },
  { code: 'first_explorer', target: 1, scoped: false, automatic: false },
  { code: 'reliable_reporter', target: 30, scoped: false, automatic: false },
  { code: 'verified_boat', target: 1, scoped: false, automatic: false },
] as const;

/** Rozet hesabı için gereken ham sayaçlar — tek SQL turunda toplanır. */
export interface BadgeStats {
  /** Bölge bazında ONAYLI not sayısı (adı da gelir: rozet etiketi bölge adını taşır). */
  areaApproved: { adminAreaId: string; name: string; count: number }[];
  /** Tek bir notun aldığı EN YÜKSEK "faydalı" oyu. */
  maxHelpfulOnOneNote: number;
  /** En az bir "doğrula" oyu almış onaylı UYARI notu sayısı. */
  confirmedHazards: number;
  /** Kasım–Mart arasında yazılan puanlı katkı sayısı. */
  winterContributions: number;
  /** Katkı verilen FARKLI bölge sayısı. */
  distinctRegions: number;
}

export interface EarnedBadge {
  code: BadgeCode;
  scopeType: string | null;
  scopeId: string | null;
}

export function emptyBadgeStats(): BadgeStats {
  return {
    areaApproved: [],
    maxHelpfulOnOneNote: 0,
    confirmedHazards: 0,
    winterContributions: 0,
    distinctRegions: 0,
  };
}

/**
 * Sayaçlardan HAK EDİLEN rozetleri üretir. Yalnız `automatic` rozetler döner;
 * altyapısı olmayanlar hiçbir koşulda kazanılmış sayılmaz.
 */
export function earnedBadges(s: BadgeStats): EarnedBadge[] {
  const out: EarnedBadge[] = [];
  for (const a of s.areaApproved) {
    if (a.count >= AREA_EXPERT_MIN) {
      out.push({ code: 'area_expert', scopeType: 'admin_area', scopeId: a.adminAreaId });
    }
  }
  if (s.maxHelpfulOnOneNote >= LIGHTHOUSE_HELPFUL) {
    out.push({ code: 'lighthouse', scopeType: null, scopeId: null });
  }
  if (s.confirmedHazards >= SAFETY_WATCH_CONFIRMED) {
    out.push({ code: 'safety_watch', scopeType: null, scopeId: null });
  }
  if (s.winterContributions >= WINTER_MIN) {
    out.push({ code: 'winter_sailor', scopeType: null, scopeId: null });
  }
  if (s.distinctRegions >= REGION_TRAVELER_MIN) {
    out.push({ code: 'region_traveler', scopeType: null, scopeId: null });
  }
  return out;
}

/** Ekranın çizdiği tek satır: kazanıldı mı, kazanılmadıysa nerede kalındı. */
export interface BadgeProgress {
  code: BadgeCode;
  earned: boolean;
  /** Kazanıldıysa ISO tarih, yoksa null. */
  awardedAt: string | null;
  current: number;
  target: number;
  /** Bölgesel rozette kapsam kimliği/adı; diğerlerinde null. */
  scopeId: string | null;
  scopeName: string | null;
  /** false = altyapısı henüz yok, ekranda "yakında" yazar. */
  automatic: boolean;
}

/** Kazanılmış rozet kaydı (veritabanından okunan). */
export interface HeldBadge {
  code: string;
  scopeId: string | null;
  awardedAt: string;
}

/**
 * Ekran için tam liste: önce kazanılanlar, sonra ilerleme sırasına göre
 * kazanılmayanlar. Kazanılmış bölgesel rozetlerin HER BİRİ ayrı satırdır.
 */
export function badgeProgress(s: BadgeStats, held: HeldBadge[]): BadgeProgress[] {
  const areaById = new Map(s.areaApproved.map((a) => [a.adminAreaId, a]));
  const out: BadgeProgress[] = [];

  // 1) Kazanılmış rozetler — kayıt neyse o gösterilir (geri alınmışlar zaten gelmez).
  for (const h of held) {
    const def = BADGES.find((b) => b.code === h.code);
    const area = h.scopeId ? areaById.get(h.scopeId) : undefined;
    out.push({
      code: (def?.code ?? h.code) as BadgeCode,
      earned: true,
      awardedAt: h.awardedAt,
      // Bölgenin güncel sayısı bulunamıyorsa (katkılar sonradan reddedildi ya
      // da silindi) SAYI UYDURULMAZ: 0 yazılır. Eskiden burada `def.target`
      // vardı ve rozet "15/15" diye yalan söylüyordu (inceleme bulgusu).
      current: h.scopeId !== null ? (area?.count ?? 0) : (def?.target ?? 1),
      target: def?.target ?? 1,
      scopeId: h.scopeId,
      scopeName: area?.name ?? null,
      automatic: def?.automatic ?? true,
    });
  }

  // 2) Henüz kazanılmayanlar. Bölgesel rozet, EN ÇOK katkı verilen ve henüz
  //    rozeti olmayan bölge üzerinden gösterilir (tek satır yeter).
  //    Anahtar (kod, kapsam) İKİLİSİDİR: yalnız kapsam kimliğine bakmak,
  //    ileride ikinci bir bölgesel rozet eklendiğinde aynı bölgeyi sessizce
  //    yutardı (inceleme bulgusu).
  const key = (code: string, scopeId: string | null) => `${code}|${scopeId ?? ''}`;
  const heldGlobal = new Set(held.filter((h) => h.scopeId === null).map((h) => h.code));
  const heldKeys = new Set(held.map((h) => key(h.code, h.scopeId)));
  for (const def of BADGES) {
    if (def.scoped) {
      const next = s.areaApproved
        .filter((a) => !heldKeys.has(key(def.code, a.adminAreaId)))
        .sort((a, b) => b.count - a.count)[0];
      // Kazanılabilecek YENİ bölge kalmadıysa ve rozet zaten alınmışsa
      // ikinci bir satır çizilmez — aksi halde ekranda "Fethiye Bilirkişisi ✓"
      // satırının hemen altında adsız bir "0/15" satırı beliriyordu.
      if (!next && held.some((h) => h.code === def.code)) continue;
      out.push({
        code: def.code,
        earned: false,
        awardedAt: null,
        // Eşiği geçmiş ama henüz yazılmamış bölge olabilir (eşitleme bir
        // sonraki katkıda koşar): çubuk %100'ü aşmasın diye kırpılır.
        current: Math.min(next?.count ?? 0, def.target),
        target: def.target,
        scopeId: next?.adminAreaId ?? null,
        scopeName: next?.name ?? null,
        automatic: def.automatic,
      });
      continue;
    }
    if (heldGlobal.has(def.code)) continue;
    out.push({
      code: def.code,
      earned: false,
      awardedAt: null,
      current: Math.min(currentFor(def.code, s), def.target),
      target: def.target,
      scopeId: null,
      scopeName: null,
      automatic: def.automatic,
    });
  }
  return out;
}

function currentFor(code: BadgeCode, s: BadgeStats): number {
  switch (code) {
    case 'lighthouse':
      return s.maxHelpfulOnOneNote;
    case 'safety_watch':
      return s.confirmedHazards;
    case 'winter_sailor':
      return s.winterContributions;
    case 'region_traveler':
      return s.distinctRegions;
    default:
      // Altyapısı olmayan rozetler: ilerleme İDDİA EDİLMEZ (0-uydurma kuralı).
      return 0;
  }
}
