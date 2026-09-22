/// Satın alma katmanı sözleşmesi (P3, kurucu onayı 2026-09-21).
///
/// Mağaza (StoreKit) erişimi bu arayüzün ARKASINDADIR: gerçek uygulama
/// `infrastructure/purchase_gateway_iap.dart` (iOS/Android), web ve testler
/// içinse stub/sahte kullanılır. Fiyatlar HER ZAMAN mağazadan gelir — koda
/// tek bir fiyat yazılmaz (fiyatı App Store Connect belirler; "tahmin yok"
/// ilkesinin satın alma karşılığı).
library;

/// Mağaza ürün kimlikleri — App Store Connect'te AYNEN bu adlarla açılır
/// (sunucudaki apple.types.ts KOYBUL_PRODUCT_IDS ile birebir aynı).
const String kPremiumYearlyId = 'koybul.premium.yillik';
const String kPremiumMonthlyId = 'koybul.premium.aylik';

/// Mağazadan okunmuş bir abonelik paketi.
class PremiumPackage {
  const PremiumPackage({
    required this.id,
    required this.price,
    required this.rawPrice,
    required this.currencySymbol,
  });

  final String id;

  /// Mağazanın YEREL para birimiyle biçimlediği fiyat (ör. '₺599,99') —
  /// ekranda aynen bu gösterilir.
  final String price;

  /// Sayısal fiyat — yalnız "aylık karşılığı" hesabı için (yıllık ÷ 12).
  final double rawPrice;
  final String currencySymbol;

  bool get isYearly => id == kPremiumYearlyId;

  /// Yıllık paketin dürüst aylık karşılığı (basit bölme, kuruş yuvarlanır).
  String get perMonthLabel =>
      '$currencySymbol${(rawPrice / 12).toStringAsFixed(2)}';
}

/// Satın alma akışından gelen olaylar.
enum PurchaseOutcomeKind {
  /// Satın alındı ya da geri yüklendi — [PurchaseOutcome.transactionId] dolu;
  /// sunucuya bağlanmalı (link).
  purchased,

  /// Kullanıcı vazgeçti — hata DEĞİLDİR, sessizce eski ekrana dönülür.
  canceled,

  /// Mağaza hatası — kullanıcıya kibar genel mesaj gösterilir.
  failed,

  /// "Geri yükle" taraması bitti (yeni bir şey bulunmamış olabilir).
  restoreFinished,
}

class PurchaseOutcome {
  const PurchaseOutcome(this.kind, {this.transactionId});

  final PurchaseOutcomeKind kind;
  final String? transactionId;
}

/// Mağaza kapısı — testlerde sahte, web'de stub ile değiştirilir.
abstract interface class PurchaseGateway {
  /// Mağazaya şu an ulaşılabiliyor mu? (web: her zaman false)
  Future<bool> isAvailable();

  /// İki paketi mağazadan okur (yıllık önce). Bulunamayan paket listeden düşer.
  Future<List<PremiumPackage>> loadPackages();

  /// Satın alma başlatır; sonuç [outcomes] akışından gelir.
  Future<void> buy(PremiumPackage package);

  /// Önceki satın alımları tarar; bulunanlar [outcomes]'a `purchased` olarak
  /// düşer, tarama bitince `restoreFinished` gelir.
  Future<void> restore();

  Stream<PurchaseOutcome> get outcomes;

  void dispose();
}
