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

/**
 * İÇERİK YÖNETİMİ (kurucu talebi 2026-10-27): yönetici uygulamadaki yayında
 * ya da bekleyen İÇERİKLERİ listeler ve SİLEBİLİR (yumuşak silme — veri
 * KVKK/denetim için durur, yayından anında iner). Düzenleme BİLEREK yok:
 * kullanıcının imzasını taşıyan içeriği yöneticinin değiştirmesi yanlış
 * temsildir; yanlış içerik ya silinir ya moderasyonda reddedilir.
 */
export type AdminContentType = 'routes' | 'questions' | 'answers' | 'notes' | 'reviews' | 'boats';

export const ADMIN_CONTENT_TYPES: readonly AdminContentType[] = [
  'routes',
  'questions',
  'answers',
  'notes',
  'reviews',
  'boats',
] as const;

export interface AdminContentRow {
  id: string;
  /** Başlık ya da gövdeden kısaltılmış özet. */
  title: string;
  authorName: string | null;
  /** 'approved' | 'pending' | 'rejected' | tekneler için 'visible'/'hidden'. */
  status: string | null;
  createdAt: Date;
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

  /** Tür bazında en yeni içerikler (silinmemiş; en yeni başta). */
  listContent(type: AdminContentType, limit: number): Promise<AdminContentRow[]>;

  /** Yumuşak silme + varsa bekleyen moderasyon görevini kapatır. */
  deleteContent(type: AdminContentType, id: string): Promise<boolean>;
}

export const ADMIN_REPOSITORY = Symbol('ADMIN_REPOSITORY');
