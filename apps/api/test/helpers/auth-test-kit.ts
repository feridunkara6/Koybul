import { generateKeyPairSync } from 'node:crypto';
import { AppProblem } from '../../src/common/problem/problem';
import { RoleCode } from '../../src/core/auth/principal';
import { FirebaseIdentity } from '../../src/infrastructure/firebase/firebase-token.verifier';
import {
  CreateSessionInput,
  SessionRepository,
} from '../../src/modules/auth/domain/session.repository';
import { UserAccountRepository } from '../../src/modules/auth/domain/user-account.repository';
import { SessionRecord, UserAccount } from '../../src/modules/auth/domain/auth.types';

/** Test RSA anahtar çifti üretir ve env'e uygun PEM döndürür (yalnız testte). */
export function generateTestKeys(): { privatePem: string; publicPem: string } {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  return {
    privatePem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
    publicPem: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
  };
}

/** Sahte Firebase doğrulayıcı: 'ftok:<json>' biçimli test token'larını çözer. */
export class FakeFirebaseVerifier {
  async verify(idToken: string): Promise<FirebaseIdentity> {
    if (!idToken.startsWith('ftok:')) {
      throw new AppProblem('invalid-token');
    }
    return JSON.parse(idToken.slice(5)) as FirebaseIdentity;
  }
}

/** Bellek-içi oturum deposu — SessionService birim testleri için. */
export class InMemorySessionRepository implements SessionRepository {
  readonly rows = new Map<string, SessionRecord & { tokenHash: string }>();

  async create(input: CreateSessionInput): Promise<void> {
    this.rows.set(input.id, {
      id: input.id,
      userId: input.userId,
      familyId: input.familyId,
      expiresAt: input.expiresAt,
      revokedAt: null,
      tokenHash: input.tokenHash,
    });
  }

  async findByTokenHash(tokenHash: string): Promise<SessionRecord | null> {
    for (const row of this.rows.values()) {
      if (row.tokenHash === tokenHash) return { ...row };
    }
    return null;
  }

  async revoke(id: string): Promise<void> {
    const row = this.rows.get(id);
    if (row) row.revokedAt = new Date();
  }

  async revokeFamily(familyId: string): Promise<void> {
    for (const row of this.rows.values()) {
      if (row.familyId === familyId && row.revokedAt === null) row.revokedAt = new Date();
    }
  }

  async revokeAllForUser(userId: string): Promise<void> {
    for (const row of this.rows.values()) {
      if (row.userId === userId && row.revokedAt === null) row.revokedAt = new Date();
    }
  }

  async countActiveFamilies(userId: string): Promise<number> {
    const families = new Set<string>();
    for (const row of this.rows.values()) {
      if (row.userId === userId && row.revokedAt === null) families.add(row.familyId);
    }
    return families.size;
  }

  async findOldestActiveFamilyId(userId: string): Promise<string | null> {
    let oldest: (SessionRecord & { tokenHash: string }) | null = null;
    for (const row of this.rows.values()) {
      if (row.userId === userId && row.revokedAt === null) {
        if (!oldest || row.id < oldest.id) oldest = row; // id = uuidv7 → zaman sıralı
      }
    }
    return oldest?.familyId ?? null;
  }

  async listActiveSessionIds(userId: string): Promise<string[]> {
    const ids: string[] = [];
    for (const row of this.rows.values()) {
      if (row.userId === userId && row.revokedAt === null) ids.push(row.id);
    }
    return ids;
  }
}

/** Bellek-içi jti karalistesi. */
export class InMemoryJtiBlacklist {
  readonly blocked = new Set<string>();

  async block(jti: string): Promise<void> {
    this.blocked.add(jti);
  }

  async isBlocked(jti: string): Promise<boolean> {
    return this.blocked.has(jti);
  }
}

/** Bellek-içi hesap deposu. */
export class InMemoryUserAccountRepository implements UserAccountRepository {
  readonly byFirebaseUid = new Map<string, UserAccount>();
  suspendedIds = new Set<string>();

  async upsertFromIdentity(id: string, identity: FirebaseIdentity): Promise<UserAccount> {
    const existing = this.byFirebaseUid.get(identity.uid);
    if (existing) {
      if (existing.isGuest && identity.provider !== 'anonymous') existing.isGuest = false;
      return { ...existing };
    }
    const account: UserAccount = {
      id,
      firebaseUid: identity.uid,
      role: 'user',
      isGuest: identity.provider === 'anonymous',
      locale: 'tr',
      status: 'active',
    };
    this.byFirebaseUid.set(identity.uid, account);
    return { ...account };
  }

  async findActiveById(id: string): Promise<UserAccount | null> {
    if (this.suspendedIds.has(id)) return null;
    for (const account of this.byFirebaseUid.values()) {
      if (account.id === id) return { ...account };
    }
    return null;
  }

  /** Gerçek SQL gibi: yalnız `user` rolü yükseltilir, üstü DOKUNULMAZ. */
  async promoteToModerator(userId: string): Promise<RoleCode> {
    for (const account of this.byFirebaseUid.values()) {
      if (account.id !== userId) continue;
      if (account.role === 'user' && !account.isGuest) account.role = 'moderator';
      this.promoted.push(userId);
      return account.role;
    }
    return 'user';
  }

  /** Yükseltme çağrılarının kaydı — testler bunu doğrular. */
  readonly promoted: string[] = [];
}
