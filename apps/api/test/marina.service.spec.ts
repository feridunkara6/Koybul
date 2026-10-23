import { MarinaService } from '../src/modules/marina/application/marina.service';
import {
  MarinaBoat,
  MarinaRepository,
  MyMarinaBoat,
  UpsertMyBoatInput,
} from '../src/modules/marina/domain/marina.types';
import { PremiumAccessService } from '../src/modules/premium/application/premium-access.service';
import { EnvService } from '../src/config/env.service';
import { Principal } from '../src/core/auth/principal';

const NOW = new Date('2026-10-23T12:00:00.000Z');
const MARTI = 'loc-marti';

function env(premiumEnforce: boolean): EnvService {
  return { premiumEnforce } as unknown as EnvService;
}
function premiumSvc(ids: string[]): PremiumAccessService {
  return {
    isPremium: (u: string) => Promise.resolve(ids.includes(u)),
  } as unknown as PremiumAccessService;
}
function member(userId = 'u1'): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}
function guest(): Principal {
  return { userId: 'g1', role: 'user', isGuest: true, familyId: 'f', jti: 'j' };
}
function admin(): Principal {
  return { userId: 'a1', role: 'admin', isGuest: false, familyId: 'f', jti: 'j' };
}

class FakeMarinaRepo implements MarinaRepository {
  marinas = new Map<string, { id: string; name: string }>([
    [MARTI, { id: MARTI, name: 'Martı Marina' }],
  ]);
  members = new Set<string>(); // `${userId}|${locationId}`
  countsValue = { total: 12, visibleCount: 7 };
  boats: MarinaBoat[] = [
    {
      name: 'Rüzgargülü',
      boatTypeCode: 'sailboat',
      lengthM: 12,
      brand: null,
      captainName: 'Deniz K.',
    },
  ];
  myBoat: MyMarinaBoat | null = null;
  upserts: UpsertMyBoatInput[] = [];
  validTypes = new Set<string>(['sailboat', 'motor_yacht', 'catamaran', 'gulet']);

  marinaInfo(id: string): Promise<{ id: string; name: string } | null> {
    return Promise.resolve(this.marinas.get(id) ?? null);
  }
  findMyBoat(): Promise<MyMarinaBoat | null> {
    return Promise.resolve(this.myBoat);
  }
  upsertMyBoat(userId: string, input: UpsertMyBoatInput): Promise<MyMarinaBoat> {
    this.upserts.push(input);
    const boat: MyMarinaBoat = {
      boatId: 'b1',
      name: input.name,
      boatTypeCode: input.boatTypeCode,
      lengthM: input.lengthM,
      brand: input.brand ?? null,
      marina: this.marinas.get(input.marinaLocationId) ?? null,
      visible: input.visible,
      shareSpecs: input.shareSpecs,
    };
    this.myBoat = boat;
    return Promise.resolve(boat);
  }
  boatTypeValid(code: string): Promise<boolean> {
    return Promise.resolve(this.validTypes.has(code));
  }
  isMemberOf(userId: string, locationId: string): Promise<boolean> {
    return Promise.resolve(this.members.has(`${userId}|${locationId}`));
  }
  counts(): Promise<{ total: number; visibleCount: number }> {
    return Promise.resolve(this.countsValue);
  }
  visibleBoats(): Promise<MarinaBoat[]> {
    return Promise.resolve(this.boats);
  }
}

function makeSvc(opts: { enforce: boolean; premiumIds?: string[] }): {
  svc: MarinaService;
  repo: FakeMarinaRepo;
} {
  const repo = new FakeMarinaRepo();
  return {
    svc: new MarinaService(env(opts.enforce), premiumSvc(opts.premiumIds ?? []), repo),
    repo,
  };
}

const INPUT: UpsertMyBoatInput = {
  name: 'Martı',
  boatTypeCode: 'sailboat',
  lengthM: 10.4,
  brand: 'Beneteau',
  marinaLocationId: MARTI,
  visible: true,
  shareSpecs: false,
};

describe('MarinaService (Marina Topluluğu V1 — kurucu onayı 2026-10-23)', () => {
  it('tekne kaydı: katalogda marina olmayan yer reddedilir (serbest yazı yok)', async () => {
    const { svc } = makeSvc({ enforce: true });
    await expect(
      svc.upsertMyBoat(member(), { ...INPUT, marinaLocationId: 'loc-koy' }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('tekne kaydı: bilinmeyen tekne tipi reddedilir; geçerli kayıt depoya iner', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    await expect(
      svc.upsertMyBoat(member(), { ...INPUT, boatTypeCode: 'uzay-gemisi' }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });

    const boat = await svc.upsertMyBoat(member(), INPUT);
    expect(repo.upserts).toHaveLength(1);
    expect(boat.marina?.name).toBe('Martı Marina');
    expect(boat.visible).toBe(true);
    expect(boat.shareSpecs).toBe(false);
  });

  it('topluluk: marina olmayan kimlik 404', async () => {
    const { svc } = makeSvc({ enforce: true });
    await expect(svc.community(null, 'loc-koy', NOW)).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('topluluk: anonim ve misafir SAYILARI görür, listeyi GÖRMEZ', async () => {
    const { svc } = makeSvc({ enforce: true });
    const anon = await svc.community(null, MARTI, NOW);
    expect(anon.access).toBe('counts');
    expect(anon.total).toBe(12);
    expect(anon.visibleCount).toBe(7);
    expect(anon.boats).toEqual([]); // liste gövdeye hiç yazılmaz

    const g = await svc.community(guest(), MARTI, NOW);
    expect(g.access).toBe('counts');
  });

  it('topluluk: KENDİ marinası olan üye listeyi ücretsiz görür (kurucu kararı)', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.members.add(`u1|${MARTI}`);
    const res = await svc.community(member('u1'), MARTI, NOW);
    expect(res.access).toBe('full');
    expect(res.boats.map((b) => b.name)).toEqual(['Rüzgargülü']);
  });

  it('topluluk: BAŞKA marinayı gezmek Premium ister; premium/admin görür', async () => {
    const { svc } = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    expect((await svc.community(member('u-free'), MARTI, NOW)).access).toBe('counts');
    expect((await svc.community(member('u-prem'), MARTI, NOW)).access).toBe('full');
    expect((await svc.community(admin(), MARTI, NOW)).access).toBe('full');
  });

  it('bayrak KAPALIYKEN liste herkese açık (bugünkü davranış ilkesi)', async () => {
    const { svc } = makeSvc({ enforce: false });
    expect((await svc.community(null, MARTI, NOW)).access).toBe('full');
  });

  it('myBoat: kayıt yoksa null, kayıttan sonra tercihleri taşır', async () => {
    const { svc } = makeSvc({ enforce: true });
    expect(await svc.myBoat(member())).toBeNull();
    await svc.upsertMyBoat(member(), INPUT);
    const mine = await svc.myBoat(member());
    expect(mine?.name).toBe('Martı');
    expect(mine?.visible).toBe(true);
  });
});
