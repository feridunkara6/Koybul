import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PREMIUM TANITIMI GÖSTERİLDİ Mİ? (kurucu isteği 2026-09-23) — cihaz başına
/// tek kayıt. Depo kuralı: testler gerçek shared_preferences'a asla gitmez,
/// sağlayıcı sahteyle değiştirilir (docs/15).
abstract interface class PremiumIntroStore {
  Future<bool> wasShown();

  Future<void> markShown();
}

final Provider<PremiumIntroStore> premiumIntroStoreProvider =
    Provider<PremiumIntroStore>((_) => const SharedPrefsPremiumIntroStore());

/// Gerçek uygulama — depo yoksa sessizce "gösterildi" sayar (aynı oturumda
/// üst üste açılmaması için güvenli taraf: tanıtım eksik kalır, rahatsızlık
/// olmaz; premium yolları zaten profilde ve kilit noktalarında açık).
class SharedPrefsPremiumIntroStore implements PremiumIntroStore {
  const SharedPrefsPremiumIntroStore();

  static const String _key = 'premium.intro_shown';

  @override
  Future<bool> wasShown() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markShown() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // en iyi çaba
    }
  }
}
