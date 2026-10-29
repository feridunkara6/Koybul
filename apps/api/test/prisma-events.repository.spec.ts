import { Prisma } from '@prisma/client';
import { PrismaEventsRepository } from '../src/modules/events/persistence/prisma-events.repository';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

/**
 * Ham SQL etkinlik deposu — SAHTE Prisma ile sözleşme testi (qa/marina deseni).
 * Kontenjan kilidinin KARAR dalları burada; gerçek kilit davranışı Postgres'in
 * FOR UPDATE'ine aittir ve CI'daki gerçek DB paketlerinde güvence altındadır.
 */

const NOW = new Date('2026-10-23T12:00:00.000Z');

interface FakeState {
  event: { quota: number; status: string; deadline: Date | null; startsAt: Date } | null;
  myRegistration: { status: string } | null;
  registeredCount: number;
  execResult?: number;
}

function fakePrisma(state: FakeState): { prisma: PrismaService; execs: string[] } {
  const execs: string[] = [];
  const impl = {
    $queryRaw: (sql: Prisma.Sql) => {
      const text = sql.sql ?? String(sql);
      if (text.includes('FOR UPDATE')) {
        return Promise.resolve(state.event === null ? [] : [state.event]);
      }
      if (text.includes('SELECT status FROM event_registrations')) {
        return Promise.resolve(state.myRegistration === null ? [] : [state.myRegistration]);
      }
      if (text.includes('count(*)::int AS n')) {
        return Promise.resolve([{ n: state.registeredCount }]);
      }
      return Promise.resolve([]);
    },
    $executeRaw: (sql: Prisma.Sql) => {
      execs.push(sql.sql ?? String(sql));
      return Promise.resolve(state.execResult ?? 1);
    },
    $transaction: async <T>(work: (tx: unknown) => Promise<T>): Promise<T> => work(impl),
  };
  return { prisma: impl as unknown as PrismaService, execs };
}

const OPEN_EVENT = {
  quota: 25,
  status: 'published',
  deadline: new Date('2026-11-05T20:59:00Z'),
  startsAt: new Date('2026-11-07T11:00:00Z'),
};

