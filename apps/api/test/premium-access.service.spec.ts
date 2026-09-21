import {
  EXPLORATION_MONTHLY_LIMIT,
  PremiumAccessService,
} from '../src/modules/premium/application/premium-access.service';
import { PremiumRepository } from '../src/modules/premium/domain/premium.repository';
import { AppProblem } from '../src/common/problem/problem';
import { EnvService } from '../src/config/env.service';
import { Principal } from '../src/core/auth/principal';

/** Sabit "şimdi": Eylül 2026 — monthKey '2026-09' beklenir. */
const NOW = new Date('2026-09-21T12:00:00.000Z');

function env(premiumEnforce: boolean): EnvService {
  return { premiumEnforce } as unknown as EnvService;
}

function member(userId = 'member-1'): Principal {
  return { userId, role: 'user', isGuest: false, familyId: 'f', jti: 'j' };
}

function guest(userId = 'guest-1'): Principal {
  return { userId, role: 'user', isGuest: true, familyId: 'f', jti: 'j' };
}

/** Bellek-içi sahte defter — gerçek repo ile aynı sözleşme. */
class FakeRepo implements PremiumRepository {
  premiumUntilByUser = new Map<string, Date>();
  unlocks = new Set<string>(); // `${userId}|${locationId}|${monthKey}`

  findPremiumUntil(userId: string): Promise<Date | null> {
    return Promise.resolve(this.premiumUntilByUser.get(userId) ?? null);
  }
  countUnlocks(userId: string, monthKey: string): Promise<number> {
    let n = 0;
    for (const k of this.unlocks) {
      if (k.startsWith(`${userId}|`) && k.endsWith(`|${monthKey}`)) n += 1;
    }
    return Promise.resolve(n);
  }
  hasUnlock(userId: string, locationId: string, monthKey: string): Promise<boolean> {
    return Promise.resolve(this.unlocks.has(`${userId}|${locationId}|${monthKey}`));
  }
  async createUnlock(
    userId: string,
    locationId: string,
    monthKey: string,
    monthlyLimit: number,
  ): Promise<'created' | 'existing' | 'quota'> {
    const key = `${userId}|${locationId}|${monthKey}`;
    if (this.unlocks.has(key)) return 'existing';
    if ((await this.countUnlocks(userId, monthKey)) >= monthlyLimit) return 'quota';
    this.unlocks.add(key);
    return 'created';
  }
}

