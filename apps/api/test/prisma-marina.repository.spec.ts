import { Prisma } from '@prisma/client';
import { PrismaMarinaRepository } from '../src/modules/marina/persistence/prisma-marina.repository';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

/**
 * Ham SQL marina deposu — SAHTE Prisma ile satır-eşleme sözleşmesi (qa deposu
 * ile aynı yaklaşım; gerçek DB davranışı CI'daki migrate+RLS paketlerinde).
 */

type RawHandler = (sqlText: string) => unknown[];

function fakePrisma(handler: RawHandler): PrismaService {
  const impl = {
    $queryRaw: (sql: Prisma.Sql) => Promise.resolve(handler(sql.sql ?? String(sql))),
    boatType: {
      findUnique: ({ where }: { where: { code: string } }) =>
        Promise.resolve(where.code === 'sailboat' ? { code: 'sailboat', isActive: true } : null),
    },
    withUserContext: async <T>(_u: string, work: (tx: unknown) => Promise<T>): Promise<T> =>
      work(impl),
  };
  return impl as unknown as PrismaService;
}

const MY_BOAT_ROW = {
  boatId: 'b1',
  name: 'Martı',
  boatTypeCode: 'sailboat',
  lengthM: '10.40', // Decimal sütun string gelebilir — Number() sözleşmesi
  brand: 'Beneteau',
  model: 'Oceanis 38.1', // Hafta 2: modele özel çizim köprüsü
  buildYear: 2019,
  marinaId: 'loc-marti',
  marinaName: 'Martı Marina',
  visible: true,
  shareSpecs: false,
};

describe('PrismaMarinaRepository (satır eşleme sözleşmesi)', () => {
  it('marinaInfo: var → {id,name}; yok → null', async () => {
    const repo = new PrismaMarinaRepository(
      fakePrisma(() => [{ id: 'loc-marti', name: 'Martı Marina' }]),
    );
    expect(await repo.marinaInfo('loc-marti')).toEqual({ id: 'loc-marti', name: 'Martı Marina' });
    const empty = new PrismaMarinaRepository(fakePrisma(() => []));
    expect(await empty.marinaInfo('loc-koy')).toBeNull();
  });

  it('findMyBoat/upsertMyBoat: Decimal boy sayıya, marina nesneye eşlenir', async () => {
    const repo = new PrismaMarinaRepository(fakePrisma(() => [MY_BOAT_ROW]));
    const mine = await repo.findMyBoat('u1');
    expect(mine?.lengthM).toBe(10.4);
    expect(mine?.marina).toEqual({ id: 'loc-marti', name: 'Martı Marina' });
    expect(mine?.model).toBe('Oceanis 38.1'); // Hafta 2 alanları eşlenir
    expect(mine?.buildYear).toBe(2019);

    const upserted = await repo.upsertMyBoat('u1', {
      name: 'Martı',
      boatTypeCode: 'sailboat',
      lengthM: 10.4,
      brand: 'Beneteau',
      marinaLocationId: 'loc-marti',
      visible: true,
      shareSpecs: false,
    });
    expect(upserted.boatId).toBe('b1');

    const bos = new PrismaMarinaRepository(fakePrisma(() => []));
    expect(await bos.findMyBoat('u1')).toBeNull();
  });

  it('boatTypeValid: sözlükteki kod true, bilinmeyen false', async () => {
    const repo = new PrismaMarinaRepository(fakePrisma(() => []));
    expect(await repo.boatTypeValid('sailboat')).toBe(true);
    expect(await repo.boatTypeValid('uzay-gemisi')).toBe(false);
  });

  it('isMemberOf/counts: boolean ve sayı eşlemesi', async () => {
    const repo = new PrismaMarinaRepository(
      fakePrisma((sql) =>
        sql.includes('AS ok') ? [{ ok: true }] : [{ total: 12, visibleCount: 7 }],
      ),
    );
    expect(await repo.isMemberOf('u1', 'loc-marti')).toBe(true);
    expect(await repo.counts('loc-marti')).toEqual({ total: 12, visibleCount: 7 });
  });

  it('visibleBoats: shareSpecs kapalı teknede boy/marka NULL kalır; kaptan adı yoksa nazik ad', async () => {
    const repo = new PrismaMarinaRepository(
      fakePrisma(() => [
        {
          boatId: 'b-ruzgar',
          name: 'Rüzgargülü',
          boatTypeCode: 'sailboat',
          lengthM: '12.00',
          brand: 'Hanse',
          captainName: 'Deniz K.',
        },
        {
          boatId: 'b-poyraz',
          name: 'Poyraz',
          boatTypeCode: 'gulet',
          lengthM: null,
          brand: null,
          captainName: null,
        },
      ]),
    );
    const boats = await repo.visibleBoats('loc-marti');
    expect(boats[0]).toEqual({
      boatId: 'b-ruzgar',
      name: 'Rüzgargülü',
      boatTypeCode: 'sailboat',
      lengthM: 12,
      brand: 'Hanse',
      captainName: 'Deniz K.',
    });
    expect(boats[1].lengthM).toBeNull();
    expect(boats[1].captainName).toBe('Koybul Kaptanı');
  });
});
