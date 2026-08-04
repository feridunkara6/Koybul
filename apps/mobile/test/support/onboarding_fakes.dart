import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/onboarding/domain/onboarding_store.dart';

/// Testte `OnboardingStore` yerine geçen sahte (bellek içi).
class FakeOnboardingStore implements OnboardingStore {
  FakeOnboardingStore({this.data});

  OnboardingData? data;
  int saveCount = 0;

  @override
  Future<OnboardingData?> load() async => data;

  @override
  Future<void> save(OnboardingData d) async {
    saveCount++;
    data = d;
  }
}

/// Tanıtımı TAMAMEN görmüş depo — tanıtım konusu olmayan ekran testleri
/// karşılama/tur/ipucu görmesin (determinizm).
FakeOnboardingStore doneOnboardingStore() => FakeOnboardingStore(
      data: const OnboardingData(
        welcomeDone: true,
        seenHints: <String>{kHintBottomCard, kHintCoords},
      ),
    );
