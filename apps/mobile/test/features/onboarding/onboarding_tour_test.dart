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

/// TANITIM KARTLARI v2 ekran testleri (kullanıcı isteği 2026-08): kartlar ilk
/// açılışta KENDİLİĞİNDEN başlar, EKRANA dokundukça ilerler, Atla kapatır.
void main() {
  testWidgets('İLK açılış: kart 1 kendiliğinden görünür; ekrana dokununca kart 2',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsOneWidget);
    // Kart 1 sadeleşti (Paket 3): karşılama işini açılış akışı (E2) yapıyor.
    expect(find.text('Harita hazır, kaptan'), findsOneWidget);
    expect(store.data!.welcomeDone, isTrue); // karar anında işlendi

    // EKRANIN HERHANGİ BİR YERİNE dokun → sonraki kart.
    await tester.tapAt(const Offset(40, 560));
    await tester.pumpAndSettle();
    expect(find.text('Harita ve koylar'), findsOneWidget);

    // Kartın kendisine dokunmak da ilerletir.
    await tester.tap(find.text('Harita ve koylar'));
    await tester.pumpAndSettle();
    expect(find.text('Filtreler'), findsOneWidget);
  });

  testWidgets('Atla: kartlar kapanır ve bir daha kendiliğinden açılmaz',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsNothing);
    expect(store.data!.welcomeDone, isTrue);
  });

  testWidgets('7 dokunuşta tanıtım biter; son kartta rota düzenleme anlatılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _app(FakeOnboardingStore(data: const OnboardingData())));
    await tester.pumpAndSettle();

    for (int i = 0; i < kTourStepCount - 1; i++) {
      await tester.tapAt(const Offset(40, 560));
      await tester.pumpAndSettle();
    }
    // Son kart: rota düzenleme + kaydetme anlatımı (kullanıcı isteği).
    expect(find.text('Rotanı düzenle ve kaydet'), findsOneWidget);
    expect(find.text('Başlamak için ekrana dokun'), findsOneWidget);
    await tester.tapAt(const Offset(40, 560));
    await tester.pumpAndSettle();
    expect(find.text('Rotanı düzenle ve kaydet'), findsNothing);
  });

  testWidgets('İPUCU: ilk pin dokunuşunda koy kartı balonu; "Anladım" bir daha göstermez',
      (WidgetTester tester) async {
    final FakeOnboardingStore store = FakeOnboardingStore(
        data: const OnboardingData(welcomeDone: true)); // kartlar kapalı
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsOneWidget);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
    expect(store.data!.seenHints, contains(kHintBottomCard)); // kalıcı

    // Kartı kapatıp yeniden aç — balon geri gelmez.
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
  });

  testWidgets('tanıtım görülmüşse hiçbir kaplama çıkmaz (mevcut akış bozulmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(doneOnboardingStore()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsNothing);
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
  });
}
