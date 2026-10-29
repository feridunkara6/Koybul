import { Inject, Injectable } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import { Principal } from '../../../core/auth/principal';
import { SessionService } from '../../auth/application/session.service';
import { DeletionAudit, USER_REPOSITORY, UserRepository } from '../domain/user.repository';
import { FollowedCaptain, PublicCaptain, UpdateMeInput, UserMe } from '../domain/user.types';

/** users/me use-case'leri (docs/23 §10 #4-5). */
@Injectable()
export class UsersService {
  constructor(
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly sessions: SessionService,
  ) {}

  async getMe(principal: Principal): Promise<UserMe> {
    const me = await this.users.getMe(principal.userId);
    if (!me) throw new AppProblem('not-found');
    return me;
  }

  /**
   * Herkese açık kaptan kartı (Hafta 1B). Kimlik İSTEMEZ — toplulukta imzalı
   * içeriği olan herkesin kartviziti gezilebilir. Silinmiş/pasif kullanıcı
   * ve bilinmeyen kimlik AYNI 404'ü alır (varlık enumerasyonu sinyali yok).
   */
  async getPublic(userId: string): Promise<PublicCaptain> {
    const captain = await this.users.getPublic(userId);
    if (!captain) throw new AppProblem('not-found');
    return captain;
  }

  async updateMe(principal: Principal, patch: UpdateMeInput): Promise<UserMe> {
    // Boş patch anlamsızdır; istemci hatasını erken yakala (edge case).
    if (
      patch.locale === undefined &&
      (!patch.profile || Object.keys(patch.profile).length === 0) &&
      (!patch.settings || Object.keys(patch.settings).length === 0)
    ) {
      throw new AppProblem('validation-error', 'Güncellenecek alan yok.', [
        { field: '(root)', code: 'empty_patch', message: 'En az bir alan gönderilmeli' },
      ]);
    }
    // Lazy init garantisi: profil/ayar satırları yoksa oluşsun.
    await this.getMe(principal);
    return this.users.updateMe(principal.userId, patch);
  }

  /**
   * Hesap silme (KVKK, docs/29 SEC-26): anonimleştir + tüm oturumları anında sonlandır.
   * Sıra önemlidir: önce veri anonimleşir; oturum sonlandırma en son (istek kendi
   * token'ıyla tamamlanabilsin diye yanıttan hemen önce).
   */
  async deleteMe(principal: Principal, audit: DeletionAudit): Promise<void> {
    await this.getMe(principal); // silinmiş hesaba ikinci silme → 404 (idempotent görünüm yok; bilinçli)
    await this.users.softDeleteAndAnonymize(principal.userId, audit);
    await this.sessions.terminateUser(principal.userId);
  }

  // --- TAKİP (SP-3a, kurucu onayı 2026-10-31) ---

  /** Takip et: kendi kendini takip 422, olmayan/pasif hedef 404; tekrar 204. */
  async follow(followerId: string, targetId: string): Promise<void> {
    if (followerId === targetId) {
      throw new AppProblem('validation-error', 'Kendini takip edemezsin.', [
        { field: 'id', code: 'self_follow', message: 'Hedef kendin olamaz' },
      ]);
    }
    if (!(await this.users.userExists(targetId))) throw new AppProblem('not-found');
    await this.users.follow(followerId, targetId);
  }

  async unfollow(followerId: string, targetId: string): Promise<void> {
    await this.users.unfollow(followerId, targetId);
  }

  following(userId: string): Promise<FollowedCaptain[]> {
    return this.users.following(userId);
  }
}
