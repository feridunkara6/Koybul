import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/emergency/presentation/emergency_screen.dart';
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/presentation/map_screen.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/search/application/search_controller.dart';
import 'package:dockly_mobile/features/search/presentation/search_screen.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/checklist_fakes.dart';
import '../../support/fake_map_surface.dart';
import '../../support/location_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/search_fakes.dart';
import '../../support/trip_fakes.dart';
import '../../support/weather_fakes.dart';

/// HARİTA YERLEŞİMİ — UX denetimi P0-2 (kullanıcı onayı 2026-08).
///
/// Onaylı hiyerarşi: ARAMA HAPI üstte tam genişlik; "ROTA PLANLA" etiketli
/// FAB sağ altta; SOS sol altta YALNIZ (ayrıksılık = bulunurluk); sağ
/// kolonda yalnız ikincil araçlar (Konumum + liste). İşlevler birebir aynı —
/// bu testler yerleşimi ve davranış eşitliğini birlikte kilitler.
Widget _app() {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider
          .overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
      tripStoreProvider.overrideWithValue(FakeTripStore()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      onboardingStoreProvider.overrideWithValue(doneOnboardingStore()),
      searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
      searchDebounceProvider.overrideWithValue(Duration.zero),
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

void main() {
  testWidgets('P0-2: arama hapı üstte durur, dokununca arama sayfası açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final Finder pill = find.byKey(const ValueKey<String>('map-search-pill'));
    expect(pill, findsOneWidget);
    // Hap ekranın ÜST yarısında (arama artık sağ kolon ikonu değil).
    expect(tester.getCenter(pill).dy, lessThan(150));
    expect(find.text('Liman, koy, şehir ara'), findsOneWidget);

    await tester.tap(pill);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    // Normal arama kipi — hedef seçme kipi DEĞİL.
    expect(find.text('Nereye gitmek istiyorsun?'), findsNothing);
  });

  testWidgets('P0-2: "Rota planla" FAB sağ altta, SOS sol altta YALNIZ',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // FAB etiketiyle var ve rota anahtarını koruyor (davranış eşitliği).
    final Finder fab = find.byKey(const ValueKey<String>('map-route-start'));
    expect(fab, findsOneWidget);
    expect(find.text('Rota planla'), findsOneWidget);

    final Finder sos = find.text('SOS');
    expect(sos, findsOneWidget);

    final Size screen = tester.getSize(find.byType(MapScreen));
    final Offset sosC = tester.getCenter(sos);
    final Offset fabC = tester.getCenter(fab);
    // İkisi de ALT bantta…
    expect(sosC.dy, greaterThan(screen.height / 2));
    expect(fabC.dy, greaterThan(screen.height / 2));
    // …SOS solda, FAB sağda (panik butonu yalnız ve ayrıksı).
    expect(sosC.dx, lessThan(screen.width / 3));
    expect(fabC.dx, greaterThan(screen.width * 2 / 3));
  });

  testWidgets('P0-2: SOS davranışı AYNEN — tek dokunuş Acil Durum sayfası',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyScreen), findsOneWidget);
  });

  testWidgets('P0-2: sağ kolonda yalnız İKİNCİL araçlar kaldı '
      '(Konumum + liste; arama/rota ikonları kolonda değil)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Konumum düğmesi duruyor (tooltip'iyle bulunur).
    expect(find.byTooltip('Konumum'), findsOneWidget);
    // Eski kolon arama ikonu kalktı: arama girişi artık tek — üstteki hap.
    expect(find.byTooltip('Arama'), findsNothing);
  });
}
