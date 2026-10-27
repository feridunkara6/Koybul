import { RoutesService } from '../src/modules/routes/application/routes.service';
import {
  CreateRouteInput,
  RouteRow,
  RouteSort,
  RouteStopView,
  RoutesRepository,
} from '../src/modules/routes/domain/route.types';
import { Principal } from '../src/core/auth/principal';

/** ROTA PAYLAŞIMI servis testleri (Hafta 3, kurucu onayı 2026-10-24). */

const NOW = new Date('2026-10-25T10:00:00Z');

function member(userId = 'u-1'): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}
function admin(): Principal {
  return { userId: 'u-admin', role: 'admin', isGuest: false, familyId: 'f', jti: 'j' };
}

const LOC_A = '00000000-0000-4000-a000-00000000000a';
const LOC_B = '00000000-0000-4000-a000-00000000000b';
const LOC_C = '00000000-0000-4000-a000-00000000000c';

function row(partial: Partial<RouteRow>): RouteRow {
  return {
    id: 'r1',
    userId: 'author-1',
    name: '12 Adalar klasiği',
    body: 'Öğlen meltemi güçlenmeden Yassıca molasını verin; dönüşü erken planlayın.',
    season: 'Nisan-Ekim',
    boatSuggestion: null,
    distanceNm: '14.0',
    durationHours: '4.0',
    status: 'approved',
    saveCount: 23,
    doneCount: 4,
    createdAt: new Date('2026-10-20T08:00:00Z'),
    authorName: 'Meltem Y.',
    startName: 'Göcek',
    endName: 'Bedri Rahmi',
    stopCount: 4,
    ...partial,
  };
}

class FakeRoutesRepo implements RoutesRepository {
  rows: RouteRow[] = [];
  stops: RouteStopView[] = [];
  publishedIds = new Set<string>([LOC_A, LOC_B, LOC_C]);
  monthly = 0;
  created: CreateRouteInput[] = [];
  saves = new Set<string>(); // `${routeId}|${userId}`
  dones = new Set<string>();

  async list(_s: RouteSort, locationId: string | null, _l: number): Promise<RouteRow[]> {
    return this.rows.filter((r) => r.status === 'approved' && (locationId === null || true));
  }
  async listOwnPending(userId: string, _l: number): Promise<RouteRow[]> {
    return this.rows.filter((r) => r.status === 'pending' && r.userId === userId);
  }
  async findRoute(routeId: string): Promise<RouteRow | null> {
    return this.rows.find((r) => r.id === routeId) ?? null;
  }
  async stopsFor(): Promise<RouteStopView[]> {
    return this.stops;
  }
  async publishedLocationCount(ids: string[]): Promise<number> {
    return ids.filter((i) => this.publishedIds.has(i)).length;
  }
  async monthlyCount(): Promise<number> {
    return this.monthly;
  }
  async create(id: string, userId: string, input: CreateRouteInput): Promise<RouteRow> {
    this.created.push(input);
    const r = row({
      id,
      userId,
      name: input.name,
      status: 'pending',
      stopCount: input.stopLocationIds.length,
    });
    this.rows.push(r);
    return r;
  }
  async savedBy(routeId: string, userId: string): Promise<boolean> {
    return this.saves.has(`${routeId}|${userId}`);
  }
  async doneBy(routeId: string, userId: string): Promise<boolean> {
    return this.dones.has(`${routeId}|${userId}`);
  }
  async toggleSave(routeId: string, userId: string) {
    const k = `${routeId}|${userId}`;
    const saved = !this.saves.has(k);
    if (saved) this.saves.add(k);
    else this.saves.delete(k);
    return { saved, saveCount: this.saves.size };
  }
  async toggleDone(routeId: string, userId: string) {
    const k = `${routeId}|${userId}`;
    const done = !this.dones.has(k);
    if (done) this.dones.add(k);
    else this.dones.delete(k);
    return { done, doneCount: this.dones.size };
  }
  async softDelete(routeId: string, userId: string): Promise<boolean> {
    const r = this.rows.find((x) => x.id === routeId && x.userId === userId);
    if (!r) return false;
    this.rows = this.rows.filter((x) => x !== r);
    return true;
  }
}

function makeSvc(opts: { enforce: boolean; premiumIds?: string[] }) {
  const repo = new FakeRoutesRepo();
  const env = { premiumEnforce: opts.enforce } as never;
  const premium = {
    isPremium: async (userId: string) => (opts.premiumIds ?? []).includes(userId),
  } as never;
  return { svc: new RoutesService(env, premium, repo), repo };
}

const VALID: CreateRouteInput = {
  name: '12 Adalar klasiği',
  body: 'Ö'.repeat(80),
  distanceNm: 14,
  durationHours: 4,
  stopLocationIds: [LOC_A, LOC_B, LOC_A],
};

