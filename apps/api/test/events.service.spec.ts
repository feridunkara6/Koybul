import { EventsService } from '../src/modules/events/application/events.service';
import {
  DealRow,
  EventParticipant,
  EventRow,
  EventsRepository,
  RegisterOutcome,
  UpsertDealInput,
  UpsertEventInput,
} from '../src/modules/events/domain/events.types';
import { PremiumAccessService } from '../src/modules/premium/application/premium-access.service';
import { EnvService } from '../src/config/env.service';
import { Principal } from '../src/core/auth/principal';

const NOW = new Date('2026-10-23T12:00:00.000Z');

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

function deal(partial: Partial<DealRow>): DealRow {
  return {
    id: 'd1',
    title: 'Hafta içi kiralama fırsatı',
    partner: 'Örnek Tekne Kiralama',
    benefit: '%15 indirim',
    code: 'KOYBUL15',
    validUntil: new Date('2026-11-30T23:59:59Z'),
    terms: null,
    place: null,
    audience: 'all',
    isActive: true,
    ...partial,
  };
}

function ev(partial: Partial<EventRow>): EventRow {
  return {
    id: 'e1',
    title: 'Göcek Koy Buluşması',
    body: 'Sonbahar buluşması — koyda demirleyip tanışıyoruz.',
    startsAt: new Date('2026-11-07T11:00:00Z'),
    endsAt: null,
    locationText: 'Göcek, Boynuz Koyu',
    venueLocationId: null,
    quota: 25,
    registeredCount: 18,
    registrationDeadline: new Date('2026-11-05T20:59:00Z'),
    priceNote: 'Ücretsiz',
    conditions: null,
    organizer: 'Koybul',
    audience: 'all',
    status: 'published',
    registeredByViewer: false,
    ...partial,
  };
}

class FakeEventsRepo implements EventsRepository {
  dealRows: DealRow[] = [];
  eventRows: EventRow[] = [];
  registerOutcome: RegisterOutcome = { result: 'registered', remaining: 6 };
  registerCalls: string[] = [];
  cancelOk = true;

  activeDeals(): Promise<DealRow[]> {
    return Promise.resolve(this.dealRows);
  }
  upcomingEvents(): Promise<EventRow[]> {
    return Promise.resolve(this.eventRows);
  }
  findEvent(eventId: string): Promise<EventRow | null> {
    return Promise.resolve(this.eventRows.find((r) => r.id === eventId) ?? null);
  }
  register(eventId: string): Promise<RegisterOutcome> {
    this.registerCalls.push(eventId);
    return Promise.resolve(this.registerOutcome);
  }
  cancelRegistration(): Promise<boolean> {
    return Promise.resolve(this.cancelOk);
  }
  createDeal(_input: UpsertDealInput): Promise<string> {
    return Promise.resolve('d-new');
  }
  updateDeal(): Promise<boolean> {
    return Promise.resolve(true);
  }
  createEvent(_input: UpsertEventInput): Promise<string> {
    return Promise.resolve('e-new');
  }
  updateEvent(): Promise<boolean> {
    return Promise.resolve(true);
  }
  participants(): Promise<EventParticipant[]> {
    return Promise.resolve([
      {
        userId: 'u1',
        displayName: 'Kaptan M.',
        email: 'kaptan@ornek.com',
        registeredAt: NOW.toISOString(),
      },
    ]);
  }
}

function makeSvc(opts: { enforce: boolean; premiumIds?: string[] }): {
  svc: EventsService;
  repo: FakeEventsRepo;
} {
  const repo = new FakeEventsRepo();
  return {
    svc: new EventsService(env(opts.enforce), premiumSvc(opts.premiumIds ?? []), repo),
    repo,
  };
}

