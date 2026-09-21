import { PrismaPremiumRepository } from '../src/modules/premium/persistence/prisma-premium.repository';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

/**
 * PrismaPremiumRepository birim testi — Prisma istemcisi TAKLİTLE değiştirilir
 * (gerçek DB e2e'de). Amaç: "say → sınır altındaysa yaz" akışının ve
 * idempotent/tekil davranışın sözleşmesini sabitlemek.
 */
interface UnlockRow {
  userId: string;
  locationId: string;
  monthKey: string;
}

function fakePrisma(state: {
  premiumUntil: Date | null;
  deleted?: boolean;
  unlocks: UnlockRow[];
}): PrismaService {
  const matches = (r: UnlockRow, w: Partial<UnlockRow>): boolean =>
    Object.entries(w).every(([k, v]) => r[k as keyof UnlockRow] === v);

  const explorationUnlock = {
    count: ({ where }: { where: Partial<UnlockRow> }) =>
      Promise.resolve(state.unlocks.filter((r) => matches(r, where)).length),
    findUnique: ({ where }: { where: { userId_locationId_monthKey: UnlockRow } }) => {
      const w = where.userId_locationId_monthKey;
      return Promise.resolve(state.unlocks.find((r) => matches(r, w)) ?? null);
    },
    create: ({ data }: { data: UnlockRow }) => {
      state.unlocks.push({ ...data });
      return Promise.resolve(data);
    },
  };

  return {
    user: {
      findFirst: ({ where }: { where: { id: string; deletedAt: null } }) => {
        if (state.deleted) return Promise.resolve(null);
        return Promise.resolve(where.id === 'u1' ? { premiumUntil: state.premiumUntil } : null);
      },
    },
    explorationUnlock,
    // withUserContext: gerçek sınıfta transaksiyon + RLS bağlamı kurar; burada
    // aynı taklit istemciyi geri verir (akışın kendisi test ediliyor).
    withUserContext: <T>(_userId: string, fn: (tx: unknown) => Promise<T>) =>
      fn({ explorationUnlock }),
  } as unknown as PrismaService;
}

describe('PrismaPremiumRepository (P1)', () => {
  it('findPremiumUntil: satır varsa tarihi, silinmiş/yok kullanıcıda null döner', async () => {
    const until = new Date('2027-01-01T00:00:00Z');
    expect(
      await new PrismaPremiumRepository(
        fakePrisma({ premiumUntil: until, unlocks: [] }),
      ).findPremiumUntil('u1'),
    ).toEqual(until);
    expect(
      await new PrismaPremiumRepository(
        fakePrisma({ premiumUntil: null, unlocks: [] }),
      ).findPremiumUntil('u1'),
    ).toBeNull();
    expect(
      await new PrismaPremiumRepository(
        fakePrisma({ premiumUntil: until, deleted: true, unlocks: [] }),
      ).findPremiumUntil('u1'),
    ).toBeNull();
  });

  it('countUnlocks/hasUnlock: yalnız o ay + o kullanıcı sayılır', async () => {
    const repo = new PrismaPremiumRepository(
      fakePrisma({
        premiumUntil: null,
        unlocks: [
          { userId: 'u1', locationId: 'l1', monthKey: '2026-09' },
          { userId: 'u1', locationId: 'l2', monthKey: '2026-08' }, // geçen ay
          { userId: 'u2', locationId: 'l3', monthKey: '2026-09' }, // başka kullanıcı
        ],
      }),
    );
    expect(await repo.countUnlocks('u1', '2026-09')).toBe(1);
    expect(await repo.hasUnlock('u1', 'l1', '2026-09')).toBe(true);
    expect(await repo.hasUnlock('u1', 'l2', '2026-09')).toBe(false);
  });

  it('createUnlock: created → existing → quota sırası doğru işler', async () => {
    const state = { premiumUntil: null, unlocks: [] as UnlockRow[] };
    const repo = new PrismaPremiumRepository(fakePrisma(state));

    expect(await repo.createUnlock('u1', 'l1', '2026-09', 3)).toBe('created');
    expect(await repo.createUnlock('u1', 'l1', '2026-09', 3)).toBe('existing');
    expect(await repo.createUnlock('u1', 'l2', '2026-09', 3)).toBe('created');
    expect(await repo.createUnlock('u1', 'l3', '2026-09', 3)).toBe('created');
    expect(await repo.createUnlock('u1', 'l4', '2026-09', 3)).toBe('quota');
    // Kota reddinde satır YAZILMAMIŞ olmalı.
    expect(state.unlocks).toHaveLength(3);
    // Yeni ay aynı kullanıcıda sıfırdan sayılır.
    expect(await repo.createUnlock('u1', 'l4', '2026-10', 3)).toBe('created');
  });
});
