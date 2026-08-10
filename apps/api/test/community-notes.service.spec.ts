import { AppProblem } from '../src/common/problem/problem';
import { EarnedBadge, emptyBadgeStats } from '../src/modules/community/domain/badges';
import { Principal } from '../src/core/auth/principal';
import { NotesService } from '../src/modules/community/application/notes.service';
import { ReputationService } from '../src/modules/community/application/reputation.service';
import { CreateNoteInput, Note } from '../src/modules/community/domain/note.types';
import {
  NearbyNote,
  NoteOwnership,
  NotesRepository,
  ReactionResult,
} from '../src/modules/community/domain/notes.repository';
import {
  AuthorState,
  ReputationRepository,
} from '../src/modules/community/domain/reputation.repository';

const P: Principal = { userId: 'u1', role: 'user', isGuest: false, familyId: 'f', jti: 'j' };

function note(over: Partial<Note> = {}): Note {
  return {
    id: 'n1',
    kind: 'experience',
    locationId: 'loc',
    fromLocationId: null,
    toLocationId: null,
    title: null,
    body: 'Kuzey ucunda kum, tutuş iyi.',
    observedOn: '2026-08-01',
    gpsVerified: false,
    wind: null,
    helpfulCount: 0,
    confirmCount: 0,
    disputeCount: 0,
    createdAt: '2026-08-01T00:00:00.000Z',
    author: { userId: 'u1', displayName: 'Kaptan', levelCode: 'new', areaContributions: null },
    status: 'pending',
    ...over,
  };
}

class FakeNotes implements NotesRepository {
  target: 'ok' | 'too-far' | 'not-found' = 'ok';
  refsOk = true;
  created: CreateNoteInput | null = null;
  createdStatus: Note['status'] = 'pending';
  ownership: NoteOwnership | null = { userId: 'u2', kind: 'hazard', status: 'approved' };
  reaction: ReactionResult | null = {
    created: true,
    helpfulCount: 1,
    confirmCount: 0,
    disputeCount: 0,
    movedToReview: false,
    ownerUserId: 'u2',
  };
  listForLocation(): Promise<Note[]> {
    return Promise.resolve([note({ status: undefined })]);
  }
  nearby(): Promise<NearbyNote[]> {
    return Promise.resolve([]);
  }
  listForUser(): Promise<Note[]> {
    return Promise.resolve([note()]);
  }
  findOwnership(): Promise<NoteOwnership | null> {
    return Promise.resolve(this.ownership);
  }
  checkTarget(): Promise<'ok' | 'too-far' | 'not-found'> {
    return Promise.resolve(this.target);
  }
  create(
    _id: string,
    _u: string,
    input: CreateNoteInput,
    _e: Date | null,
    status: 'pending' | 'approved',
  ): Promise<Note> {
    this.created = input;
    this.createdStatus = status;
    return Promise.resolve(note({ kind: input.kind, status }));
  }
  update(): Promise<Note | null> {
    return Promise.resolve(note());
  }
  softDelete(): Promise<boolean> {
    return Promise.resolve(true);
  }
  refsValid(): Promise<boolean> {
    return Promise.resolve(this.refsOk);
  }
  react(): Promise<ReactionResult | null> {
    return Promise.resolve(this.reaction);
  }
}

class FakeRep implements ReputationRepository {
  granted: string[] = [];
  state: AuthorState = { trustScore: 1, approvedCount: 5, writeRestrictedUntil: null };
  awards: { userId: string; action: string; base: number }[] = [];
  alreadyAwarded = false;
  awardWindow() {
    return Promise.resolve({
      todayPoints: 0,
      weekPoints: 0,
      todayEventsOfAction: 0,
      trustScore: this.state.trustScore,
    });
  }
  award(userId: string, action: string, points: number) {
    this.awards.push({ userId, action, base: points });
    return Promise.resolve({ points, levelCode: 'new' as const, leveledUp: false });
  }
  helpfulPointsForEntity() {
    return Promise.resolve(0);
  }
  hasAwardedFor() {
    return Promise.resolve(this.alreadyAwarded);
  }
  summary(): never {
    throw new Error('kullanılmıyor');
  }
  contributions() {
    return Promise.resolve([]);
  }
  recomputeTrust() {
    return Promise.resolve(1);
  }
  badgeStats() {
    return Promise.resolve(emptyBadgeStats());
  }
  grantBadges(_userId: string, badges: EarnedBadge[]) {
    this.granted.push(...badges.map((b) => b.code));
    return Promise.resolve(badges);
  }
  authorState() {
    return Promise.resolve(this.state);
  }
}

function build(): { svc: NotesService; notes: FakeNotes; rep: FakeRep } {
  const notes = new FakeNotes();
  const rep = new FakeRep();
  const svc = new NotesService(notes, new ReputationService(rep));
  return { svc, notes, rep };
}

const input: CreateNoteInput = {
  kind: 'experience',
  locationId: '11111111-1111-4111-8111-111111111111',
  body: 'Kuzey ucunda kum, tutuş iyi.',
  observedOn: '2026-08-01',
};

