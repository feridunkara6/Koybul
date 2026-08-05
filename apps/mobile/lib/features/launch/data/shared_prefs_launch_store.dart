import 'package:shared_preferences/shared_preferences.dart';

import '../domain/launch_store.dart';

/// [LaunchStore]'un `shared_preferences` uygulaması. Anahtar uzayı `onb.v2.*`
/// (onaylı tasarım dokümanı) — mevcut tur/ipucu anahtarlarına (`onb.v1.*`)
/// dokunmaz; iki sistem bağımsız yaşar.
///
/// DİKKAT: hata durumunda [isDone] TRUE döner — bozuk depoda kullanıcı her
/// açılışta karşılama ekranına hapsolmasın (WelcomeStore ile aynı ilke).
class SharedPrefsLaunchStore implements LaunchStore {
  const SharedPrefsLaunchStore();

  static const String _doneKey = 'onb.v2.launchDone';

  @override
  Future<bool> isDone() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_doneKey) ?? false;
    } catch (_) {
      return true; // en iyi çaba: bozuk depoda karşılamaya hapsetme
    }
  }

  @override
  Future<void> markDone() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_doneKey, true);
    } catch (_) {
      // sessizce geç — bir sonraki açılışta en kötü ihtimalle tekrar sorulur
    }
  }
}
