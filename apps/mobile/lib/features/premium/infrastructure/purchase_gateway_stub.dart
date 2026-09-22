import 'dart:async';

import '../domain/purchase_gateway.dart';

/// WEB stub'ı (karar K6, premium v3 raporu §9): web'de mağaza yoktur —
/// paket ekranı iOS uygulamasına yönlendiren mesajı gösterir. Koşullu import
/// bu dosyayı yalnız web derlemesinde seçer; StoreKit kodu web paketine
/// hiç girmez (map_platform_web.dart ile aynı desen).
PurchaseGateway createPurchaseGateway() => _NoStoreGateway();

class _NoStoreGateway implements PurchaseGateway {
  final StreamController<PurchaseOutcome> _outcomes =
      StreamController<PurchaseOutcome>.broadcast();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<PremiumPackage>> loadPackages() async => const <PremiumPackage>[];

  @override
  Future<void> buy(PremiumPackage package) async {}

  @override
  Future<void> restore() async {
    _outcomes.add(const PurchaseOutcome(PurchaseOutcomeKind.restoreFinished));
  }

  @override
  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;

  @override
  void dispose() {
    _outcomes.close();
  }
}
