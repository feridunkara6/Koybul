import { LocationsService } from '../src/modules/locations/application/locations.service';
import { AppProblem } from '../src/common/problem/problem';
import {
  DetailData,
  LocationsRepository,
} from '../src/modules/locations/domain/locations.repository';
import { OccupancySummary } from '../src/modules/locations/domain/location.types';

const SAMPLE: DetailData = {
  id: 'loc-1',
  slug: 'd-marin',
  type: 'private_marina',
  status: 'published',
  baseName: 'D-Marin',
  baseDescription: 'base desc',
  i18n: [
    { locale: 'tr', name: 'D-Marin Göcek', description: 'TR açıklama' },
    { locale: 'en', name: 'D-Marin Gocek', description: 'EN desc' },
  ],
  lat: 36.75,
  lon: 28.95,
  countryCode: 'TR',
  adminArea: { id: 'aa', name: 'Fethiye', province: 'Muğla' },
  waterBody: { id: 'wb', name: 'Göcek Körfezi', type: 'gulf' },
  dimensions: { maxBoatLengthM: 40, maxDraftM: 5, depthMinM: 3, depthMaxM: 12, capacity: 380 },
  priceTier: 'paid',
  is24h: true,
  verifiedAt: '2026-08-01T00:00:00.000Z',
  ratingAvg: 4.6,
  ratingCount: 50,
  reviewCount: 50,
  photoCount: 24,
  cover: null,
  amenities: [
    {
      code: 'electricity',
      category: 'utility',
      translations: [
        { locale: 'tr', name: 'Elektrik' },
        { locale: 'en', name: 'Electricity' },
      ],
    },
  ],
  services: [{ code: 'mooring_assist', translations: [{ locale: 'tr', name: 'Palamar' }] }],
  contacts: [{ type: 'phone', value: '+90', isPrimary: true }],
  hours: [{ dayOfWeek: 1, opensAt: '08:00', closesAt: '22:00' }],
  seasons: [{ opensOn: '05-01', closesOn: '10-31' }],
  typeDetails: {
    kind: 'marina',
    berthCount: 380,
    vhfChannel: '72',
    hasBlueFlag: true,
    travelLiftCapacityTons: 100,
    craneCapacityTons: null,
    winterStorage: true,
  },
  ratingDimensions: [
    { code: 'shelter', avg: 4.9 },
    { code: 'staff', avg: 4.7 },
  ],
};

/** Alt-tip detayı olmayan lokasyon (ör. şamandıra) — typeDetails null yolu. */
const BARE: DetailData = { ...SAMPLE, slug: 'bare', typeDetails: null, ratingDimensions: [] };

/** Dış (CC/Commons) lisanslı kapak görseli olan lokasyon — atıf geçişi. */
const WITHCOVER: DetailData = {
  ...SAMPLE,
  slug: 'covered',
  cover: {
    url: 'https://upload.wikimedia.org/wikipedia/commons/x.jpg',
    blurhash: null,
    credit: 'Foto: Jane Doe',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:X.jpg',
  },
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
    if (idOrSlug === 'd-marin') return Promise.resolve(SAMPLE);
    if (idOrSlug === 'bare') return Promise.resolve(BARE);
    if (idOrSlug === 'covered') return Promise.resolve(WITHCOVER);
    return Promise.resolve(null);
  }
  // Arayüz büyüdüğünde sahte de büyümeli — eksik kalırsa PAKET DERLENMEZ
  // (2026-08'de tam olarak bu oldu: findSearch/findReviews eklendi, sahte kalmadı).
  findSearch(): Promise<never[]> {
    return Promise.resolve([]);
  }
  findReviews(): Promise<never[]> {
    return Promise.resolve([]);
  }
}

