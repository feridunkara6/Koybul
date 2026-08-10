import { FirebaseIdentity } from '../../../infrastructure/firebase/firebase-token.verifier';
import { RoleCode } from '../../../core/auth/principal';
import { UserAccount } from './auth.types';

/**
 * Kimlik köprüsünün users erişimi: upsert + misafir yükseltme (docs/23 §3.3).
 * firebase_uid sabit kimlik anahtarıdır; misafir→kayıtlı geçişte satır AYNI kalır.
 */
export interface UserAccountRepository {
  upsertFromIdentity(id: string, identity: FirebaseIdentity): Promise<UserAccount>;
  /** Refresh rotasyonu için: aktif (silinmemiş/askıya alınmamış) hesabı okur. */
  findActiveById(id: string): Promise<UserAccount | null>;
  /**
   * Hesabı moderatöre yükseltir ve OLUŞAN rolü döndürür (MODERATOR_EMAILS).
   * Yalnız `user` rolündeki satırı değiştirir: daha yüksek bir rol varsa
   * DOKUNMAZ ve o rolü aynen geri verir — yükseltme aracı, düşürme aracına
   * dönüşmemelidir.
   */
  promoteToModerator(userId: string): Promise<RoleCode>;
}

export const USER_ACCOUNT_REPOSITORY = Symbol('USER_ACCOUNT_REPOSITORY');