describe('PrismaEventsRepository.register (kontenjan karar dalları)', () => {
  it('yayında + yer var → registered, kalan doğru, tek yazım', async () => {
    const { prisma, execs } = fakePrisma({
      event: OPEN_EVENT,
      myRegistration: null,
      registeredCount: 18,
    });
    const repo = new PrismaEventsRepository(prisma);
    const out = await repo.register('e1', 'u1', NOW, false);
    expect(out).toEqual({ result: 'registered', remaining: 6 }); // 25-18-1
    expect(execs).toHaveLength(1);
  });

  it('dolu → quota; hiçbir yazım yapılmaz', async () => {
    const { prisma, execs } = fakePrisma({
      event: OPEN_EVENT,
      myRegistration: null,
      registeredCount: 25,
    });
    const out = await new PrismaEventsRepository(prisma).register('e1', 'u1', NOW, false);
    expect(out).toEqual({ result: 'quota' });
    expect(execs).toHaveLength(0);
  });

  it('zaten kayıtlı → already (mükerrer yazım yok)', async () => {
    const { prisma, execs } = fakePrisma({
      event: OPEN_EVENT,
      myRegistration: { status: 'registered' },
      registeredCount: 18,
    });
    const out = await new PrismaEventsRepository(prisma).register('e1', 'u1', NOW, false);
    expect(out).toEqual({ result: 'already', remaining: 7 });
    expect(execs).toHaveLength(0);
  });

  it('iptal edilmiş kaydı olan yeniden kayıt olabilir (satır dirilir)', async () => {
    const { prisma, execs } = fakePrisma({
      event: OPEN_EVENT,
      myRegistration: { status: 'cancelled' },
      registeredCount: 18,
    });
    const out = await new PrismaEventsRepository(prisma).register('e1', 'u1', NOW, false);
    expect(out).toEqual({ result: 'registered', remaining: 6 });
    expect(execs).toHaveLength(1);
  });

  it('son kayıt geçti / iptal edilmiş / yok → not-open', async () => {
    const past = { ...OPEN_EVENT, deadline: new Date('2026-10-01T00:00:00Z') };
    expect(
      await new PrismaEventsRepository(
        fakePrisma({ event: past, myRegistration: null, registeredCount: 0 }).prisma,
      ).register('e1', 'u1', NOW, false),
    ).toEqual({ result: 'not-open' });

    const cancelled = { ...OPEN_EVENT, status: 'cancelled' };
    expect(
      await new PrismaEventsRepository(
        fakePrisma({ event: cancelled, myRegistration: null, registeredCount: 0 }).prisma,
      ).register('e1', 'u1', NOW, false),
    ).toEqual({ result: 'not-open' });

    expect(
      await new PrismaEventsRepository(
        fakePrisma({ event: null, myRegistration: null, registeredCount: 0 }).prisma,
      ).register('e-yok', 'u1', NOW, false),
    ).toEqual({ result: 'not-open' });
  });

  it('son kayıt tarihi YOKSA etkinlik başlangıcı sınır kabul edilir', async () => {
    const noDeadline = { ...OPEN_EVENT, deadline: null };
    const out = await new PrismaEventsRepository(
      fakePrisma({ event: noDeadline, myRegistration: null, registeredCount: 0 }).prisma,
    ).register('e1', 'u1', NOW, false);
    expect(out).toEqual({ result: 'registered', remaining: 24 });
  });

  it('cancelRegistration: satır değiştiyse true, yoksa false', async () => {
    const yes = fakePrisma({ event: null, myRegistration: null, registeredCount: 0 });
    expect(await new PrismaEventsRepository(yes.prisma).cancelRegistration('e1', 'u1')).toBe(true);
    const no = fakePrisma({
      event: null,
      myRegistration: null,
      registeredCount: 0,
      execResult: 0,
    });
    expect(await new PrismaEventsRepository(no.prisma).cancelRegistration('e1', 'u1')).toBe(false);
  });
});

describe('PrismaEventsRepository (liste/katılımcı eşlemesi)', () => {
  it('participants: profil adı yoksa nazik ad; tarih ISO', async () => {
    const impl = {
      $queryRaw: () =>
        Promise.resolve([
          { userId: 'u1', displayName: null, email: 'kaptan@ornek.com', registeredAt: NOW },
        ]),
    };
    const repo = new PrismaEventsRepository(impl as unknown as PrismaService);
    const list = await repo.participants('e1');
    expect(list[0]).toEqual({
      userId: 'u1',
      displayName: 'Koybul Kaptanı',
      email: 'kaptan@ornek.com',
      registeredAt: NOW.toISOString(),
    });
  });

  it('upcomingEvents/findEvent sorgu satırlarını aynen taşır', async () => {
    const row = {
      id: 'e1',
      title: 'Buluşma',
      body: 'Gövde metni yeterince uzun.',
      startsAt: NOW,
      endsAt: null,
      locationText: 'Göcek',
      venueLocationId: null,
      quota: 25,
      registeredCount: 18,
      registrationDeadline: null,
      priceNote: null,
      conditions: null,
      organizer: 'Koybul',
      audience: 'all',
      status: 'published',
      registeredByViewer: false,
    };
    const impl = { $queryRaw: () => Promise.resolve([row]) };
    const repo = new PrismaEventsRepository(impl as unknown as PrismaService);
    expect((await repo.upcomingEvents('u1', NOW))[0].id).toBe('e1');
    expect(await repo.findEvent('e1', null)).toMatchObject({ quota: 25 });
    const empty = { $queryRaw: () => Promise.resolve([]) };
    expect(
      await new PrismaEventsRepository(empty as unknown as PrismaService).findEvent('e-yok', null),
    ).toBeNull();
  });
});
