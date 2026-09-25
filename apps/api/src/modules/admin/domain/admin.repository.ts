/**
 * YÖNETİM PANELİ deposu (kurucu talebi 2026-09-25): panelin saydığı her şey
 * sunucunun ZATEN bildiği verilerdir — indirme sayısı burada YOKTUR (o veri
 * yalnız App Store Connect'tedir; dürüstlük ilkesi gereği panelde
 * "kayıtlı kullanıcı" gösterilir, "indirme" değil).
 */
export interface AdminStats {
  /** Gerçek (misafir olmayan, silinmemiş) hesap sayısı. */
  totalUsers: number;
  /** Misafir oturum sayısı (cihaz denedi, hesap açmadı). */
  guestUsers: number;
  /** Son 7 günde açılan gerçek hesaplar. */
  newUsers7d: number;
  /** premiumUntil > now olan hesaplar (Apple aboneliği ya da elle tanımlama). */
  premiumActive: number;
  /** Moderasyon kuyruğunda bekleyen iş sayısı (yorum/not/bildirim). */
  pendingModeration: number;
  /** Toplam yorum ve toplam kaptan notu (onaylı+bekleyen). */
  totalReviews: number;
  totalNotes: number;
}

export interface PremiumGrantResult {
  email: string;
  /** Yeni bitiş anı (ISO). */
  premiumUntil: string;
}

export interface AdminRepository {
  stats(now: Date): Promise<AdminStats>;

  /** E-postayla GERÇEK hesabı bulur (misafir/silinmiş hariç); yoksa null. */
  findUserByEmail(
    email: string,
  ): Promise<{ id: string; email: string; premiumUntil: Date | null } | null>;

  /** premiumUntil + ürün kimliğini yazar. */
  setPremium(userId: string, until: Date, productId: string): Promise<void>;
}

export const ADMIN_REPOSITORY = Symbol('ADMIN_REPOSITORY');
