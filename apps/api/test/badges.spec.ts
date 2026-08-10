import {
  AREA_EXPERT_MIN,
  BADGES,
  BadgeStats,
  LIGHTHOUSE_HELPFUL,
  REGION_TRAVELER_MIN,
  SAFETY_WATCH_CONFIRMED,
  WINTER_MIN,
  badgeProgress,
  earnedBadges,
  emptyBadgeStats,
} from '../src/modules/community/domain/badges';

const AREA_A = '11111111-1111-4111-8111-111111111111';
const AREA_B = '22222222-2222-4222-8222-222222222222';
const AREA_C = '33333333-3333-4333-8333-333333333333';

function stats(over: Partial<BadgeStats> = {}): BadgeStats {
  return { ...emptyBadgeStats(), ...over };
}

describe('rozet kataloğu', () => {
  it('8 rozet vardır ve kodlar tekildir (tasarım §8.3)', () => {
    expect(BADGES).toHaveLength(8);
    expect(new Set(BADGES.map((b) => b.code)).size).toBe(8);
  });

  it('altyapısı olmayan rozetler automatic=false ile işaretlidir', () => {
    const manual = BADGES.filter((b) => !b.automatic)
      .map((b) => b.code)
      .sort();
    expect(manual).toEqual(['first_explorer', 'reliable_reporter', 'verified_boat']);
  });
});

describe('earnedBadges', () => {
  it('hiçbir katkı yoksa hiçbir rozet verilmez', () => {
    expect(earnedBadges(stats())).toEqual([]);
  });

  it('eşiğin BİR ALTINDA rozet verilmez, eşikte verilir', () => {
    expect(earnedBadges(stats({ maxHelpfulOnOneNote: LIGHTHOUSE_HELPFUL - 1 }))).toEqual([]);
    expect(earnedBadges(stats({ maxHelpfulOnOneNote: LIGHTHOUSE_HELPFUL }))).toEqual([
      { code: 'lighthouse', scopeType: null, scopeId: null },
    ]);
  });

  it('bölgesel rozet BİRDEN FAZLA kez kazanılabilir, eşiği geçmeyen bölge sayılmaz', () => {
    const out = earnedBadges(
      stats({
        areaApproved: [
          { adminAreaId: AREA_A, name: 'Fethiye', count: AREA_EXPERT_MIN },
          { adminAreaId: AREA_B, name: 'Göcek', count: AREA_EXPERT_MIN + 9 },
          { adminAreaId: AREA_C, name: 'Datça', count: AREA_EXPERT_MIN - 1 },
        ],
      }),
    );
    expect(out.map((b) => b.scopeId)).toEqual([AREA_A, AREA_B]);
    expect(out.every((b) => b.code === 'area_expert' && b.scopeType === 'admin_area')).toBe(true);
  });

  it('uyarı, kış ve gezgin rozetleri eşiklerinde verilir', () => {
    const out = earnedBadges(
      stats({
        confirmedHazards: SAFETY_WATCH_CONFIRMED,
        winterContributions: WINTER_MIN,
        distinctRegions: REGION_TRAVELER_MIN,
      }),
    );
    expect(out.map((b) => b.code).sort()).toEqual([
      'region_traveler',
      'safety_watch',
      'winter_sailor',
    ]);
  });

  it('altyapısı olmayan rozetler HİÇBİR koşulda otomatik verilmez', () => {
    const out = earnedBadges(
      stats({
        maxHelpfulOnOneNote: 9999,
        confirmedHazards: 9999,
        winterContributions: 9999,
        distinctRegions: 9999,
        areaApproved: [{ adminAreaId: AREA_A, name: 'Fethiye', count: 9999 }],
      }),
    );
    const codes = out.map((b) => b.code);
    expect(codes).not.toContain('first_explorer');
    expect(codes).not.toContain('reliable_reporter');
    expect(codes).not.toContain('verified_boat');
  });
});

