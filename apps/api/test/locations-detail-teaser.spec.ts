import { LocationsService } from '../src/modules/locations/application/locations.service';
import {
  DetailData,
  LocationsRepository,
} from '../src/modules/locations/domain/locations.repository';
import { toTeaserDetail } from '../src/modules/locations/domain/teaser';
import { OccupancySummary } from '../src/modules/locations/domain/location.types';
import {
  AccessDecision,
  PremiumAccessService,
} from '../src/modules/premium/application/premium-access.service';
import { AppProblem } from '../src/common/problem/problem';
import { Principal } from '../src/core/auth/principal';

/** Kilitli alanları DOLU bir örnek: vitrinin gerçekten soyduğunu kanıtlamak için. */
const SAMPLE: DetailData = {
  id: 'loc-1',
  slug: 'kille-koyu',
  type: 'buoy',
  status: 'published',
  baseName: 'Kille Koyu',
  baseDescription: 'Uzun açıklama — Premium.',
  i18n: [{ locale: 'tr', name: 'Kille Koyu', description: 'Uzun açıklama — Premium.' }],
  lat: 36.6844,
  lon: 28.8921,
  countryCode: 'TR',
  adminArea: { id: 'aa', name: 'Fethiye', province: 'Muğla' },
  waterBody: { id: 'wb', name: 'Göcek Körfezi', type: 'gulf' },
  dimensions: { maxBoatLengthM: 25, maxDraftM: 4, depthMinM: 7, depthMaxM: 8, capacity: 18 },
  priceTier: 'paid',
  is24h: false,
  verifiedAt: '2026-08-01T00:00:00.000Z',
  ratingAvg: 4.4,
  ratingCount: 12,
  reviewCount: 12,
  photoCount: 6,
  cover: {
    url: 'https://upload.wikimedia.org/wikipedia/commons/x.jpg',
    blurhash: null,
    credit: 'Foto: Jane Doe',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:X.jpg',
  },
  amenities: [{ code: 'water', category: 'utility', translations: [{ locale: 'tr', name: 'Su' }] }],
  services: [{ code: 'mooring_assist', translations: [{ locale: 'tr', name: 'Palamar' }] }],
  contacts: [{ type: 'phone', value: '+90 555 000 00 00', isPrimary: true }],
  hours: [{ dayOfWeek: 1, opensAt: '08:00', closesAt: '22:00' }],
  seasons: [{ opensOn: '05-01', closesOn: '10-31' }],
  typeDetails: {
    kind: 'anchorage',
    holdingType: 'mud',
    protectionN: 5,
    protectionS: 2,
    protectionE: 4,
    protectionW: 3,
    swellExposure: 'low',
    isFree: false,
  },
  ratingDimensions: [{ code: 'shelter', avg: 4.8 }],
  occupancy: { level: 'moderate', reportedAt: '2026-09-21T09:00:00.000Z', reportCount: 2 },
  windExposedDirs: 'G,GD',
  seabed: 'mud',
  shelteredDirs: 'K,KB',
};

class FakeRepo implements LocationsRepository {
  findPinsInBbox(): Promise<never[]> {
    return Promise.resolve([]);
  }
  reportOccupancy(): Promise<OccupancySummary | 'too-far' | 'unsupported' | null> {
    return Promise.resolve(null);
  }
  findNearby(): Promise<never[]> {
    return Promise.resolve([]);
  }
  findClusters(): Promise<never[]> {
    return Promise.resolve([]);
  }
  findDetail(idOrSlug: string): Promise<DetailData | null> {
    return Promise.resolve(idOrSlug === 'kille-koyu' ? SAMPLE : null);
  }
  findSearch(): Promise<never[]> {
    return Promise.resolve([]);
  }
  findReviews(): Promise<never[]> {
    return Promise.resolve([]);
  }
}

/** Sahte erişim kararı — birim test, kararı DIŞARIDAN verir. */
function premiumStub(
  decision: AccessDecision,
  unlockResult?: { remaining: number } | AppProblem,
): PremiumAccessService {
  return {
    accessFor: () => Promise.resolve(decision),
    unlock: () => {
      if (unlockResult instanceof AppProblem) return Promise.reject(unlockResult);
      return Promise.resolve(unlockResult ?? { remaining: 0 });
    },
  } as unknown as PremiumAccessService;
}

const MEMBER: Principal = { userId: 'u1', role: 'user', isGuest: false, familyId: 'f', jti: 'j' };

