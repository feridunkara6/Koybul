import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/onboarding/domain/onboarding_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/onboarding_fakes.dart';

ProviderContainer _container(FakeOnboardingStore store) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      onboardingStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

OnboardingController _ctrl(ProviderContainer c) =>
    c.read(onboardingControllerProvider.notifier);

OnboardingState _state(ProviderContainer c) =>
    c.read(onboardingControllerProvider);

/// TANITIM BEYNİ v2 testleri (kullanıcı isteği 2026-08): kartlar ilk açılışta
/// KENDİLİĞİNDEN başlar, dokundukça ilerler; karar anında cihaza işlenir.
void main() {
  test('depo yok/bozuk (null) → hazır DEĞİL: hiçbir tanıtım öğesi çıkmaz', () async {
    final ProviderContainer c = _container(FakeOnboardingStore()); // data null
    c.read(onboardingControllerProvider); // yüklemeyi tetikle
    await Future<void>.delayed(Duration.zero);
    final OnboardingState s = _state(c);
    expect(s.ready, isFalse);
    expect(s.tourActive, isFalse);
    expect(s.showHint(kHintBottomCard), isFalse);
  });

  test('İLK AÇILIŞ: kartlar otomatik başlar; karar ANINDA cihaza işlenir '
      '(yarıda kapansa bile bir daha kendiliğinden açılmaz)', () async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    final ProviderContainer c = _container(store);
    c.read(onboardingControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final OnboardingState s = _state(c);
    expect(s.ready, isTrue);
    expect(s.tourStep, 0); // kartlar kendiliğinden açıldı
    expect(store.saveCount, 1);
    expect(store.data!.welcomeDone, isTrue); // kalıcı karar
  });

  test('İKİNCİ açılış: kartlar kendiliğinden AÇILMAZ', () async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData(welcomeDone: true));
    final ProviderContainer c = _container(store);
    c.read(onboardingControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(_state(c).ready, isTrue);
    expect(_state(c).tourActive, isFalse);
  });

  test('dokunuş akışı: 7 kartta biter; Atla her an kapatır; Profil yeniden açar', () async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    final ProviderContainer c = _container(store);
    c.read(onboardingControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(_state(c).tourStep, 0);

    for (int i = 1; i < kTourStepCount; i++) {
      _ctrl(c).nextStep(); // ekrana dokunuş
      expect(_state(c).tourStep, i);
    }
    _ctrl(c).nextStep(); // son kartta dokunuş → biter
    expect(_state(c).tourActive, isFalse);

    // Profil → yeniden izle; Atla ortada kapatır.
    _ctrl(c).replayTour();
    expect(_state(c).tourStep, 0);
    _ctrl(c).nextStep();
    _ctrl(c).skipTour();
    expect(_state(c).tourActive, isFalse);
  });

  test('ipucu: bir kez gösterilir, cihaza işlenir; kartlar açıkken gösterilmez', () async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData(welcomeDone: true));
    final ProviderContainer c = _container(store);
    c.read(onboardingControllerProvider);
    await Future<void>.delayed(Duration.zero);

    expect(_state(c).showHint(kHintBottomCard), isTrue);
    _ctrl(c).markHintSeen(kHintBottomCard);
    expect(_state(c).showHint(kHintBottomCard), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(store.data!.seenHints, contains(kHintBottomCard));

    // Kartlar açıkken diğer ipuçları susar (ekran kalabalığı olmasın).
    _ctrl(c).replayTour();
    expect(_state(c).showHint(kHintCoords), isFalse);
  });
}