describe('badgeProgress', () => {
  it('hiç rozet yokken 8 satır çizilir ve hepsi kazanılmamıştır', () => {
    const rows = badgeProgress(stats(), []);
    expect(rows).toHaveLength(8);
    expect(rows.every((r) => !r.earned)).toBe(true);
  });

  it('ilerleme gerçek sayaçtan gelir (uydurulmaz)', () => {
    const rows = badgeProgress(stats({ confirmedHazards: 4 }), []);
    const safety = rows.find((r) => r.code === 'safety_watch');
    expect(safety).toMatchObject({ current: 4, target: SAFETY_WATCH_CONFIRMED, earned: false });
  });

  it('altyapısı olmayan rozetin ilerlemesi 0 gösterilir, uydurulmaz', () => {
    const rows = badgeProgress(stats({ maxHelpfulOnOneNote: 99 }), []);
    for (const code of ['first_explorer', 'reliable_reporter', 'verified_boat']) {
      const r = rows.find((x) => x.code === code);
      expect(r).toMatchObject({ current: 0, automatic: false, earned: false });
    }
  });

  it('kazanılmış küresel rozet TEKRAR "kazanılmamış" olarak listelenmez', () => {
    const rows = badgeProgress(stats({ maxHelpfulOnOneNote: 30 }), [
      { code: 'lighthouse', scopeId: null, awardedAt: '2026-08-01T00:00:00.000Z' },
    ]);
    const lighthouse = rows.filter((r) => r.code === 'lighthouse');
    expect(lighthouse).toHaveLength(1);
    expect(lighthouse[0]).toMatchObject({ earned: true, awardedAt: '2026-08-01T00:00:00.000Z' });
  });

  it('kazanılmış bölgesel rozet adıyla görünür; SONRAKİ bölge ilerleme satırı olur', () => {
    const rows = badgeProgress(
      stats({
        areaApproved: [
          { adminAreaId: AREA_A, name: 'Fethiye', count: 22 },
          { adminAreaId: AREA_B, name: 'Göcek', count: 9 },
        ],
      }),
      [{ code: 'area_expert', scopeId: AREA_A, awardedAt: '2026-07-01T00:00:00.000Z' }],
    );
    const earned = rows.find((r) => r.code === 'area_expert' && r.earned);
    const next = rows.find((r) => r.code === 'area_expert' && !r.earned);
    expect(earned).toMatchObject({ scopeName: 'Fethiye', current: 22 });
    expect(next).toMatchObject({ scopeName: 'Göcek', current: 9, target: AREA_EXPERT_MIN });
  });

  it('bölge yoksa bölgesel satır 0 ilerlemeyle yine çizilir (ekran boş kalmasın)', () => {
    const rows = badgeProgress(stats(), []);
    const area = rows.find((r) => r.code === 'area_expert');
    expect(area).toMatchObject({ current: 0, scopeId: null, scopeName: null });
  });

  it('bilinmeyen rozet kodu (eski kayıt) çökme yapmaz, satır olarak görünür', () => {
    const rows = badgeProgress(stats(), [
      { code: 'eski_rozet', scopeId: null, awardedAt: '2026-01-01T00:00:00.000Z' },
    ]);
    expect(rows[0]).toMatchObject({ code: 'eski_rozet', earned: true, target: 1 });
    expect(rows).toHaveLength(9);
  });

  it('bölgesel rozet alındı ve BAŞKA bölge yoksa ikinci (adsız) satır çizilmez', () => {
    const rows = badgeProgress(
      stats({ areaApproved: [{ adminAreaId: AREA_A, name: 'Fethiye', count: 22 }] }),
      [{ code: 'area_expert', scopeId: AREA_A, awardedAt: '2026-07-01T00:00:00.000Z' }],
    );
    expect(rows.filter((r) => r.code === 'area_expert')).toHaveLength(1);
    expect(rows[0]).toMatchObject({ earned: true, scopeName: 'Fethiye' });
  });

  it('kazanılmış bölgenin katkıları silindiyse SAYI UYDURULMAZ (0 yazılır)', () => {
    const rows = badgeProgress(stats(), [
      { code: 'area_expert', scopeId: AREA_A, awardedAt: '2026-07-01T00:00:00.000Z' },
    ]);
    expect(rows[0]).toMatchObject({ earned: true, current: 0, target: AREA_EXPERT_MIN });
  });

  it('eşiği geçmiş ama henüz yazılmamış ilerleme HEDEFİ AŞMAZ', () => {
    const rows = badgeProgress(stats({ confirmedHazards: 12 }), []);
    const safety = rows.find((r) => r.code === 'safety_watch');
    expect(safety).toMatchObject({ current: SAFETY_WATCH_CONFIRMED, earned: false });
  });
});
