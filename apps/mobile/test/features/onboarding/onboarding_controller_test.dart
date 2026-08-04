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

/// TANITIM BEYNİ testleri: karşılama/tur akışı ve ipucu kalıcılığı.
void main() {
  test('depo yok/bozuk (null) → hazır DEĞİL: hiçbir tanıtım öğesi çıkmaz', () async {
    final ProviderContainer c = _container(FakeOnboardingStore()); // data null
    c.read(onboardingControllerProvider); // yüklemeyi tetikle
    await Future<void>.delayed(Duration.zero);
    final OnboardingState s = _state(c);
    expect(s.ready, isFalse);
    expect(s.showWelcome, isFalse);
    expect(s.showHint(kHintBottomCard), isFalse);
  });

  test('ilk açılış → karşılama görünür; "Şimdi değil" kalıcı kapatır', () async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    final ProviderContainer c = _container(store);
    c.read(onboardingControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(_state(c).showWelcome, isTrue);

    _ctrl(c).dismissWelcome();
    expect(_state(c).showWelcome, isFalse);
    expect(_state(c).tourActive, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(store.saveCount, 1);
    expect(store.data!.welcomeDone, isTrue); // bir daha sorulmaz
  });

  test('tur akışı: başlat → 6 adım → biter; Atla her an kapatır', () async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    final ProviderContainer c = _container(store);
    c.read(onboardingControllerProvider);
    await Future<void>.delayed(Duration.zero);

    _ctrl(c).startTour();
    expect(_state(c).tourStep, 0);
    expect(_state(c).showWelcome, isFalse); // karşılama kararı verildi
    for (int i = 1; i < kTourStepCount; i++) {
      _ctrl(c).nextStep();
      expect(_state(c).tourStep, i);
    }
    _ctrl(c).nextStep(); // son adımda "Bitti"
    expect(_state(c).tourActive, isFalse);

    // Atla: yeniden başlat, ortada bırak.
    _ctrl(c).replayTour();
    _ctrl(c).nextStep();
    expect(_state(c).tourStep, 1);
    _ctrl(c).skipTour();
    expect(_state(c).tourActive, isFalse);
  });

  test('ipucu: bir kez gösterilir, cihaza işlenir; tur açıkken gösterilmez', () async {
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

    // Tur açıkken diğer ipuçları da susar (ekran kalabalığı olmasın).
    _ctrl(c).replayTour();
    expect(_state(c).showHint(kHintCoords), isFalse);
  });
}
