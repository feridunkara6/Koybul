import { FollowedCaptain, PublicCaptain, UpdateMeInput, UserMe } from './user.types';

export interface DeletionAudit {
  ip?: string;
  requestId?: string;
}

/** users/me veri erişim sözleşmesi. */
export interface UserRepository {
  /** Profil/ayar satırları yoksa güvenli varsayılanlarla oluşturur (lazy init). */
  getMe(userId: string): Promise<UserMe | null>;
  /** Herkese açık kaptan kartı; silinmiş/pasif kullanıcıda null (Hafta 1B). */
  getPublic(userId: string): Promise<PublicCaptain | null>;
  updateMe(userId: string, patch: UpdateMeInput): Promise<UserMe>;
  /**
   * KVKK silme (docs/22 §1.5): soft delete + PII anonimleştirme + cihaz kayıtlarının
   * silinmesi + audit kaydı — TEK transaction içinde.
   */
  softDeleteAndAnonymize(userId: string, audit: DeletionAudit): Promise<void>;

  // --- TAKİP (SP-3a, kurucu onayı 2026-10-31) ---

  /** Hedef aktif bir kullanıcı mı? (takip öncesi varlık denetimi) */
  userExists(userId: string): Promise<boolean>;
  /** Takip satırı ekler; zaten varsa sessizce geçer (idempotent). */
  follow(followerId: string, followedId: string): Promise<void>;
  /** Takibi bırakır; satır yoksa sessizce geçer (idempotent). */
  unfollow(followerId: string, followedId: string): Promise<void>;
  /** Takip ettiklerim — en yeni takip önce. */
  following(userId: string): Promise<FollowedCaptain[]>;
}

export const USER_REPOSITORY = Symbol('USER_REPOSITORY');
