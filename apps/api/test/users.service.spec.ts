import { UsersService } from '../src/modules/users/application/users.service';
import { SessionService } from '../src/modules/auth/application/session.service';
import { UserRepository, DeletionAudit } from '../src/modules/users/domain/user.repository';
import {
  FollowedCaptain,
  PublicCaptain,
  UpdateMeInput,
  UserMe,
} from '../src/modules/users/domain/user.types';
import { Principal } from '../src/core/auth/principal';

const PRINCIPAL: Principal = {
  userId: 'u-1',
  role: 'user',
  isGuest: false,
  familyId: 'f-1',
  jti: 'j-1',
};

function me(): UserMe {
  return {
    id: 'u-1',
    email: 'a@b.c',
    phone: null,
    role: 'user',
    isGuest: false,
    locale: 'tr',
    countryCode: 'TR',
    createdAt: '2026-07-07T00:00:00.000Z',
    profile: { displayName: 'Kaptan', fullName: null, bio: null, experienceYears: null },
    settings: { theme: 'system', units: 'metric', marketingConsent: false },
  };
}

class FakeUserRepo implements UserRepository {
  deleted: string[] = [];
  patches: UpdateMeInput[] = [];
  exists = true;

  async getMe(): Promise<UserMe | null> {
    return this.exists ? me() : null;
  }

  async getPublic(userId: string): Promise<PublicCaptain | null> {
    if (!this.exists) return null;
    return {
      id: userId,
      displayName: 'Kaptan Levent',
      bio: 'Göcek sularındayım.',
      experienceYears: 14,
      memberSince: '2026-07-07T00:00:00.000Z',
      points: 840,
      levelCode: 'guide',
      approvedCount: 46,
      helpfulReceived: 120,
      badges: ['first_contribution', 'hazard_hero'],
      // SP-3a Takip (2026-10-31): herkese açık takipçi sayısı.
      followerCount: 12,
      // SP-1 Kimlik (2026-10-29): vitrin — onaylı not + rota örneği.
      recentContributions: [
        {
          kind: 'note',
          title: 'Kille Koyu',
          noteKind: 'experience',
          savedCount: null,
          createdAt: '2026-10-20T10:00:00.000Z',
        },
        {
          kind: 'route',
          title: 'Gökova batı turu',
          noteKind: null,
          savedCount: 18,
          createdAt: '2026-10-18T10:00:00.000Z',
        },
      ],
    };
  }

  async updateMe(_userId: string, patch: UpdateMeInput): Promise<UserMe> {
    this.patches.push(patch);
    return me();
  }

  async softDeleteAndAnonymize(userId: string, _audit: DeletionAudit): Promise<void> {
    this.deleted.push(userId);
    this.exists = false;
  }

  // --- TAKİP (SP-3a, 2026-10-31) ---

  follows: Array<[string, string]> = [];
  targetExists = true;

  async userExists(_userId: string): Promise<boolean> {
    return this.targetExists;
  }

  async follow(followerId: string, followedId: string): Promise<void> {
    // Gerçek repo idempotenttir (ON CONFLICT DO NOTHING) — fake de öyle.
    if (!this.follows.some(([a, b]) => a === followerId && b === followedId)) {
      this.follows.push([followerId, followedId]);
    }
  }

  async unfollow(followerId: string, followedId: string): Promise<void> {
    this.follows = this.follows.filter(([a, b]) => !(a === followerId && b === followedId));
  }

  async following(userId: string): Promise<FollowedCaptain[]> {
    return this.follows
      .filter(([a]) => a === userId)
      .map(([, b]) => ({ id: b, displayName: 'Kaptan ' + b, levelCode: 'new' }));
  }
}

class FakeSessions {
  terminated: string[] = [];

  async terminateUser(userId: string): Promise<void> {
    this.terminated.push(userId);
  }
}

describe('UsersService (unit)', () => {
  let repo: FakeUserRepo;
  let sessions: FakeSessions;
  let service: UsersService;

  beforeEach(() => {
    repo = new FakeUserRepo();
    sessions = new FakeSessions();
    service = new UsersService(repo, sessions as unknown as SessionService);
  });

  it('getMe: silinmiş/yok hesapta not-found', async () => {
    repo.exists = false;
    await expect(service.getMe(PRINCIPAL)).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('getPublic: kart PII TAŞIMAZ ve itibar alanlarını döndürür (Hafta 1B)', async () => {
    const card = await service.getPublic('u-2');
    expect(card.displayName).toBe('Kaptan Levent');
    expect(card.points).toBe(840);
    expect(card.badges).toContain('hazard_hero');
    // PII sözleşmesi: e-posta/rol/premium alanları kartta YOKTUR.
    expect(card as unknown as Record<string, unknown>).not.toHaveProperty('email');
    expect(card as unknown as Record<string, unknown>).not.toHaveProperty('role');
  });

  it('getPublic: silinmiş/bilinmeyen kullanıcıda not-found', async () => {
    repo.exists = false;
    await expect(service.getPublic('u-x')).rejects.toMatchObject({ problemType: 'not-found' });
  });

  it('updateMe: boş patch 422 empty_patch (edge)', async () => {
    await expect(service.updateMe(PRINCIPAL, {})).rejects.toMatchObject({
      problemType: 'validation-error',
    });
    await expect(service.updateMe(PRINCIPAL, { profile: {} })).rejects.toMatchObject({
      problemType: 'validation-error',
    });
    expect(repo.patches).toHaveLength(0);
  });

  it('updateMe: geçerli patch repoya ulaşır', async () => {
    await service.updateMe(PRINCIPAL, { settings: { theme: 'dark' } });
    expect(repo.patches).toEqual([{ settings: { theme: 'dark' } }]);
  });

  it('deleteMe: anonimleştirme + oturum sonlandırma SIRAYLA çağrılır', async () => {
    await service.deleteMe(PRINCIPAL, { ip: '10.0.0.1', requestId: 'r-1' });
    expect(repo.deleted).toEqual(['u-1']);
    expect(sessions.terminated).toEqual(['u-1']);
  });

  it('deleteMe: zaten silinmiş hesapta 404 (ikinci silme)', async () => {
    await service.deleteMe(PRINCIPAL, {});
    await expect(service.deleteMe(PRINCIPAL, {})).rejects.toMatchObject({
      problemType: 'not-found',
    });
    expect(repo.deleted).toHaveLength(1);
  });

  // --- TAKİP (SP-3a, 2026-10-31) ---

  it('follow: kendini takip 422 self_follow', async () => {
    await expect(service.follow('u-1', 'u-1')).rejects.toMatchObject({
      problemType: 'validation-error',
    });
    expect(repo.follows).toHaveLength(0);
  });

  it('follow: olmayan/pasif hedef 404', async () => {
    repo.targetExists = false;
    await expect(service.follow('u-1', 'u-2')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    expect(repo.follows).toHaveLength(0);
  });

  it('follow/unfollow: idempotent — tekrar çağrı hata üretmez', async () => {
    await service.follow('u-1', 'u-2');
    await service.follow('u-1', 'u-2'); // ikinci çağrı sessiz
    expect(repo.follows).toEqual([['u-1', 'u-2']]);

    await service.unfollow('u-1', 'u-2');
    await service.unfollow('u-1', 'u-2'); // satır yok, yine sessiz
    expect(repo.follows).toHaveLength(0);
  });

  it('following: takip ettiklerim listesi döner', async () => {
    await service.follow('u-1', 'u-2');
    const list = await service.following('u-1');
    expect(list).toEqual([{ id: 'u-2', displayName: 'Kaptan u-2', levelCode: 'new' }]);
  });
});