describe('Detay vitrini (P1 — premium v3 raporu §3)', () => {
  it('premium servis YOKKEN (birim kurulumları) detay full döner', async () => {
    const d = await new LocationsService(new FakeRepo()).detail('kille-koyu', 'tr');
    expect(d.access).toBe('full');
    expect(d.explorationRemaining).toBeNull();
    expect(d.description).toBe('Uzun açıklama — Premium.');
  });

  it('karar full ise gövde tam iner', async () => {
    const svc = new LocationsService(
      new FakeRepo(),
      premiumStub({ access: 'full', explorationRemaining: null }),
    );
    const d = await svc.detail('kille-koyu', 'tr', MEMBER);
    expect(d.access).toBe('full');
    expect(d.contacts).toHaveLength(1);
    expect(d.typeDetails?.kind).toBe('anchorage');
    expect(d.occupancy).not.toBeNull();
  });

  it('karar teaser ise: kilitli alanlar İNMEZ, vitrin + güvenlik özeti kalır', async () => {
    const svc = new LocationsService(
      new FakeRepo(),
      premiumStub({ access: 'teaser', explorationRemaining: 2 }),
    );
    const d = await svc.detail('kille-koyu', 'tr', MEMBER);

    expect(d.access).toBe('teaser');
    expect(d.explorationRemaining).toBe(2);

    // KİLİTLİ (istemciye inmez): açıklama, olanak/hizmet, iletişim, saatler,
    // sezonlar, alt-tip detayı, doluluk, kapasite, puan kırılımı.
    expect(d.description).toBeNull();
    expect(d.amenities).toEqual([]);
    expect(d.services).toEqual([]);
    expect(d.contacts).toEqual([]);
    expect(d.hours).toEqual([]);
    expect(d.seasons).toEqual([]);
    expect(d.typeDetails).toBeNull();
    expect(d.occupancy).toBeNull();
    expect(d.dimensions.capacity).toBeNull();
    expect(d.rating.dimensions).toEqual([]);

    // VİTRİN (açık kalır): kimlik + konum + kapak + sayılar + puan özeti.
    expect(d.name).toBe('Kille Koyu');
    expect(d.position).toEqual({ lat: 36.6844, lon: 28.8921 });
    expect(d.media.cover?.url).toContain('wikimedia');
    expect(d.media.cover?.credit).toBe('Foto: Jane Doe'); // CC atfı vitrinde de zorunlu
    expect(d.counts).toEqual({ reviews: 12, photos: 6 });
    expect(d.rating.avg).toBe(4.4);
    expect(d.rating.count).toBe(12);

    // GÜVENLİK ÖZETİ (kurucu kararı K1: derinlik/zemin/korunak/rüzgâr açık).
    expect(d.dimensions.depthMinM).toBe(7);
    expect(d.dimensions.depthMaxM).toBe(8);
    expect(d.seabed).toBe('mud');
    expect(d.shelteredDirs).toBe('K,KB');
    expect(d.windExposedDirs).toBe('G,GD');
    expect(d.dimensions.maxBoatLengthM).toBe(25); // pin'de zaten herkese açık
  });

  it('toTeaserDetail girdi nesnesini DEĞİŞTİRMEZ (saf fonksiyon)', async () => {
    const full = await new LocationsService(new FakeRepo()).detail('kille-koyu', 'tr');
    const teaser = toTeaserDetail(full);
    expect(teaser).not.toBe(full);
    expect(full.contacts).toHaveLength(1); // orijinal bozulmadı
    expect(teaser.contacts).toEqual([]);
  });

  it('unlock: tam detay + kalan hak döner', async () => {
    const svc = new LocationsService(
      new FakeRepo(),
      premiumStub({ access: 'teaser', explorationRemaining: 3 }, { remaining: 2 }),
    );
    const r = await svc.unlock('kille-koyu', 'tr', MEMBER);
    expect(r.remaining).toBe(2);
    expect(r.detail.access).toBe('full');
    expect(r.detail.contacts).toHaveLength(1);
  });

  it('unlock: bilinmeyen koy 404; kota dolunca 403 quota-exceeded yüzeye çıkar', async () => {
    const okSvc = new LocationsService(
      new FakeRepo(),
      premiumStub({ access: 'teaser', explorationRemaining: 0 }, new AppProblem('quota-exceeded')),
    );
    await expect(okSvc.unlock('yok-boyle-koy', 'tr', MEMBER)).rejects.toMatchObject({
      problemType: 'not-found',
    });
    await expect(okSvc.unlock('kille-koyu', 'tr', MEMBER)).rejects.toMatchObject({
      problemType: 'quota-exceeded',
    });
  });
});
