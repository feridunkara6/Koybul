import { PublicCaptain, UpdateMeInput, UserMe } from './user.types';

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
}

export const USER_REPOSITORY = Symbol('USER_REPOSITORY');
