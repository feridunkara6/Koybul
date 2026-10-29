import { TripsService } from '../src/modules/trips/application/trips.service';
import { FeedService } from '../src/modules/trips/application/feed.service';
import {
  ShareTripInput,
  TRIP_DAILY_LIMIT,
  TripsRepository,
} from '../src/modules/trips/domain/trip.types';
import { FeedRepository, FeedRow } from '../src/modules/trips/domain/feed.types';
import { Principal } from '../src/core/auth/principal';

const PRINCIPAL: Principal = {
  userId: 'u-1',
  role: 'user',
  isGuest: false,
  familyId: 'f-1',
  jti: 'j-1',
};

function input(): ShareTripInput {
  return {
    startName: 'Kille Koyu',
    endName: 'Göcek',
    distanceNm: 18.5,
    durationMin: 240,
    stopCount: 2,
    sailedOn: '2026-10-30',
  };
}

class FakeTripsRepo implements TripsRepository {
  todayCount = 0;
  tripExists = true;
  shared: Array<{ id: string; userId: string; input: ShareTripInput }> = [];
  removed: string[] = [];
  reactions = new Set<string>();

  async sharedToday(): Promise<number> {
    return this.todayCount;
  }

  async share(id: string, userId: string, inp: ShareTripInput): Promise<void> {
    this.shared.push({ id, userId, input: inp });
  }

  async remove(tripId: string, userId: string): Promise<boolean> {
    if (!this.tripExists) return false;
    this.removed.push(`${userId}:${tripId}`);
    return true;
  }

  async exists(): Promise<boolean> {
    return this.tripExists;
  }

  async togglePruva(
    tripId: string,
    userId: string,
  ): Promise<{ reacted: boolean; pruvaCount: number }> {
    const key = `${tripId}:${userId}`;
    if (this.reactions.has(key)) {
      this.reactions.delete(key);
      return { reacted: false, pruvaCount: 0 };
    }
    this.reactions.add(key);
    return { reacted: true, pruvaCount: 1 };
  }
}

describe('TripsService (unit)', () => {
  let repo: FakeTripsRepo;
  let service: TripsService;

  beforeEach(() => {
    repo = new FakeTripsRepo();
    service = new TripsService(repo);
  });

  it('share: paylaşım kaydedilir ve id döner', async () => {
    const res = await service.share(PRINCIPAL, input());
    expect(res.id).toBeTruthy();
    expect(repo.shared).toHaveLength(1);
    expect(repo.shared[0].userId).toBe('u-1');
    expect(repo.shared[0].input.endName).toBe('Göcek');
  });

  it(`share: günlük tavan (${TRIP_DAILY_LIMIT}) dolunca 422 daily_limit`, async () => {
    repo.todayCount = TRIP_DAILY_LIMIT;
    await expect(service.share(PRINCIPAL, input())).rejects.toMatchObject({
      problemType: 'validation-error',
    });
    expect(repo.shared).toHaveLength(0);
  });

  it('remove: başkasının/olmayan paylaşımında 404', async () => {
    repo.tripExists = false;
    await expect(service.remove(PRINCIPAL, 't-1')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('togglePruva: aç/kapat; silinmiş paylaşımda 404', async () => {
    const on = await service.togglePruva(PRINCIPAL, 't-1');
    expect(on).toEqual({ reacted: true, pruvaCount: 1 });
    const off = await service.togglePruva(PRINCIPAL, 't-1');
    expect(off.reacted).toBe(false);

    repo.tripExists = false;
    await expect(service.togglePruva(PRINCIPAL, 't-1')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });
});

describe('FeedService (unit)', () => {
  it('following: ham satır tipleri dürüstçe çevrilir (Decimal→sayı, tarih→gün)', async () => {
    const row: FeedRow = {
      kind: 'trip',
      id: 't-1',
      authorId: 'u-2',
      authorName: null, // profil satırı silinmiş → varsayılan ad
      levelCode: null,
      createdAt: new Date('2026-10-30T10:00:00Z'),
      startName: null, // "Konumum" başlangıcı — paylaşılmadı
      endName: 'Göcek',
      distanceNm: '18.5', // numeric ham döner
      durationMin: 240,
      stopCount: 2,
      sailedOn: new Date('2026-10-30T00:00:00Z'),
      pruvaCount: 3,
      myPruva: false,
      locationId: null,
      locationName: null,
      noteKind: null,
      body: null,
      routeName: null,
      saveCount: null,
    };
    const repo: FeedRepository = {
      followingFeed: async () => [row],
    };
    const service = new FeedService(repo);
    const items = await service.following(PRINCIPAL);
    expect(items).toHaveLength(1);
    expect(items[0].authorName).toBe('Koybul Kaptanı');
    expect(items[0].levelCode).toBe('new');
    expect(items[0].distanceNm).toBe(18.5);
    expect(items[0].sailedOn).toBe('2026-10-30');
    expect(items[0].startName).toBeNull();
    expect(items[0].createdAt).toBe('2026-10-30T10:00:00.000Z');
  });
});
