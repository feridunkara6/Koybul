import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/premium/data/premium_offline_cache.dart';

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
