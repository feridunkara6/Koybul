import { Principal } from '../src/core/auth/principal';
import { EarnedBadge, emptyBadgeStats } from '../src/modules/community/domain/badges';
import { ModerationService } from '../src/modules/community/application/moderation.service';
import { ReputationService } from '../src/modules/community/application/reputation.service';
import {
  DecisionResult,
  ModerationDecision,
  ModerationRepository,
} from '../src/modules/community/domain/moderation.types';
import {
  AuthorState,
  ReputationRepository,
} from '../src/modules/community/domain/reputation.repository';

const M: Principal = { userId: 'mod', role: 'moderator', isGuest: false, familyId: 'f', jti: 'j' };

class FakeMod implements ModerationRepository {
  result: DecisionResult | null = {
    entityType: 'note',
    entityId: 'n1',
    ownerUserId: 'author',
    decision: 'approve',
    noteKind: 'hazard',
    bodyLength: 200,
  };
  queue() {
    return Promise.resolve([]);
  }
  counts() {
    return Promise.resolve({});
  }
  decide(_t: string, _m: string, decision: ModerationDecision): Promise<DecisionResult | null> {
    return Promise.resolve(this.result ? { ...this.result, decision } : null);
  }
}

class FakeRep implements ReputationRepository {
  granted: string[] = [];
  awards: { userId: string; action: string; base: number }[] = [];
  recomputed: string[] = [];
  throwOnAward = false;
  awardWindow() {
    return Promise.resolve({
      todayPoints: 0,
      weekPoints: 0,
      todayEventsOfAction: 0,
      trustScore: 1,
    });
  }
  award(userId: string, action: string, points: number) {
    if (this.throwOnAward) return Promise.reject(new Error('db patladı'));
    this.awards.push({ userId, action, base: points });
    return Promise.resolve({ points, levelCode: 'new' as const, leveledUp: false });
  }
  helpfulPointsForEntity() {
    return Promise.resolve(0);
  }
  hasAwardedFor() {
    return Promise.resolve(false);
  }
  summary(): never {
    throw new Error('kullanılmıyor');
  }
  contributions() {
    return Promise.resolve([]);
  }
  recomputeTrust(userId: string) {
    this.recomputed.push(userId);
    return Promise.resolve(1);
  }
  badgeStats() {
    return Promise.resolve(emptyBadgeStats());
  }
  grantBadges(_userId: string, badges: EarnedBadge[]) {
    this.granted.push(...badges.map((b) => b.code));
    return Promise.resolve(badges);
  }
  authorState(): Promise<AuthorState> {
    return Promise.resolve({ trustScore: 1, approvedCount: 1, writeRestrictedUntil: null });
  }
}

function build(): { svc: ModerationService; repo: FakeMod; rep: FakeRep } {
  const repo = new FakeMod();
  const rep = new FakeRep();
  return { svc: new ModerationService(repo, new ReputationService(rep)), repo, rep };
}

describe('ModerationService.decide', () => {
  it('uyarı onayı 20 puan taban kullanır (en değerli katkı)', async () => {
    const { svc, rep } = build();
    await svc.decide(M, 't1', 'approve', null);
    expect(rep.awards).toEqual([{ userId: 'author', action: 'note_approved', base: 20 }]);
  });

  it('deneyim notu onayı 12 puan taban kullanır', async () => {
    const { svc, repo, rep } = build();
    repo.result = { ...repo.result!, noteKind: 'experience' };
    await svc.decide(M, 't1', 'approve', null);
    expect(rep.awards[0].base).toBe(12);
  });

  it('uzun yorum onayı 8, kısa yorum 3 puan taban kullanır', async () => {
    const long = build();
    long.repo.result = {
      ...long.repo.result!,
      entityType: 'review',
      noteKind: null,
      bodyLength: 300,
    };
    await long.svc.decide(M, 't1', 'approve', null);
    expect(long.rep.awards[0]).toMatchObject({ action: 'review_created', base: 8 });

    const short = build();
    short.repo.result = {
      ...short.repo.result!,
      entityType: 'review',
      noteKind: null,
      bodyLength: 20,
    };
    await short.svc.decide(M, 't1', 'approve', null);
    expect(short.rep.awards[0].base).toBe(3);
  });

  it('red CEZA yazar (negatif taban)', async () => {
    const { svc, rep } = build();
    await svc.decide(M, 't1', 'reject', 'off_topic');
    expect(rep.awards).toEqual([{ userId: 'author', action: 'content_rejected', base: -10 }]);
  });

  it('her karardan sonra güven katsayısı tazelenir', async () => {
    const { svc, rep } = build();
    await svc.decide(M, 't1', 'reject', 'duplicate');
    expect(rep.recomputed).toEqual(['author']);
  });

  it('sahibi çözülemeyen varlık tipinde puan YAZILMAZ', async () => {
    const { svc, repo, rep } = build();
    repo.result = { ...repo.result!, entityType: 'media', ownerUserId: null, noteKind: null };
    await expect(svc.decide(M, 't1', 'approve', null)).resolves.toMatchObject({
      pointsAwarded: 0,
    });
    expect(rep.awards).toHaveLength(0);
    expect(rep.recomputed).toHaveLength(0);
  });

  it('görev yoksa/başkası aldıysa 404', async () => {
    const { svc, repo } = build();
    repo.result = null;
    await expect(svc.decide(M, 't1', 'approve', null)).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('puan yazımı patlasa bile KARAR geçerli kalır', async () => {
    const { svc, rep } = build();
    rep.throwOnAward = true;
    await expect(svc.decide(M, 't1', 'approve', null)).resolves.toMatchObject({
      entityId: 'n1',
      pointsAwarded: 0,
    });
  });
});