describe('RoutesService (Rota Paylaşımı V1 — Hafta 3)', () => {
  it('create: rota PENDING doğar (her rota moderasyondan geçer)', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    const res = await svc.create(member(), VALID, NOW);
    expect(res.status).toBe('pending');
    expect(repo.created).toHaveLength(1);
    expect(repo.created[0].stopLocationIds).toEqual([LOC_A, LOC_B, LOC_A]);
  });

  it('create: tek durak ve ardışık tekrar reddedilir', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    await expect(
      svc.create(member(), { ...VALID, stopLocationIds: [LOC_A] }, NOW),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
    await expect(
      svc.create(member(), { ...VALID, stopLocationIds: [LOC_A, LOC_A] }, NOW),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
    expect(repo.created).toHaveLength(0);
  });

  it('create: katalogda olmayan durak reddedilir (uydurma koy yok)', async () => {
    const { svc } = makeSvc({ enforce: false });
    const ghost = '00000000-0000-4000-a000-0000000000ff';
    await expect(
      svc.create(member(), { ...VALID, stopLocationIds: [LOC_A, ghost] }, NOW),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('AYLIK TAVAN: bayrak açıkken ücretsiz üye 2 rotadan sonra premium-required', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.monthly = 2;
    await expect(svc.create(member(), VALID, NOW)).rejects.toMatchObject({
      problemType: 'premium-required',
    });
    // Premium üye ve admin muaf; bayrak kapalıyken herkes muaf.
    const prem = makeSvc({ enforce: true, premiumIds: ['u-prem'] });
    prem.repo.monthly = 99;
    await expect(prem.svc.create(member('u-prem'), VALID, NOW)).resolves.toMatchObject({
      status: 'pending',
    });
    const adm = makeSvc({ enforce: true });
    adm.repo.monthly = 99;
    await expect(adm.svc.create(admin(), VALID, NOW)).resolves.toBeTruthy();
    const kapali = makeSvc({ enforce: false });
    kapali.repo.monthly = 99;
    await expect(kapali.svc.create(member(), VALID, NOW)).resolves.toBeTruthy();
  });

  it('detail: bekleyen rota yalnız sahibine; reddedilen herkese 404', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.rows.push(row({ id: 'r-pend', status: 'pending', userId: 'author-1' }));
    repo.rows.push(row({ id: 'r-rej', status: 'rejected' }));

    const own = await svc.detail(member('author-1'), 'r-pend');
    expect(own.mine).toBe(true);
    expect(own.status).toBe('pending');

    await expect(svc.detail(member('u-2'), 'r-pend')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    await expect(svc.detail(null, 'r-rej')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('detail: anonim bakan savedByMe/doneByMe false alır; sayılar eşlenir', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.rows.push(row({ id: 'r1' }));
    const d = await svc.detail(null, 'r1');
    expect(d.savedByMe).toBe(false);
    expect(d.doneByMe).toBe(false);
    expect(d.distanceNm).toBe(14);
    expect(d.saveCount).toBe(23);
    expect(d.authorId).toBe('author-1');
  });

  it('toggleSave/toggleDone: yayındaki rotada aç/kapa çalışır', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.rows.push(row({ id: 'r1' }));
    const s1 = await svc.toggleSave(member('u-2'), 'r1');
    expect(s1.saved).toBe(true);
    const s2 = await svc.toggleSave(member('u-2'), 'r1');
    expect(s2.saved).toBe(false);
    const d1 = await svc.toggleDone(member('u-2'), 'r1');
    expect(d1.done).toBe(true);
  });

  it('toggleSave: bekleyen rotaya yabancı dokunamaz (404 — sızdırmaz)', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.rows.push(row({ id: 'r-pend', status: 'pending', userId: 'author-1' }));
    await expect(svc.toggleSave(member('u-2'), 'r-pend')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('remove: sahip siler; başkasının rotası 404', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.rows.push(row({ id: 'r1', userId: 'author-1' }));
    await expect(svc.remove(member('u-2'), 'r1')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    await svc.remove(member('author-1'), 'r1');
    expect(repo.rows).toHaveLength(0);
  });

  // SAHA İSTEĞİ (2026-10-27, "paylaştım ama görünmüyor"): kimlikli liste
  // bakanın KENDİ bekleyenlerini BAŞA koyar; anonim liste yalnız onaylı görür.
  it('list: kimlikli istekte kendi bekleyen rotalar başa gelir; anonimde yok', async () => {
    const { svc, repo } = makeSvc({ enforce: false });
    repo.rows = [
      row({ id: 'a1', status: 'approved', name: 'Onaylı tur' }),
      row({ id: 'p1', status: 'pending', userId: 'u1', name: 'Benim bekleyen' }),
      row({ id: 'p2', status: 'pending', userId: 'u2', name: 'Başkasının bekleyeni' }),
    ];

    const anon = await svc.list(null, 'new', null, 20);
    expect(anon.map((r) => r.id)).toEqual(['a1']);
    expect(anon[0].status).toBe('approved');

    const mine = await svc.list(member('u1'), 'new', null, 20);
    expect(mine.map((r) => r.id)).toEqual(['p1', 'a1']); // bekleyen BAŞTA
    expect(mine[0].status).toBe('pending'); // rozet için durum dolu
    // Başkasının bekleyeni ASLA sızmaz.
    expect(mine.some((r) => r.id === 'p2')).toBe(false);
  });
});
