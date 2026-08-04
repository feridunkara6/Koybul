import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_store.dart';

/// `OnboardingStore`'un `shared_preferences` uygulaması. Hata durumunda
/// `load` NULL döner → tanıtım gösterilmez (en iyi çaba; asla fırlatmaz).
class SharedPrefsOnboardingStore implements OnboardingStore {
  const SharedPrefsOnboardingStore();

  static const String _kWelcome = 'onb.v1.welcome_done';
  static const String _kHints = 'onb.v1.seen_hints';

  @override
  Future<OnboardingData?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return OnboardingData(
        welcomeDone: prefs.getBool(_kWelcome) ?? false,
        seenHints:
            (prefs.getStringList(_kHints) ?? const <String>[]).toSet(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(OnboardingData data) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kWelcome, data.welcomeDone);
      await prefs.setStringList(
          _kHints, data.seenHints.toList(growable: false));
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }
}
