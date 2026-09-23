import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/premium/data/premium_intro_store.dart';
import 'package:dockly_mobile/features/premium/data/premium_offline_cache.dart';
import 'package:dockly_mobile/features/premium/domain/purchase_gateway.dart';

/// Sahte PREMIUM ÇEVRİMDIŞI İZ deposu (P4b) — bellek içi; depo kuralı gereği
/// testler gerçek shared_preferences'a asla gitmez (docs/15).
class FakePremiumOfflineStore implements PremiumOfflineStore {
  FakePremiumOfflineStore({this.toRead});

  /// [read] çağrısının döndüreceği iz (çevrimdışı senaryosu kurar).
  PremiumMe? toRead;

  /// Son [save] edilen durum (yazıldı mı denetimi).
  PremiumMe? saved;

  @override
  Future<void> save(PremiumMe me) async {
    saved = me;
  }

  @override
  Future<PremiumMe?> read() async => toRead;
}

/// Sahte MAĞAZA kapısı (varsayılan: mağaza YOK) — gerçek in_app_purchase
/// eklentisi widget testinde platform kanalına takılıp kalır; PremiumScreen
/// kuran her test bunu override eder.
class FakeUnavailablePurchaseGateway implements PurchaseGateway {
  final StreamController<PurchaseOutcome> _outcomes =
      StreamController<PurchaseOutcome>.broadcast();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<PremiumPackage>> loadPackages() async => const <PremiumPackage>[];

  @override
  Future<void> buy(PremiumPackage package) async {}

  @override
  Future<void> restore() async {}

  @override
  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;

  @override
  void dispose() {
    _outcomes.close();
  }
}

/// Sahte TANITIM İZİ deposu (bellek içi) — kayıt sonrası premium tanıtımı.
class FakePremiumIntroStore implements PremiumIntroStore {
  FakePremiumIntroStore({this.shown = false});

  bool shown;
  int markCalls = 0;

  @override
  Future<bool> wasShown() async => shown;

  @override
  Future<void> markShown() async {
    shown = true;
    markCalls += 1;
  }
}