describe('EventsService (Etkinlikler & Fırsatlar V1 — kurucu onayı 2026-10-23)', () => {
  it('fırsat: herkese açık kod anonimde bile iner; süresi geçen kod İNMEZ', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.dealRows = [
      deal({}),
      deal({ id: 'd-eski', validUntil: new Date('2026-01-01T00:00:00Z') }),
    ];
    const deals = await svc.deals(null, NOW);
    expect(deals[0].code).toBe('KOYBUL15');
    expect(deals[0].locked).toBe(false);
    expect(deals[1].expired).toBe(true);
    expect(deals[1].code).toBeNull(); // geçmiş kod kopyalanamaz
  });

  it('fırsat: üye kilidi anonim/misafire kapalı — kod gövdeye hiç yazılmaz', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.dealRows = [deal({ audience: 'members' })];
    expect((await svc.deals(null, NOW))[0]).toMatchObject({ code: null, locked: true });
    expect((await svc.deals(guest(), NOW))[0]).toMatchObject({ code: null, locked: true });
    expect((await svc.deals(member(), NOW))[0].code).toBe('KOYBUL15');
  });

  it('fırsat: premium kilidi — ücretsiz üye kilitli; premium/admin açık; bayrak kapalıyken herkes', async () => {
    const seed = (enforce: boolean, premiumIds: string[] = []) => {
      const made = makeSvc({ enforce, premiumIds });
      made.repo.dealRows = [deal({ audience: 'premium' })];
      return made.svc;
    };
    expect((await seed(true).deals(member(), NOW))[0].locked).toBe(true);
    expect((await seed(true, ['u-p']).deals(member('u-p'), NOW))[0].code).toBe('KOYBUL15');
    expect((await seed(true).deals(admin(), NOW))[0].code).toBe('KOYBUL15');
    expect((await seed(false).deals(member(), NOW))[0].code).toBe('KOYBUL15');
  });

  it('etkinlik görünümü: kalan yer, doluluk ve bakanın kayıt durumu', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.eventRows = [
      ev({}),
      ev({ id: 'e-dolu', registeredCount: 25 }),
      ev({ id: 'e-benim', registeredByViewer: true }),
    ];
    const list = await svc.events(member(), NOW);
    expect(list[0]).toMatchObject({ remaining: 7, full: false, registered: false });
    expect(list[1]).toMatchObject({ remaining: 0, full: true });
    expect(list[2].registered).toBe(true);
  });

  it('kayıt: dolu etkinlik quota-exceeded (403) fırlatır', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.eventRows = [ev({})];
    repo.registerOutcome = { result: 'quota' };
    await expect(svc.register(member(), 'e1', NOW)).rejects.toMatchObject({
      problemType: 'quota-exceeded',
    });
  });

  it('kayıt: süresi geçmiş/iptal etkinlik kibarca reddedilir; mükerrer kayıt idempotent', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.eventRows = [ev({})];
    repo.registerOutcome = { result: 'not-open' };
    await expect(svc.register(member(), 'e1', NOW)).rejects.toMatchObject({
      problemType: 'validation-error',
    });
    repo.registerOutcome = { result: 'already', remaining: 7 };
    expect(await svc.register(member(), 'e1', NOW)).toEqual({ registered: true, remaining: 7 });
  });

  it('kayıt: premium etkinliğe ücretsiz üye premium-required alır; admin geçer', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.eventRows = [ev({ audience: 'premium' })];
    await expect(svc.register(member(), 'e1', NOW)).rejects.toMatchObject({
      problemType: 'premium-required',
    });
    expect((await svc.register(admin(), 'e1', NOW)).registered).toBe(true);
  });

  it('iptal: kayıt yoksa 404; varsa sessizce iptal olur', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    repo.cancelOk = false;
    await expect(svc.cancel(member(), 'e1')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    repo.cancelOk = true;
    await expect(svc.cancel(member(), 'e1')).resolves.toBeUndefined();
  });

  it('yönetici: katılımcı listesi var olmayan etkinlikte 404, varsa ad+e-posta döner', async () => {
    const { svc, repo } = makeSvc({ enforce: true });
    await expect(svc.adminParticipants('e-yok')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    repo.eventRows = [ev({})];
    const list = await svc.adminParticipants('e1');
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({ email: 'kaptan@ornek.com' });
  });
});
