import { LocationsService } from '../src/modules/locations/application/locations.service';
import { LocationsRepository } from '../src/modules/locations/domain/locations.repository';
import { NotesService } from '../src/modules/community/application/notes.service';
import { NoteListFilters, NotesRepository } from '../src/modules/community/domain/notes.repository';
import { ReputationService } from '../src/modules/community/application/reputation.service';
import {
  AccessDecision,
  PremiumAccessService,
} from '../src/modules/premium/application/premium-access.service';
import { Principal } from '../src/core/auth/principal';

/**
 * KİLİTLİ OKUMA UÇLARI (P5, premium v3 §9): vitrin yalnız detayda değil, yan
 * uçlarda da sunucudan kesilir — yorum listesi ve (uyarı dışı) kaptan notları
 * vitrin gören isteğe İNMEZ. KAPTAN KURALI: uyarı (hazard) notları emniyet
 * bilgisidir, HERKESE açık kalır. Bayrak kapalıyken davranış birebir eskisi.
 */

/** Sahte erişim kararı — `enforced` bayrağı ve karar DIŞARIDAN verilir. */
function premiumStub(enforced: boolean, decision: AccessDecision): PremiumAccessService {
  return {
    enforced,
    accessFor: () => Promise.resolve(decision),
  } as unknown as PremiumAccessService;
}

const TEASER: AccessDecision = { access: 'teaser', explorationRemaining: 2 };
const FULL: AccessDecision = { access: 'full', explorationRemaining: null };
const MEMBER: Principal = { userId: 'u1', role: 'user', isGuest: false, familyId: 'f', jti: 'j' };

/** Yalnız yorum yolunu kaydeden asgari sahte lokasyon deposu. */
class ReviewsRepo {
  reviewCalls = 0;
  resolveCalls = 0;
  knownId: string | null = 'loc-1';

  resolveId(): Promise<string | null> {
    this.resolveCalls += 1;
    return Promise.resolve(this.knownId);
  }
  findReviews(): Promise<never[]> {
    this.reviewCalls += 1;
    return Promise.resolve([]);
  }
}

function locationsService(repo: ReviewsRepo, premium?: PremiumAccessService): LocationsService {
  return new LocationsService(repo as unknown as LocationsRepository, premium);
}

/** Not deposu: kendisine ulaşan süzgeci kaydeder. */
class NotesRepo {
  lastFilters: NoteListFilters | null = null;

  listForLocation(_id: string, filters: NoteListFilters): Promise<never[]> {
    this.lastFilters = filters;
    return Promise.resolve([]);
  }
}

function notesService(repo: NotesRepo, premium?: PremiumAccessService): NotesService {
  return new NotesService(
    repo as unknown as NotesRepository,
    // listForLocation itibar servisine hiç dokunmaz — asgari sahte yeterli.
    {} as unknown as ReputationService,
    premium,
  );
}

describe('Yorum listesi kilidi (P5)', () => {
  it('bayrak KAPALI: erişim kararına hiç girilmez, yorumlar eskisi gibi iner', async () => {
    const repo = new ReviewsRepo();
    const svc = locationsService(repo, premiumStub(false, TEASER));
    await expect(svc.reviews('kille-koyu', undefined, null)).resolves.toEqual({ data: [] });
    expect(repo.resolveCalls).toBe(0); // sıfır ek sorgu sözü
    expect(repo.reviewCalls).toBe(1);
  });

  it('premium servis YOKKEN (birim kurulumları) davranış eski', async () => {
    const repo = new ReviewsRepo();
    await expect(locationsService(repo).reviews('kille-koyu', undefined)).resolves.toEqual({
      data: [],
    });
    expect(repo.reviewCalls).toBe(1);
  });

  it('bayrak AÇIK + vitrin: dürüst 403 premium-required, yorumlar HİÇ çekilmez', async () => {
    const repo = new ReviewsRepo();
    const svc = locationsService(repo, premiumStub(true, TEASER));
    await expect(svc.reviews('kille-koyu', undefined, null)).rejects.toMatchObject({
      problemType: 'premium-required',
    });
    expect(repo.reviewCalls).toBe(0); // kilitli veri depodan bile okunmaz
  });

  it('bayrak AÇIK + tam erişim (premium/keşif hakkı): yorumlar iner', async () => {
    const repo = new ReviewsRepo();
    const svc = locationsService(repo, premiumStub(true, FULL));
    await expect(svc.reviews('kille-koyu', undefined, MEMBER)).resolves.toEqual({ data: [] });
    expect(repo.reviewCalls).toBe(1);
  });

  it('lokasyon yoksa (id çözülemedi) 403 atılmaz — eski boş-liste davranışı', async () => {
    const repo = new ReviewsRepo();
    repo.knownId = null;
    const svc = locationsService(repo, premiumStub(true, TEASER));
    await expect(svc.reviews('yok-boyle-koy', undefined, null)).resolves.toEqual({ data: [] });
  });
});

describe('Kaptan notları kilidi (P5 — kaptan kuralı: uyarılar herkese açık)', () => {
  it('bayrak KAPALI: süzgeç aynen geçer (davranış birebir eski)', async () => {
    const repo = new NotesRepo();
    const svc = notesService(repo, premiumStub(false, TEASER));
    await svc.listForLocation('loc-1', { limit: 20 }, null);
    expect(repo.lastFilters).toEqual({ limit: 20 });
  });

  it('bayrak AÇIK + vitrin: tür istenmemişse YALNIZ uyarılar iner', async () => {
    const repo = new NotesRepo();
    const svc = notesService(repo, premiumStub(true, TEASER));
    await svc.listForLocation('loc-1', { limit: 20 }, null);
    expect(repo.lastFilters).toEqual({ limit: 20, kind: 'hazard' });
  });

  it('bayrak AÇIK + vitrin: uyarı türü AÇIKÇA istenirse serbest (emniyet kilitlenmez)', async () => {
    const repo = new NotesRepo();
    const svc = notesService(repo, premiumStub(true, TEASER));
    await svc.listForLocation('loc-1', { limit: 5, kind: 'hazard' }, null);
    expect(repo.lastFilters).toEqual({ limit: 5, kind: 'hazard' });
  });

  it('bayrak AÇIK + vitrin: uyarı DIŞI tür açıkça istenirse dürüst 403', async () => {
    const repo = new NotesRepo();
    const svc = notesService(repo, premiumStub(true, TEASER));
    await expect(
      svc.listForLocation('loc-1', { limit: 20, kind: 'experience' }, null),
    ).rejects.toMatchObject({
      problemType: 'premium-required',
    });
    expect(repo.lastFilters).toBeNull(); // depoya hiç inilmedi
  });

  it('bayrak AÇIK + tam erişim: süzgeç aynen geçer', async () => {
    const repo = new NotesRepo();
    const svc = notesService(repo, premiumStub(true, FULL));
    await svc.listForLocation('loc-1', { limit: 20, kind: 'experience' }, MEMBER);
    expect(repo.lastFilters).toEqual({ limit: 20, kind: 'experience' });
  });

  it('premium servis YOKKEN davranış eski', async () => {
    const repo = new NotesRepo();
    await notesService(repo).listForLocation('loc-1', { limit: 20 }, null);
    expect(repo.lastFilters).toEqual({ limit: 20 });
  });
});
