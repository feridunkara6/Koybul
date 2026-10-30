import { BoatsService } from '../src/modules/boats/application/boats.service';
import { BoatRepository, LookupResolution } from '../src/modules/boats/domain/boat.repository';
import {
  Boat,
  CreateBoatInput,
  FavoriteBoatRef,
  PublicBoatCard,
  UpdateBoatInput,
} from '../src/modules/boats/domain/boat.types';
import { Principal } from '../src/core/auth/principal';

const P: Principal = { userId: 'owner-1', role: 'user', isGuest: false, familyId: 'f', jti: 'j' };

function boat(over: Partial<Boat> = {}): Boat {
  return {
    id: 'b1',
    name: 'Poyraz',
    boatTypeCode: 'sailboat',
    brand: null,
    model: null,
    buildYear: null,
    lengthM: 12.4,
    beamM: null,
    draftM: null,
    engineTypeCode: null,
    flagCountryCode: null,
    registrationNo: null,
    isPrimary: false,
    createdAt: '2026-07-07T00:00:00.000Z',
    ...over,
  };
}

/** Birincil tekne kuralını ve tavanı in-memory simüle eden depo. */
class FakeBoatRepo implements BoatRepository {
  rows: Boat[] = [];
  validBoatTypes = new Set(['sailboat', 'motor_yacht', 'other']);
  validEngineTypes = new Set(['outboard', 'inboard_diesel']);
  validCountries = new Set(['TR', 'GR']);

  async listByOwner(): Promise<Boat[]> {
    return [...this.rows]
      .filter((b) => b)
      .sort((a, b) => Number(b.isPrimary) - Number(a.isPrimary));
  }
  async findOwned(_o: string, id: string): Promise<Boat | null> {
    return this.rows.find((b) => b.id === id) ?? null;
  }
  async countActiveByOwner(): Promise<number> {
    return this.rows.length;
  }
  async resolveLookups(input: {
    boatTypeCode?: string;
    engineTypeCode?: string | null;
    flagCountryCode?: string | null;
  }): Promise<LookupResolution> {
    return {
      boatTypeId: input.boatTypeCode
        ? this.validBoatTypes.has(input.boatTypeCode)
          ? 1
          : null
        : null,
      engineTypeId: input.engineTypeCode
        ? this.validEngineTypes.has(input.engineTypeCode)
          ? 2
          : null
        : null,
      countryValid: input.flagCountryCode ? this.validCountries.has(input.flagCountryCode) : true,
    };
  }
  async create(id: string, _o: string, input: CreateBoatInput): Promise<Boat> {
    const makePrimary = this.rows.length === 0 || input.isPrimary === true;
    if (makePrimary) this.rows.forEach((b) => (b.isPrimary = false));
    const created = boat({
      id,
      name: input.name,
      boatTypeCode: input.boatTypeCode,
      lengthM: input.lengthM,
      isPrimary: makePrimary,
    });
    this.rows.push(created);
    return created;
  }
  async update(_o: string, id: string, patch: UpdateBoatInput): Promise<Boat> {
    if (patch.isPrimary === true) this.rows.forEach((b) => (b.isPrimary = b.id === id));
    const row = this.rows.find((b) => b.id === id)!;
    Object.assign(row, {
      ...(patch.name !== undefined ? { name: patch.name } : {}),
      ...(patch.lengthM !== undefined ? { lengthM: patch.lengthM } : {}),
      ...(patch.isPrimary === true ? { isPrimary: true } : {}),
    });
    return row;
  }
  async softDelete(_o: string, id: string): Promise<void> {
    this.rows = this.rows.filter((b) => b.id !== id);
  }
  async promoteNewPrimaryIfNeeded(): Promise<void> {
    if (this.rows.length === 0) return;
    if (!this.rows.some((b) => b.isPrimary)) {
      this.rows[this.rows.length - 1].isPrimary = true;
    }
  }
  // TEKNE KARTI (Hafta 2): sahte kart — null = görünmez/yok (servis 404'ler).
  publicCards = new Map<string, PublicBoatCard>();
  async publicCard(boatId: string): Promise<PublicBoatCard | null> {
    return this.publicCards.get(boatId) ?? null;
  }
  // FAVORİLE (TK-5, 0025): görünür kartı olan tekne favorilenebilir.
  favorites = new Set<string>(); // "userId|boatId"
  async addFavorite(userId: string, boatId: string): Promise<boolean> {
    const card = this.publicCards.get(boatId);
    if (!card || card.captain.userId === userId) return false;
    this.favorites.add(`${userId}|${boatId}`);
    return true;
  }
  async removeFavorite(userId: string, boatId: string): Promise<void> {
    this.favorites.delete(`${userId}|${boatId}`);
  }
  async countFavoritesByUser(userId: string): Promise<number> {
    return [...this.favorites].filter((k) => k.startsWith(`${userId}|`)).length;
  }
  async listFavorites(userId: string): Promise<FavoriteBoatRef[]> {
    return [...this.favorites]
      .filter((k) => k.startsWith(`${userId}|`))
      .map((k) => k.split('|')[1])
      .filter((id) => this.publicCards.has(id)) // yalnız hâlâ görünür tekneler
      .map((id) => {
        const c = this.publicCards.get(id)!;
        return {
          id: c.id,
          name: c.name,
          boatTypeCode: c.boatTypeCode,
          brand: c.brand,
          model: c.model,
          marinaName: c.marina?.name ?? null,
        };
      });
  }
}

