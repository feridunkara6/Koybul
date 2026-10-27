import { Inject, Injectable } from '@nestjs/common';
import { AppProblem } from '../../../common/problem/problem';
import {
  ADMIN_REPOSITORY,
  AdminContentType,
  AdminRepository,
  AdminStats,
  PremiumGrantResult,
} from '../domain/admin.repository';

/** Elle tanımlanan premium'un ürün kimliği — Apple ürünlerinden ayrışır ki
 *  teşhiste "bu abonelik mağazadan mı, yönetimden mi" tek bakışta görülsün. */
export const ADMIN_GRANT_PRODUCT_ID = 'koybul.premium.admin';

/// YÖNETİM PANELİ servisi (kurucu talebi 2026-09-25): istatistik + elle
/// premium tanımlama. Uçlar RolesGuard ile 'admin' asgari rolüne kilitlidir;
/// yetki denetimi SUNUCUDADIR (istemcideki görünürlük yalnız kolaylıktır).
@Injectable()
export class AdminService {
  constructor(@Inject(ADMIN_REPOSITORY) private readonly repo: AdminRepository) {}

  /** Testlerde sabitlenebilir saat. */
  now: () => Date = () => new Date();

  stats(): Promise<AdminStats> {
    return this.repo.stats(this.now());
  }

  /**
   * E-postayla premium tanımlar. Süre AY cinsindendir; hesabın SÜRESİ HÂLÂ
   * DOLU ise yeni süre kalan sürenin ÜSTÜNE eklenir (kaptan kaybetmez),
   * dolmuşsa bugünden başlar. Hesap yoksa 'not-found' döner — panel bunu
   * "bu e-postayla kayıtlı hesap yok" diye gösterir.
   */
  async grantPremium(email: string, months: number): Promise<PremiumGrantResult> {
    const user = await this.repo.findUserByEmail(email.trim());
    if (!user) throw new AppProblem('not-found');
    const now = this.now();
    const base =
      user.premiumUntil && user.premiumUntil.getTime() > now.getTime()
        ? new Date(user.premiumUntil)
        : new Date(now);
    const until = new Date(base);
    until.setUTCMonth(until.getUTCMonth() + months);
    await this.repo.setPremium(user.id, until, ADMIN_GRANT_PRODUCT_ID);
    return { email: user.email, premiumUntil: until.toISOString() };
  }

  /** İÇERİK YÖNETİMİ (2026-10-27): tür başına en yeni içerikler. */
  async listContent(
    type: AdminContentType,
    limit: number,
  ): Promise<
    {
      id: string;
      title: string;
      authorName: string | null;
      status: string | null;
      createdAt: string;
    }[]
  > {
    const rows = await this.repo.listContent(type, limit);
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      authorName: r.authorName,
      status: r.status,
      createdAt: r.createdAt.toISOString(),
    }));
  }

  /** Yayından indirme (yumuşak silme). Bulunamazsa 404 — panel dürüst söyler. */
  async deleteContent(type: AdminContentType, id: string): Promise<void> {
    const ok = await this.repo.deleteContent(type, id);
    if (!ok) throw new AppProblem('not-found');
  }
}
