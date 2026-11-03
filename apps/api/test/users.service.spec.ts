import { UsersService } from '../src/modules/users/application/users.service';
import { SessionService } from '../src/modules/auth/application/session.service';
import { UserRepository, DeletionAudit } from '../src/modules/users/domain/user.repository';
import {
  BlockedUser,
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
      // PR-1 Profil düzeni (2026-11-03): takip sayısı + sezon şeridi.
      followingCount: 7,
      sharedTrips: 18,
      sharedRoutes: 6,
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

  // PR-1 (2026-11-03): takipçi listesi — following() aynası.
  async followers(userId: string): Promise<FollowedCaptain[]> {
    return this.follows
      .filter(([, b]) => b === userId)
      .map(([a]) => ({ id: a, displayName: 'Kaptan ' + a, levelCode: 'new' }));
  }

  // ENG-1 (2026-11-03): engelleme — gerçek repo gibi takip bağlarını düşürür.
  blocks: Array<[string, string]> = [];

  async block(blockerId: string, blockedId: string): Promise<void> {
    if (!this.blocks.some(([a, b]) => a === blockerId && b === blockedId)) {
      this.blocks.push([blockerId, blockedId]);
    }
    this.follows = this.follows.filter(
      ([a, b]) => !(a === blockerId && b === blockedId) && !(a === blockedId && b === blockerId),
    );
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    this.blocks = this.blocks.filter(([a, b]) => !(a === blockerId && b === blockedId));
  }

  async blockedList(userId: string): Promise<BlockedUser[]> {
    return this.blocks
      .filter(([a]) => a === userId)
      .map(([, b]) => ({
        id: b,
        displayName: 'Kaptan ' + b,
        levelCode: 'new',
        blockedAt: '2026-11-03T10:00:00.000Z',
      }));
  }

  async isBlockedBy(userId: string, targetId: string): Promise<boolean> {
    return this.blocks.some(([a, b]) => a === targetId && b === userId);
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

  // PR-1 Profil düzeni (kurucu onayı 2026-11-03): takipçi/takip listeleri.
  it('followersOf/followingOf: iki yön doğru döner (PR-1)', async () => {
    await service.follow('u-1', 'u-2');
    await service.follow('u-3', 'u-2');
    const followers = await service.followersOf('u-2');
    expect(followers.map((f) => f.id).sort()).toEqual(['u-1', 'u-3']);
    const following = await service.followingOf('u-1');
    expect(following.map((f) => f.id)).toEqual(['u-2']);
  });

  it('followersOf: olmayan/pasif hedef 404 (sızdırmaz)', async () => {
    repo.targetExists = false;
    await expect(service.followersOf('u-yok')).rejects.toMatchObject({
      problemType: 'not-found',
    });
    await expect(service.followingOf('u-yok')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  // --- ENGELLEME (ENG-1, kurucu onayı 2026-11-03) ---

  it('block: iki yöndeki takip bağları düşer; liste engeli gösterir', async () => {
    await service.follow('u-1', 'u-2'); // ben onu takip ediyorum
    await service.follow('u-2', 'u-1'); // o beni takip ediyor
    await service.block('u-1', 'u-2');
    await service.block('u-1', 'u-2'); // idempotent — hata yok
    expect(repo.follows).toHaveLength(0); // İKİ bağ da düştü
    const list = await service.blockedList('u-1');
    expect(list.map((b: BlockedUser) => b.id)).toEqual(['u-2']);
  });

  it('block: kendini engelleme 422; olmayan hedef 404', async () => {
    await expect(service.block('u-1', 'u-1')).rejects.toMatchObject({
      problemType: 'validation-error',
    });
    repo.targetExists = false;
    await expect(service.block('u-1', 'u-yok')).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('TAKİP KAPISI: engellenen kişi takip edemez — SESSİZCE yazılmaz (204)', async () => {
    await service.block('u-1', 'u-2'); // u-1, u-2'yi engelledi
    await service.follow('u-2', 'u-1'); // u-2 takip etmeye çalışır — hata YOK
    expect(repo.follows).toHaveLength(0); // ama bağ da YOK
  });

  it('unblock: idempotent; takip bağları kendiliğinden GERİ GELMEZ', async () => {
    await service.follow('u-2', 'u-1');
    await service.block('u-1', 'u-2');
    await service.unblock('u-1', 'u-2');
    await service.unblock('u-1', 'u-2'); // ikinci kez — sessiz
    expect(await service.blockedList('u-1')).toHaveLength(0);
    expect(repo.follows).toHaveLength(0); // düşen bağ geri gelmedi
    // Engel kalktı: artık yeniden takip EDEBİLİR (bilinçli karar).
    await service.follow('u-2', 'u-1');
    expect(repo.follows).toHaveLength(1);
  });
});
