import { UsersService } from '../src/modules/users/application/users.service';
import { SessionService } from '../src/modules/auth/application/session.service';
import { UserRepository, DeletionAudit } from '../src/modules/users/domain/user.repository';
import { PublicCaptain, UpdateMeInput, UserMe } from '../src/modules/users/domain/user.types';
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
});
