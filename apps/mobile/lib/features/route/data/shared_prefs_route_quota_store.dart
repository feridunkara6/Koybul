import 'package:shared_preferences/shared_preferences.dart';

import '../application/route_quota_controller.dart' show RouteQuotaStore;

/// GÜNLÜK ROTA SAYACI deposu (P4b, premium v3 raporu K3 — günde 3 rota).
///
/// Cihazda yalnız iki değer tutulur: gün anahtarı (yerel 'yyyy-aa-gg') ve o
/// gün üretilen rota sayısı. Gün değişince sayaç kendiliğinden sıfır sayılır.
/// Depo her ortamda olmayabilir (testler) — her erişim try/catch; olmazsa
/// sayaç oturum içi hafızada yaşar, kullanıcı asla hatayla karşılaşmaz.
class SharedPrefsRouteQuotaStore implements RouteQuotaStore {
  const SharedPrefsRouteQuotaStore();

  static const String _kDay = 'route.quota.day';
  static const String _kUsed = 'route.quota.used';

  @override
  Future<(String, int)?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? day = prefs.getString(_kDay);
      final int? used = prefs.getInt(_kUsed);
      if (day == null || used == null || used < 0) return null;
      return (day, used);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String dayKey, int used) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDay, dayKey);
      await prefs.setInt(_kUsed, used);
    } catch (_) {
      // en iyi çaba — sessizce geç
    }
  }
}