describe('BoatsService (birincil tekne + doğrulama, docs/23 §10 #7)', () => {
  let repo: FakeBoatRepo;
  let service: BoatsService;

  beforeEach(() => {
    repo = new FakeBoatRepo();
    service = new BoatsService(repo);
  });

  it('ilk tekne otomatik birincil olur', async () => {
    const b = await service.create(P, { name: 'Poyraz', boatTypeCode: 'sailboat', lengthM: 12.4 });
    expect(b.isPrimary).toBe(true);
  });

  it('ikinci tekne birincil olmaz; isPrimary=true verilince devreder', async () => {
    const first = await service.create(P, { name: 'A', boatTypeCode: 'sailboat', lengthM: 10 });
    const second = await service.create(P, {
      name: 'B',
      boatTypeCode: 'motor_yacht',
      lengthM: 8,
      isPrimary: true,
    });
    expect(second.isPrimary).toBe(true);
    const list = await service.list(P);
    expect(list.find((b) => b.id === first.id)!.isPrimary).toBe(false);
    // Tek birincil değişmezi: tam olarak bir birincil olmalı
    expect(list.filter((b) => b.isPrimary)).toHaveLength(1);
  });

  it('geçersiz tekne tipi → 422 alan hatası (boatTypeCode)', async () => {
    await expect(
      service.create(P, { name: 'X', boatTypeCode: 'uzay_gemisi', lengthM: 5 }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('geçersiz motor/ülke kodu → 422', async () => {
    await expect(
      service.create(P, {
        name: 'X',
        boatTypeCode: 'sailboat',
        lengthM: 5,
        engineTypeCode: 'nukleer',
      }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
    await expect(
      service.create(P, { name: 'X', boatTypeCode: 'sailboat', lengthM: 5, flagCountryCode: 'ZZ' }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('başkasının teknesi / yok → 404 (sızdırmaz)', async () => {
    await expect(service.getOne(P, 'yok')).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('birincil tekne silinince en yeni aktif tekne birincil olur', async () => {
    await service.create(P, { name: 'A', boatTypeCode: 'sailboat', lengthM: 10 }); // primary
    const b = await service.create(P, { name: 'B', boatTypeCode: 'motor_yacht', lengthM: 8 });
    const primary = (await service.list(P)).find((x) => x.isPrimary)!;
    await service.remove(P, primary.id);
    const list = await service.list(P);
    expect(list).toHaveLength(1);
    expect(list[0].isPrimary).toBe(true);
    expect(list[0].id).toBe(b.id);
  });

  it('25 tekne tavanı aşımında conflict-state', async () => {
    for (let i = 0; i < 25; i++) {
      await service.create(P, { name: `B${i}`, boatTypeCode: 'other', lengthM: 5 });
    }
    await expect(
      service.create(P, { name: 'fazla', boatTypeCode: 'other', lengthM: 5 }),
    ).rejects.toMatchObject({ problemType: 'conflict-state' });
  });

  it('TEKNE KARTI (Hafta 2): görünür tekne döner; görünmez/yok AYNI 404', async () => {
    const card: PublicBoatCard = {
      id: 'b-marti',
      name: 'Martı',
      boatTypeCode: 'sailboat',
      brand: 'Beneteau',
      model: 'Oceanis 38.1',
      lengthM: 11.5,
      buildYear: 2019,
      marina: { id: 'loc-marti', name: 'Martı Marina' },
      captain: { userId: 'u-1', displayName: 'Kaptan Levent', levelCode: 'guide' },
      // 0024: hikâye + türetilmiş istatistikler + rota listesi.
      story: null,
      stats: { sharedTrips: 0, sharedRoutes: 0, pruvaTotal: 0 },
      routes: [],
      // TK-5 (0025): favori sayısı + kaptan takipçisi + kardeş tekneler.
      favoriteCount: 0,
      captainFollowers: 0,
      sisters: [],
    };
    repo.publicCards.set('b-marti', card);

    expect(await service.publicCard('b-marti')).toEqual(card);
    // Depo null dedi (görünmez/silinmiş/yok) → servis ayrım sızdırmadan 404.
    await expect(service.publicCard('b-gizli')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  describe('FAVORİLE (TK-5, 0025 — kurucu onayı 2026-10-30)', () => {
    const kart = (id: string, captainId: string): PublicBoatCard => ({
      id,
      name: 'Martı',
      boatTypeCode: 'sailboat',
      brand: null,
      model: null,
      lengthM: null,
      buildYear: null,
      marina: { id: 'loc-1', name: 'Martı Marina' },
      captain: { userId: captainId, displayName: 'Kaptan', levelCode: 'new' },
      story: null,
      stats: { sharedTrips: 0, sharedRoutes: 0, pruvaTotal: 0 },
      routes: [],
      favoriteCount: 0,
      captainFollowers: 0,
      sisters: [],
    });

    it('görünür tekne favorilenir; liste kendi favorilerini döner', async () => {
      repo.publicCards.set('b1', kart('b1', 'baska-kaptan'));
      await service.favorite(P, 'b1');
      await service.favorite(P, 'b1'); // idempotent — hata yok
      const list = await service.listFavorites(P);
      expect(list).toHaveLength(1);
      expect(list[0].id).toBe('b1');
    });

    it('görünmez/yok tekne ile KENDİ teknesi AYNI 404 (sızdırmaz)', async () => {
      await expect(service.favorite(P, 'yok')).rejects.toMatchObject({
        problemType: 'not-found',
      });
      repo.publicCards.set('benim', kart('benim', P.userId));
      await expect(service.favorite(P, 'benim')).rejects.toMatchObject({
        problemType: 'not-found',
      });
    });

    it('favoriden çıkarma idempotenttir; görünürlük kapanınca listeden düşer', async () => {
      repo.publicCards.set('b1', kart('b1', 'baska-kaptan'));
      await service.favorite(P, 'b1');
      await service.unfavorite(P, 'b1');
      await service.unfavorite(P, 'b1'); // ikinci kez — sessiz
      expect(await service.listFavorites(P)).toHaveLength(0);
      // Rıza ilkesi: favori kayıtlı ama tekne görünmez olunca listelenmez.
      await service.favorite(P, 'b1');
      repo.publicCards.delete('b1');
      expect(await service.listFavorites(P)).toHaveLength(0);
    });
  });
});