describe('LocationsService.detail (docs/23 §11.3)', () => {
  const service = new LocationsService(new FakeRepo());

  it('tr locale: TR isim + etiketler + province', async () => {
    const d = await service.detail('d-marin', 'tr');
    expect(d.name).toBe('D-Marin Göcek');
    expect(d.description).toBe('TR açıklama');
    expect(d.amenities[0].label).toBe('Elektrik');
    expect(d.services[0].label).toBe('Palamar');
    expect(d.geo.adminArea?.province).toBe('Muğla');
    expect(d.geo.waterBody?.type).toBe('gulf');
    expect(d.hours[0]).toEqual({ dayOfWeek: 1, opensAt: '08:00', closesAt: '22:00' });
    expect(d.seasons[0]).toEqual({ opensOn: '05-01', closesOn: '10-31' });
  });

  it('en locale: EN isim + etiket', async () => {
    const d = await service.detail('d-marin', 'en');
    expect(d.name).toBe('D-Marin Gocek');
    expect(d.amenities[0].label).toBe('Electricity');
  });

  it('es locale: ES açıklama seçilir; adı olmayan i18n satırı adı DEĞİŞTİRMEZ', async () => {
    // Veri çevirisi kuralı (kullanıcı kararı 2026-07): koy adları çevrilmez —
    // seed'in yazdığı es/ru satırlarında name NULL kalır, ad zincirden gelir.
    const withEs: DetailData = {
      ...SAMPLE,
      slug: 'with-es',
      i18n: [
        { locale: 'tr', name: 'D-Marin Göcek', description: 'TR açıklama' },
        { locale: 'es', name: null, description: 'Descripción ES' },
      ],
    };
    class EsRepo extends FakeRepo {
      override findDetail(): Promise<DetailData> {
        return Promise.resolve(withEs);
      }
    }
    const d = await new LocationsService(new EsRepo()).detail('with-es', 'es');
    expect(d.description).toBe('Descripción ES');
    expect(d.name).toBe('D-Marin'); // es name null, en satırı yok → baseName
  });

  it('doluluk: repo özet vermezse null, verirse aynen geçer', async () => {
    const d = await service.detail('d-marin', 'tr');
    expect(d.occupancy).toBeNull();

    const withOcc: DetailData = {
      ...SAMPLE,
      occupancy: { level: 'full', reportedAt: '2026-07-15T10:00:00.000Z', reportCount: 3 },
    };
    class OccRepo extends FakeRepo {
      override findDetail(): Promise<DetailData> {
        return Promise.resolve(withOcc);
      }
    }
    const d2 = await new LocationsService(new OccRepo()).detail('d-marin', 'tr');
    expect(d2.occupancy).toEqual({
      level: 'full',
      reportedAt: '2026-07-15T10:00:00.000Z',
      reportCount: 3,
    });
  });

  it('rüzgâra açık yönler: yoksa null, varsa aynen geçer', async () => {
    const d = await service.detail('d-marin', 'tr');
    expect(d.windExposedDirs).toBeNull();

    const withWind: DetailData = { ...SAMPLE, windExposedDirs: 'G,GD' };
    class WindRepo extends FakeRepo {
      override findDetail(): Promise<DetailData> {
        return Promise.resolve(withWind);
      }
    }
    const d2 = await new LocationsService(new WindRepo()).detail('d-marin', 'tr');
    expect(d2.windExposedDirs).toBe('G,GD');
  });

  it('doluluk bildirimi: bilinmeyen lokasyon → not-found', async () => {
    await expect(
      service.reportOccupancy('yok-boyle-koy', 'user-1', 'full', { lat: 36.75, lon: 28.95 }),
    ).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('doluluk bildirimi: koydan uzak konum → validation-error (too_far)', async () => {
    class FarRepo extends FakeRepo {
      override reportOccupancy(): Promise<'too-far'> {
        return Promise.resolve('too-far' as const);
      }
    }
    await expect(
      new LocationsService(new FarRepo()).reportOccupancy('d-marin', 'user-1', 'full', {
        lat: 41.0,
        lon: 29.0,
      }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('doluluk bildirimi: desteklenmeyen tür (marina/liman) → validation-error', async () => {
    class UnsupportedRepo extends FakeRepo {
      override reportOccupancy(): Promise<'unsupported'> {
        return Promise.resolve('unsupported' as const);
      }
    }
    await expect(
      new LocationsService(new UnsupportedRepo()).reportOccupancy('d-marin', 'user-1', 'full', {
        lat: 36.75,
        lon: 28.95,
      }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('doluluk bildirimi: özet döner', async () => {
    class ReportRepo extends FakeRepo {
      override reportOccupancy(): Promise<{
        level: 'moderate';
        reportedAt: string;
        reportCount: number;
      }> {
        return Promise.resolve({
          level: 'moderate' as const,
          reportedAt: '2026-07-15T11:00:00.000Z',
          reportCount: 2,
        });
      }
    }
    const res = await new LocationsService(new ReportRepo()).reportOccupancy(
      'd-marin',
      'user-1',
      'moderate',
      { lat: 36.75, lon: 28.95 },
    );
    expect(res.occupancy.level).toBe('moderate');
    expect(res.occupancy.reportCount).toBe(2);
  });

  it("ru çevirisi henüz yoksa açıklama EN'e düşer (fallback zinciri)", async () => {
    const d = await service.detail('d-marin', 'ru');
    expect(d.description).toBe('EN desc');
    expect(d.name).toBe('D-Marin Gocek'); // en satırındaki ad
  });

  it('typeDetails (marina) + rating.dimensions geçirilir', async () => {
    const d = await service.detail('d-marin', 'tr');
    expect(d.typeDetails).toEqual({
      kind: 'marina',
      berthCount: 380,
      vhfChannel: '72',
      hasBlueFlag: true,
      travelLiftCapacityTons: 100,
      craneCapacityTons: null,
      winterStorage: true,
    });
    expect(d.rating).toEqual({
      avg: 4.6,
      count: 50,
      dimensions: [
        { code: 'shelter', avg: 4.9 },
        { code: 'staff', avg: 4.7 },
      ],
    });
  });

  it('alt-tip detayı yoksa typeDetails null, rating.dimensions boş', async () => {
    const d = await service.detail('bare', 'tr');
    expect(d.typeDetails).toBeNull();
    expect(d.rating.dimensions).toEqual([]);
  });

  it('kapak görseli yoksa media.cover null (userContext de null)', async () => {
    const d = await service.detail('d-marin', 'tr');
    expect(d.media).toEqual({ cover: null, count: 24 });
    expect(d.userContext).toBeNull();
    expect(d.counts).toEqual({ reviews: 50, photos: 24 });
  });

  it('dış lisanslı kapak görseli, atıf alanlarıyla (credit/license/source) geçirilir', async () => {
    const d = await service.detail('covered', 'tr');
    expect(d.media.cover).toEqual({
      url: 'https://upload.wikimedia.org/wikipedia/commons/x.jpg',
      blurhash: null,
      credit: 'Foto: Jane Doe',
      license: 'CC BY-SA 4.0',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:X.jpg',
    });
    expect(d.media.count).toBe(24);
  });

  it('bulunamayan id/slug → not-found (AppProblem)', async () => {
    await expect(service.detail('yok', 'tr')).rejects.toBeInstanceOf(AppProblem);
  });
});