describe('PremiumAccessService (P1 — premium v3 raporu §3, K2)', () => {
  it('monthKey UTC takvim ayını üretir', () => {
    expect(PremiumAccessService.monthKey(NOW)).toBe('2026-09');
    // Ay sınırı: 30 Eylül 23:59 UTC hâlâ Eylül'dür; 1 Ekim 00:00 Ekim'dir.
    expect(PremiumAccessService.monthKey(new Date('2026-09-30T23:59:59Z'))).toBe('2026-09');
    expect(PremiumAccessService.monthKey(new Date('2026-10-01T00:00:00Z'))).toBe('2026-10');
  });

  it('bayrak KAPALIYKEN herkes full görür — bugünkü davranış birebir', async () => {
    const svc = new PremiumAccessService(env(false), new FakeRepo());
    expect(await svc.accessFor(null, 'loc-1', NOW)).toEqual({
      access: 'full',
      explorationRemaining: null,
    });
    expect(await svc.accessFor(member(), 'loc-1', NOW)).toEqual({
      access: 'full',
      explorationRemaining: null,
    });
  });

  it('bayrak açık: anonim istek vitrin (teaser) görür', async () => {
    const svc = new PremiumAccessService(env(true), new FakeRepo());
    expect(await svc.accessFor(null, 'loc-1', NOW)).toEqual({
      access: 'teaser',
      explorationRemaining: null,
    });
  });

  it('bayrak açık: premium kullanıcı full görür; süresi GEÇMİŞ premium görmez', async () => {
    const repo = new FakeRepo();
    repo.premiumUntilByUser.set('member-1', new Date('2027-01-01T00:00:00Z'));
    repo.premiumUntilByUser.set('expired-1', new Date('2026-01-01T00:00:00Z'));
    const svc = new PremiumAccessService(env(true), repo);

    expect((await svc.accessFor(member('member-1'), 'loc-1', NOW)).access).toBe('full');
    const expired = await svc.accessFor(member('expired-1'), 'loc-1', NOW);
    expect(expired.access).toBe('teaser');
    // Eski abonenin keşif hakkı da vardır (üye) — kalan sayı dolar.
    expect(expired.explorationRemaining).toBe(EXPLORATION_MONTHLY_LIMIT);
  });

  it('bayrak açık: misafir (anonim Firebase) hesap sayılmaz — teaser, hak yok', async () => {
    const svc = new PremiumAccessService(env(true), new FakeRepo());
    expect(await svc.accessFor(guest(), 'loc-1', NOW)).toEqual({
      access: 'teaser',
      explorationRemaining: null,
    });
  });

  it('üye: bu ay açtığı koyu full görür; başka koy teaser + kalan hak', async () => {
    const repo = new FakeRepo();
    const svc = new PremiumAccessService(env(true), repo);
    await svc.unlock(member(), 'loc-1', NOW);

    expect((await svc.accessFor(member(), 'loc-1', NOW)).access).toBe('full');
    const other = await svc.accessFor(member(), 'loc-2', NOW);
    expect(other.access).toBe('teaser');
    expect(other.explorationRemaining).toBe(EXPLORATION_MONTHLY_LIMIT - 1);
  });

  it('keşif hakkı: 3 koy açılır, 4.sü 403 quota-exceeded fırlatır', async () => {
    const repo = new FakeRepo();
    const svc = new PremiumAccessService(env(true), repo);
    expect((await svc.unlock(member(), 'loc-1', NOW)).remaining).toBe(2);
    expect((await svc.unlock(member(), 'loc-2', NOW)).remaining).toBe(1);
    expect((await svc.unlock(member(), 'loc-3', NOW)).remaining).toBe(0);

    let thrown: unknown;
    try {
      await svc.unlock(member(), 'loc-4', NOW);
    } catch (e) {
      thrown = e;
    }
    expect(thrown).toBeInstanceOf(AppProblem);
    expect((thrown as AppProblem).problemType).toBe('quota-exceeded');
    expect((thrown as AppProblem).status).toBe(403);
  });

  it('aynı koyu aynı ay yeniden açmak hak TÜKETMEZ', async () => {
    const svc = new PremiumAccessService(env(true), new FakeRepo());
    await svc.unlock(member(), 'loc-1', NOW);
    const again = await svc.unlock(member(), 'loc-1', NOW);
    expect(again.remaining).toBe(EXPLORATION_MONTHLY_LIMIT - 1);
  });

  it('yeni ay = yeni haklar: Ekim, Eylül sayacını görmez', async () => {
    const repo = new FakeRepo();
    const svc = new PremiumAccessService(env(true), repo);
    await svc.unlock(member(), 'loc-1', NOW);
    await svc.unlock(member(), 'loc-2', NOW);
    await svc.unlock(member(), 'loc-3', NOW);

    const october = new Date('2026-10-05T09:00:00Z');
    expect((await svc.unlock(member(), 'loc-4', october)).remaining).toBe(2);
    // Eylül'de açılan koy Ekim'de otomatik AÇIK DEĞİLDİR (ay sonuna dek sözü).
    expect((await svc.accessFor(member(), 'loc-1', october)).access).toBe('teaser');
  });

  it('premium kullanıcıda unlock hak tüketmez (zaten tam erişim)', async () => {
    const repo = new FakeRepo();
    repo.premiumUntilByUser.set('member-1', new Date('2027-01-01T00:00:00Z'));
    const svc = new PremiumAccessService(env(true), repo);
    await svc.unlock(member('member-1'), 'loc-1', NOW);
    expect(repo.unlocks.size).toBe(0);
  });
});
