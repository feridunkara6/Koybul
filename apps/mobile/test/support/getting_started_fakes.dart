import 'package:dockly_mobile/features/today/domain/getting_started_store.dart';

/// Bellek içi başlangıç görevleri deposu (depo kuralı docs/15: testte
/// gerçek SharedPreferences ASLA kullanılmaz).
class FakeGettingStartedStore implements GettingStartedStore {
  FakeGettingStartedStore({this.dismissed = false});

  bool dismissed;
  int saveCount = 0;

  @override
  Future<bool> loadDismissed() async => dismissed;

  @override
  Future<void> saveDismissed() async {
    dismissed = true;
    saveCount++;
  }
}
