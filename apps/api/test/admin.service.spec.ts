import {
  ADMIN_GRANT_PRODUCT_ID,
  AdminService,
} from '../src/modules/admin/application/admin.service';
import { AdminRepository, AdminStats } from '../src/modules/admin/domain/admin.repository';
import { AppProblem } from '../src/common/problem/problem';

/** Bellek-içi sahte depo — YÖNETİM PANELİ (kurucu talebi 2026-09-25). */
class FakeAdminRepo implements AdminRepository {
  user: { id: string; email: string; premiumUntil: Date | null } | null = null;
  saved: { userId: string; until: Date; productId: string } | null = null;

  async stats(): Promise<AdminStats> {
    return {
      totalUsers: 42,
      guestUsers: 7,
      newUsers7d: 5,
      premiumActive: 3,
      pendingModeration: 2,
      totalReviews: 10,
      totalNotes: 20,
    };
  }

  async findUserByEmail(email: string) {
    return this.user && this.user.email.toLowerCase() === email.toLowerCase() ? this.user : null;
  }

  async setPremium(userId: string, until: Date, productId: string): Promise<void> {
    this.saved = { userId, until, productId };
  }
}

const NOW = new Date('2026-09-25T12:00:00.000Z');

function make(repo: FakeAdminRepo): AdminService {
  const s = new AdminService(repo);
  s.now = () => NOW;
  return s;
}

describe('AdminService (yönetim paneli, kurucu talebi 2026-09-25)', () => {
  it('stats: depodaki sayıları olduğu gibi taşır', async () => {
    const s = make(new FakeAdminRepo());
    await expect(s.stats()).resolves.toMatchObject({ totalUsers: 42, premiumActive: 3 });
  });

  it('premium tanımlama: hesabı olmayan e-posta → not-found (panel dürüst mesaj gösterir)', async () => {
    const s = make(new FakeAdminRepo());
    await expect(s.grantPremium('yok@ornek.com', 3)).rejects.toMatchObject({
      problemType: 'not-found',
    });
  });

  it('premium tanımlama: süresi geçmiş/hiç olmamış hesapta süre BUGÜNDEN başlar', async () => {
    const repo = new FakeAdminRepo();
    repo.user = { id: 'u1', email: 'kaptan@ornek.com', premiumUntil: null };
    const s = make(repo);
    const r = await s.grantPremium('kaptan@ornek.com', 3);
    expect(r.premiumUntil).toBe('2026-12-25T12:00:00.000Z');
    expect(repo.saved).toMatchObject({ userId: 'u1', productId: ADMIN_GRANT_PRODUCT_ID });
  });

  it('premium tanımlama: süresi HÂLÂ dolu hesapta yeni süre kalanın ÜSTÜNE eklenir', async () => {
    const repo = new FakeAdminRepo();
    repo.user = {
      id: 'u1',
      email: 'kaptan@ornek.com',
      premiumUntil: new Date('2026-11-01T00:00:00.000Z'),
    };
    const s = make(repo);
    const r = await s.grantPremium('kaptan@ornek.com', 1);
    expect(r.premiumUntil).toBe('2026-12-01T00:00:00.000Z'); // kaptan kaybetmez
  });

  it('AppProblem sözleşmesi: not-found problemType kısa kodunu taşır', () => {
    expect(new AppProblem('not-found').problemType).toBe('not-found');
  });
});