describe('NotesService.create', () => {
  it('deneyim notu konum olmadan yazılabilir', async () => {
    const { svc } = build();
    await expect(svc.create(P, input)).resolves.toMatchObject({ kind: 'experience' });
  });

  it('GÜNCEL DURUM ve UYARI notu konum ister', async () => {
    const { svc } = build();
    for (const kind of ['status', 'hazard'] as const) {
      await expect(svc.create(P, { ...input, kind })).rejects.toMatchObject({
        problemType: 'validation-error',
      });
    }
  });

  it('noktaya çok uzaksa 422 verir', async () => {
    const { svc, notes } = build();
    notes.target = 'too-far';
    await expect(
      svc.create(P, { ...input, kind: 'status', position: { lat: 1, lon: 1 } }),
    ).rejects.toMatchObject({ problemType: 'validation-error' });
  });

  it('nokta yoksa 404 verir', async () => {
    const { svc, notes } = build();
    notes.target = 'not-found';
    await expect(svc.create(P, input)).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('yazma kısıtlıysa içerik ÜRETİLEMEZ', async () => {
    const { svc, rep, notes } = build();
    rep.state = { ...rep.state, writeRestrictedUntil: new Date(Date.now() + 86400_000) };
    await expect(svc.create(P, input)).rejects.toBeInstanceOf(AppProblem);
    expect(notes.created).toBeNull();
  });

  it('kuyruğa giren not HENÜZ puan üretmez (çift puanlama olmasın)', async () => {
    const { svc, rep } = build();
    await svc.create(P, input);
    expect(rep.awards).toHaveLength(0);
  });

  it('otomatik yayınlanan güncel durum notu anında puan üretir', async () => {
    const { svc, notes, rep } = build();
    await svc.create(P, {
      ...input,
      kind: 'status',
      body: 'Şamandıra ücreti 450 TL oldu, nakit istiyorlar.',
      position: { lat: 36.6, lon: 28.9 },
    });
    expect(notes.createdStatus).toBe('approved');
    expect(rep.awards).toEqual([{ userId: 'u1', action: 'note_approved', base: 5 }]);
  });
});

describe('NotesService.react', () => {
  it('geçersiz varış noktası / başkasının teknesi 422 verir', async () => {
    const { svc, notes } = build();
    notes.refsOk = false;
    await expect(svc.create(P, input)).rejects.toMatchObject({
      problemType: 'validation-error',
    });
  });
});

describe('NotesService — puan çiftliği koruması', () => {
  it('aynı içerik ikinci kez onaylansa da puan TEKRAR yazılmaz', async () => {
    const { svc, notes, rep } = build();
    rep.alreadyAwarded = true;
    notes.createdStatus = 'approved';
    await svc.create(P, {
      ...input,
      kind: 'status',
      body: 'Samandira ucreti guncellendi, nakit isteniyor.',
      position: { lat: 36.6, lon: 28.9 },
    });
    expect(rep.awards).toHaveLength(0);
  });
});

describe('NotesService.react', () => {
  it('kendi notuna oy verilemez', async () => {
    const { svc, notes } = build();
    notes.ownership = { userId: 'u1', kind: 'experience', status: 'approved' };
    await expect(svc.react(P, 'n1', 'helpful')).rejects.toMatchObject({ problemType: 'forbidden' });
  });

  it('onaylanmamış nota oy verilemez (404 — varlık sızdırılmaz)', async () => {
    const { svc, notes } = build();
    notes.ownership = { userId: 'u2', kind: 'experience', status: 'pending' };
    await expect(svc.react(P, 'n1', 'helpful')).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('faydalı oyu puanı NOTUN SAHİBİNE yazar', async () => {
    const { svc, rep } = build();
    await svc.react(P, 'n1', 'helpful');
    expect(rep.awards).toEqual([{ userId: 'u2', action: 'helpful_received', base: 2 }]);
  });

  it('uyarı doğrulama puanı OY VERENE yazar', async () => {
    const { svc, rep } = build();
    await svc.react(P, 'n1', 'confirm');
    expect(rep.awards).toEqual([{ userId: 'u1', action: 'hazard_confirmed', base: 3 }]);
  });

  it('deneyim notunu doğrulamak puan üretmez (yalnız uyarı için anlamlı)', async () => {
    const { svc, notes, rep } = build();
    notes.ownership = { userId: 'u2', kind: 'experience', status: 'approved' };
    await svc.react(P, 'n1', 'confirm');
    expect(rep.awards).toHaveLength(0);
  });

  it('tekrar eden oy (created=false) puan üretmez', async () => {
    const { svc, notes, rep } = build();
    notes.reaction = { ...notes.reaction!, created: false };
    await svc.react(P, 'n1', 'helpful');
    expect(rep.awards).toHaveLength(0);
  });

  it('çelişki bildirimi sayacı döner', async () => {
    const { svc, notes } = build();
    notes.reaction = { ...notes.reaction!, disputeCount: 2, movedToReview: true };
    await expect(svc.react(P, 'n1', 'dispute')).resolves.toMatchObject({ disputeCount: 2 });
  });
});
