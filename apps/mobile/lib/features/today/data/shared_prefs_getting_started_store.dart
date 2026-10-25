import 'package:shared_preferences/shared_preferences.dart';

import '../domain/getting_started_store.dart';

/// `GettingStartedStore`'un `shared_preferences` uygulaması (en iyi çaba —
/// kontrol listesi deposuyla aynı sözleşme: asla fırlatmaz).
class SharedPrefsGettingStartedStore implements GettingStartedStore {
  const SharedPrefsGettingStartedStore();

  static const String _key = 'gettingstarted.v1.dismissed';

  @override
  Future<bool> loadDismissed() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      // Depo bozuksa "kapatıldı" varsayılamaz — kart görünür kalır
      // (yeni kullanıcı rehbersiz kalmasın; nag'den kötü değildir).
      return false;
    }
  }

  @override
  Future<void> saveDismissed() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // sessizce geç
    }
  }
}
