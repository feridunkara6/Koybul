import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/purchase_gateway.dart';

/// GERÇEK mağaza kapısı (P3): `in_app_purchase` üzerinden StoreKit/Play.
/// Koşullu import bunu yalnız iOS/Android derlemesinde seçer.
///
/// GÜVEN MODELİ: satın alma başarısı burada YETMEZ — premium'u sunucu,
/// işlem kimliğini Apple'dan doğrulayıp hesaba yazınca verir (P2). Buradan
/// yalnız işlem kimliği yukarı taşınır.
PurchaseGateway createPurchaseGateway() => IapPurchaseGateway();

class IapPurchaseGateway implements PurchaseGateway {
  IapPurchaseGateway() {
    // Mağaza olay akışı uygulama açıkken tek yerden dinlenir; yarım kalmış
    // işlemler (uygulama satın alma ortasında kapanmışsa) da buraya düşer.
    try {
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object _) =>
            _outcomes.add(const PurchaseOutcome(PurchaseOutcomeKind.failed)),
      );
    } catch (_) {
      // Mağaza eklentisi yoksa (test ortamı gibi) kapı "kapalı" davranır.
      _subscription = null;
    }
  }

  final StreamController<PurchaseOutcome> _outcomes =
      StreamController<PurchaseOutcome>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  Future<bool> isAvailable() async {
    if (_subscription == null) return false;
    try {
      return await InAppPurchase.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<PremiumPackage>> loadPackages() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      const <String>{kPremiumYearlyId, kPremiumMonthlyId},
    );
    final List<PremiumPackage> packages = response.productDetails
        .map(
          (ProductDetails d) => PremiumPackage(
            id: d.id,
            price: d.price,
            rawPrice: d.rawPrice,
            currencySymbol: d.currencySymbol,
          ),
        )
        .toList()
      // Yıllık önde (paket ekranı kurgusu — premium v3 raporu §6).
      ..sort((a, b) => (a.isYearly ? 0 : 1).compareTo(b.isYearly ? 0 : 1));
    return packages;
  }

  @override
  Future<void> buy(PremiumPackage package) async {
    final response = await InAppPurchase.instance.queryProductDetails(
      <String>{package.id},
    );
    if (response.productDetails.isEmpty) {
      _outcomes.add(const PurchaseOutcome(PurchaseOutcomeKind.failed));
      return;
    }
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
    );
  }

  @override
  Future<void> restore() async {
    await InAppPurchase.instance.restorePurchases();
    _outcomes.add(const PurchaseOutcome(PurchaseOutcomeKind.restoreFinished));
  }

  void _onPurchaseUpdates(List<PurchaseDetails> updates) {
    for (final PurchaseDetails p in updates) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // İşlem kimliği sunucuya gider; sunucu Apple'dan kanonik
          // originalTransactionId'yi kendisi çözer (P3 sunucu yaması).
          final String? txId = p.purchaseID;
          _outcomes.add(
            txId == null || txId.isEmpty
                ? const PurchaseOutcome(PurchaseOutcomeKind.failed)
                : PurchaseOutcome(PurchaseOutcomeKind.purchased,
                    transactionId: txId),
          );
        case PurchaseStatus.canceled:
          _outcomes.add(const PurchaseOutcome(PurchaseOutcomeKind.canceled));
        case PurchaseStatus.error:
          _outcomes.add(const PurchaseOutcome(PurchaseOutcomeKind.failed));
        case PurchaseStatus.pending:
          break; // Mağaza penceresi açık — sonuç sonraki güncellemede.
      }
      // Mağaza defterini kapat — kapatılmayan işlem her açılışta yeniden düşer.
      if (p.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  @override
  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;

  @override
  void dispose() {
    _subscription?.cancel();
    _outcomes.close();
  }
}
