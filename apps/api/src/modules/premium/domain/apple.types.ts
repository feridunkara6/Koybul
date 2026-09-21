/**
 * Apple abonelik durumu — App Store Server API'den türetilmiş sunucu-içi model
 * (P2, kurucu onayı 2026-09-21).
 */
export interface AppleSubscriptionState {
  originalTransactionId: string;
  /** Ürün kimliği (ör. koybul.premium.yillik); çözülemezse null. */
  productId: string | null;
  /** Erişim hakkı VAR mı? (status 1 = aktif, 4 = fatura ertelemesi/grace) */
  entitled: boolean;
  /** Apple'ın ham durumu: 1 aktif, 2 bitti, 3 fatura yeniden deneme, 4 grace, 5 iade. */
  appleStatus: number;
  /** Abonelik bitiş anı (signedTransactionInfo.expiresDate); yoksa null. */
  expiresAt: Date | null;
}

/**
 * App Store Server API kapısı. `configured=false` iken uçlar 503 döner
 * (panelde Apple anahtarı tanımlanana dek — Sentry deseni).
 */
export interface AppleSubscriptionGateway {
  readonly configured: boolean;
  /** Aboneliğin GÜNCEL durumunu Apple'dan sorar; Apple tanımıyorsa null. */
  fetchState(originalTransactionId: string): Promise<AppleSubscriptionState | null>;
}

export const APPLE_SUBSCRIPTION_GATEWAY = Symbol('APPLE_SUBSCRIPTION_GATEWAY');

/**
 * Mağaza ürün kimlikleri (premium v3 raporu §6 — App Store Connect'te AYNEN bu
 * adlarla açılmalı; mobil paket ekranı da bu ikiliyi kullanır).
 */
export const KOYBUL_PRODUCT_IDS = {
  yearly: 'koybul.premium.yillik',
  monthly: 'koybul.premium.aylik',
} as const;
