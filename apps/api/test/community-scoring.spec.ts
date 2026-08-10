import {
  DAILY_POINT_CAP,
  LEVELS,
  WEEKLY_POINT_CAP,
  awardablePoints,
  clampTrust,
  computeTrustScore,
  isWriteRestricted,
  levelForPoints,
  notePoints,
  occupancyFreshnessFactor,
  pointsToNextLevel,
  reviewPoints,
} from '../src/modules/community/domain/scoring';

const base = { todayEventsOfAction: 0, todayPoints: 0, weekPoints: 0, trust: 1 };

describe('puan tabanları', () => {
  it('uyarı notu en yüksek puanı taşır (emniyet bilgisi ürünün en değerli çıktısı)', () => {
    expect(notePoints('hazard')).toBeGreaterThan(notePoints('experience'));
    expect(notePoints('experience')).toBeGreaterThan(notePoints('passage') - 3);
    expect(notePoints('status')).toBeLessThan(notePoints('experience'));
  });

  it('kısa yorum düşük puan alır ama SIFIR almaz (caydırır, engellemez)', () => {
    expect(reviewPoints(10)).toBe(3);
    expect(reviewPoints(119)).toBe(3);
    expect(reviewPoints(120)).toBe(8);
  });

  it('aynı koya tekrar bildirim puanı söndürür', () => {
    expect(occupancyFreshnessFactor(0)).toBe(1);
    expect(occupancyFreshnessFactor(1)).toBe(0.5);
    expect(occupancyFreshnessFactor(2)).toBe(0);
    expect(occupancyFreshnessFactor(9)).toBe(0);
  });
});

describe('awardablePoints', () => {
  it('güven katsayısıyla çarpar ve yuvarlar', () => {
    expect(awardablePoints('photo_approved', { ...base, base: 10, trust: 1.2 })).toBe(12);
    expect(awardablePoints('photo_approved', { ...base, base: 10, trust: 0.5 })).toBe(5);
  });

  it('olay tavanı dolduysa 0 verir (içerik yine kaydedilir)', () => {
    expect(awardablePoints('photo_approved', { ...base, base: 10, todayEventsOfAction: 3 })).toBe(
      0,
    );
    expect(awardablePoints('photo_approved', { ...base, base: 10, todayEventsOfAction: 2 })).toBe(
      10,
    );
  });

  it('günlük tavan kalan boşluk kadarını verir', () => {
    expect(
      awardablePoints('photo_approved', { ...base, base: 10, todayPoints: DAILY_POINT_CAP - 4 }),
    ).toBe(4);
    expect(
      awardablePoints('photo_approved', { ...base, base: 10, todayPoints: DAILY_POINT_CAP }),
    ).toBe(0);
  });

  it('haftalık tavan günlükten bağımsız olarak keser', () => {
    expect(
      awardablePoints('photo_approved', { ...base, base: 10, weekPoints: WEEKLY_POINT_CAP - 2 }),
    ).toBe(2);
  });

  it('tazelik çarpanı uygulanır', () => {
    expect(awardablePoints('occupancy_reported', { ...base, base: 2, freshness: 0.5 })).toBe(1);
    expect(awardablePoints('occupancy_reported', { ...base, base: 2, freshness: 0 })).toBe(0);
  });

  it('CEZA hiçbir tavana takılmaz ve güvenle ÇARPILMAZ', () => {
    const ctx = { ...base, base: -10, trust: 0.4, todayPoints: 999, weekPoints: 999 };
    expect(awardablePoints('content_rejected', ctx)).toBe(-10);
  });

  it('güven 0 ise puan 0 olur (ama içerik reddedilmez)', () => {
    expect(awardablePoints('note_approved', { ...base, base: 20, trust: 0 })).toBe(0);
  });
});

describe('computeTrustScore', () => {
  it('yeni hesap yarım ağırlıkla başlar, ilk onaydan sonra normale döner', () => {
    expect(
      computeTrustScore({
        accountAgeDays: 1,
        approvedCount: 0,
        rejectedCount: 0,
        helpfulReceived: 0,
        confirmedReports: 0,
      }),
    ).toBe(0.5);
    expect(
      computeTrustScore({
        accountAgeDays: 1,
        approvedCount: 1,
        rejectedCount: 0,
        helpfulReceived: 0,
        confirmedReports: 0,
      }),
    ).toBe(1);
  });

  it('yüksek onay oranı ve faydalı oyu katsayıyı yükseltir', () => {
    const t = computeTrustScore({
      accountAgeDays: 200,
      approvedCount: 40,
      rejectedCount: 1,
      helpfulReceived: 60,
      confirmedReports: 0,
    });
    expect(t).toBeGreaterThan(1.3);
    expect(t).toBeLessThanOrEqual(1.5);
  });

  it('redler katsayıyı düşürür ama bu terim 0.60 puandan fazla indirmez', () => {
    const many = computeTrustScore({
      accountAgeDays: 200,
      approvedCount: 0,
      rejectedCount: 100,
      helpfulReceived: 0,
      confirmedReports: 0,
    });
    expect(many).toBeCloseTo(0.4, 2);
  });

  it('3 doğrulanmış ihlal katsayıyı SIFIRLAR', () => {
    expect(
      computeTrustScore({
        accountAgeDays: 900,
        approvedCount: 500,
        rejectedCount: 0,
        helpfulReceived: 900,
        confirmedReports: 3,
      }),
    ).toBe(0);
  });

  it('katsayı her zaman 0–1.5 aralığında kalır', () => {
    expect(clampTrust(9)).toBe(1.5);
    expect(clampTrust(-3)).toBe(0);
    expect(clampTrust(Number.NaN)).toBe(1);
  });
});

describe('seviyeler', () => {
  it('eşikler artan sırada ve ilk seviye 0', () => {
    expect(LEVELS[0].minPoints).toBe(0);
    for (let i = 1; i < LEVELS.length; i++) {
      expect(LEVELS[i].minPoints).toBeGreaterThan(LEVELS[i - 1].minPoints);
    }
  });

  it('puandan seviye', () => {
    expect(levelForPoints(0)).toBe('new');
    expect(levelForPoints(149)).toBe('new');
    expect(levelForPoints(150)).toBe('coastal');
    expect(levelForPoints(599)).toBe('coastal');
    expect(levelForPoints(1500)).toBe('master');
    expect(levelForPoints(999999)).toBe('pilot');
  });

  it('bir sonraki seviyeye kalan; en üstte null', () => {
    expect(pointsToNextLevel(0)).toBe(150);
    expect(pointsToNextLevel(1499)).toBe(1);
    expect(pointsToNextLevel(4000)).toBeNull();
  });
});

describe('yazma kısıtı', () => {
  const now = new Date('2026-08-10T12:00:00Z');
  it('gelecekteki kısıt engeller, geçmiş engellemez, null serbesttir', () => {
    expect(isWriteRestricted(new Date('2026-08-20T00:00:00Z'), now)).toBe(true);
    expect(isWriteRestricted(new Date('2026-08-01T00:00:00Z'), now)).toBe(false);
    expect(isWriteRestricted(null, now)).toBe(false);
  });
});
