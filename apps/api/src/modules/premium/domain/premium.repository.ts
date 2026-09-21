/**
 * Premium veri erişim sözleşmesi (P1, kurucu onayı 2026-09-21).
 * Abonelik gerçeği Apple'dadır (P2); burada yalnız sunucudaki yansıma okunur
 * ve keşif-hakkı defteri işletilir.
 */
export interface PremiumRepository {
  /**
   * Kullanıcının premium bitiş anı; hiç abone olmamışsa null.
   * (Kullanıcı yoksa da null — çağıran katman kimliği zaten doğrulamıştır.)
   */
  findPremiumUntil(userId: string): Promise<Date | null>;

  /** premiumUntil + son bilinen ürün (P2, /premium/me gövdesi için). */
  findSubscription(
    userId: string,
  ): Promise<{ premiumUntil: Date | null; productId: string | null }>;

  /** Bu ay (monthKey) bu kullanıcının açtığı FARKLI koy sayısı. */
  countUnlocks(userId: string, monthKey: string): Promise<number>;

  /** Bu koy, bu ay bu kullanıcı tarafından zaten açılmış mı? */
  hasUnlock(userId: string, locationId: string, monthKey: string): Promise<boolean>;

  /**
   * Keşif hakkı kullanımı — TEK TRANSAKSİYONDA "say → sınır altındaysa yaz".
   * Dönen değer:
   *  - 'created'  → yeni satır yazıldı (1 hak tüketildi)
   *  - 'existing' → aynı koy bu ay zaten açıktı (hak TÜKETİLMEDİ)
   *  - 'quota'    → aylık sınır dolu, satır yazılmadı
   */
  createUnlock(
    userId: string,
    locationId: string,
    monthKey: string,
    monthlyLimit: number,
  ): Promise<'created' | 'existing' | 'quota'>;

  /**
   * Bu Apple aboneliği (originalTransactionId) hangi hesaba bağlı? Yoksa null.
   * (P2: bir abonelik TEK hesaba bağlanır — ux_users_apple_original_transaction_id.)
   */
  findUserIdByOriginalTransactionId(originalTransactionId: string): Promise<string | null>;

  /**
   * Apple'dan doğrulanmış GÜNCEL durumu kullanıcıya yazar (P2). premiumUntil
   * geçmişte olabilir (bitmiş abonelik) — alan yine yazılır: "eski abone"
   * bilgisi kayıtların salt-okunur korunması için gereklidir.
   */
  saveSubscription(
    userId: string,
    state: { premiumUntil: Date | null; productId: string | null; originalTransactionId: string },
  ): Promise<void>;
}

export const PREMIUM_REPOSITORY = Symbol('PREMIUM_REPOSITORY');
