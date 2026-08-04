import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/presentation/map_screen.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/onboarding/domain/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_map_surface.dart';
import '../../support/map_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/onboarding_fakes.dart';

Widget _app(FakeOnboardingStore store) {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      onboardingStoreProvider.overrideWithValue(store),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

const ValueKey<String> _pinKey = ValueKey<String>('pin-loc-1');

/// YENİ KULLANICI TANITIMI ekran testleri: karşılama kartı, spot ışıklı tur
/// ve ilk pin dokunuşundaki koy kartı ipucu.
void main() {
  testWidgets('İLK açılış: karşılama kartı çıkar; "Şimdi değil" kalıcı kapatır',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('onb-welcome')), findsOneWidget);
    expect(find.text("Koybul'a hoş geldin, kaptan"), findsOneWidget);

    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-welcome')), findsNothing);
    expect(store.data!.welcomeDone, isTrue); // cihaza işlendi
  });

  testWidgets('TUR: başlat → adımlar ilerler, spot balonları doğru metni taşır, Atla kapatır',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turu başlat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsOneWidget);
    expect(find.text('Harita ve koylar'), findsOneWidget);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(find.text('Filtreler'), findsOneWidget);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-tour-step-1')), findsNothing);
    // Tur kapandı; karşılama da geri gelmez (karar verilmişti).
    expect(find.byKey(const ValueKey<String>('onb-welcome')), findsNothing);
  });

  testWidgets('TUR: son adımda "Bitti" görünür ve turu bitirir',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turu başlat'));
    await tester.pumpAndSettle();

    for (int i = 0; i < kTourStepCount - 1; i++) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Koy kartı'), findsOneWidget); // son adım başlığı
    expect(find.text('Bitti'), findsOneWidget);
    await tester.tap(find.text('Bitti'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koy kartı'), findsNothing);
  });

  testWidgets('İPUCU: ilk pin dokunuşunda koy kartı balonu; "Anladım" bir daha göstermez',
      (WidgetTester tester) async {
    final FakeOnboardingStore store = FakeOnboardingStore(
        data: const OnboardingData(welcomeDone: true)); // karşılama geçilmiş
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsOneWidget);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
    expect(store.data!.seenHints, contains(kHintBottomCard)); // kalıcı

    // Kartı kapatıp yeniden aç — balon geri gelmez.
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
  });

  testWidgets('tanıtım görülmüşse hiçbir kaplama çıkmaz (mevcut akış bozulmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(doneOnboardingStore()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-welcome')), findsNothing);
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
  });
}
