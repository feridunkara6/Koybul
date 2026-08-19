import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_state.dart';
import 'package:dockly_mobile/features/map/presentation/map_screen.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/route/application/sea_route_engine.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
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

/// ROTA GİRİŞİ (Faz 1 — keşfedilebilirlik).
///
/// Denetim bulgusu: rota motoru uygulamanın en ayırt edici parçası ama ilk
/// ekranda hiçbir izi yoktu — ancak "pinler tıklanabilir" bilgisine sahip
/// kullanıcı bulabiliyordu. Artık haritada bir düğme var ve hedefi ADIYLA
/// aratıyor.
class _FakeRouteEngine extends SeaRouteEngine {
  @override
  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async =>
      const SeaRoutePlan(
        points: <GeoPoint>[
          GeoPoint(lat: 36.76, lon: 28.96),
          GeoPoint(lat: 36.75, lon: 28.93),
        ],
        distanceNm: 2,
        reachedGoal: true,
        viaSea: true,
      );

  @override
  Future<GeoPoint?> snapWater(GeoPoint p) async => p;
}

Widget _app(FakeSearchGateway search, {FakeLocationService? location}) {
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
      seaRouteEngineProvider.overrideWithValue(_FakeRouteEngine()),
      searchGatewayProvider.overrideWithValue(search),
      searchDebounceProvider.overrideWithValue(Duration.zero),
      locationServiceProvider.overrideWithValue(
        location ??
            FakeLocationService(const GeoPoint(lat: 36.76, lon: 28.96)),
      ),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

const ValueKey<String> _btn = ValueKey<String>('map-route-start');

void main() {
  testWidgets('rota düğmesi İLK EKRANDA duruyor (pin seçmeye gerek yok)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeSearchGateway()));
    await tester.pumpAndSettle();
    expect(find.byKey(_btn), findsOneWidget);
  });

  testWidgets('hedefi ADIYLA arat → seç → rota çizilir',
      (WidgetTester tester) async {
    final FakeSearchGateway search = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-9', 'Ekincik Koyu')],
    );
    await tester.pumpWidget(_app(search));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_btn));
    await tester.pumpAndSettle();

    // ROTA PLANLAYICI (kurucu isteği 2026-08): önce mod sorulur.
    expect(find.byKey(const ValueKey<String>('plan-from-me')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('plan-two-points')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('plan-from-me')));
    await tester.pumpAndSettle();

    // Seçim kipi: arama ekranı ne istediğini söylüyor.
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Nereye gitmek istiyorsun?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ekincik');
    await tester.pumpAndSettle();
    expect(find.text('Ekincik Koyu'), findsOneWidget);

    await tester.tap(find.text('Ekincik Koyu'));
    await tester.pumpAndSettle();

    // Detay AÇILMADI, haritaya dönüldü ve rota kuruldu.
    expect(find.byType(SearchScreen), findsNothing);
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    expect(c.read(mapControllerProvider).route, isNotNull);
    // Hedef gerçekten SEÇİLEN kayıt (yanlış koya rota çizilmedi).
    final List<RouteWaypoint> wps = c.read(mapControllerProvider).routeWaypoints;
    expect(wps, hasLength(1));
    expect(wps.single.id, 'loc-9');
    expect(wps.single.name, 'Ekincik Koyu');

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('rota çiziliyken düğme gizlenir (bilgi çipi devralır)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeSearchGateway()));
    await tester.pumpAndSettle();
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));

    // routeTo başlangıç için paylaşılmış GPS konumu ister.
    await c.read(locationControllerProvider.notifier).locateMe();
    await tester.pumpAndSettle();
    await c.read(mapControllerProvider.notifier).routeTo(
          const GeoPoint(lat: 36.75, lon: 28.93),
          'loc-1',
          name: 'Göcek',
        );
    await tester.pumpAndSettle();

    expect(c.read(mapControllerProvider).route, isNotNull);
    expect(find.byKey(_btn), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('arama iptal edilirse hiçbir şey olmaz (rota kurulmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeSearchGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_btn));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('plan-from-me')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    // Geri (arama ekranında AppBar geri düğmesi var).
    final NavigatorState nav = tester.state(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();

    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    expect(c.read(mapControllerProvider).route, isNull);
    expect(find.byKey(_btn), findsOneWidget);
  });

  testWidgets('İKİ NOKTA ARASI (A → B, kurucu isteği 2026-08): GPS hiç '
      'istenmez — hedef aranır, başlangıç haritadan seçilir, rota kurulur',
      (WidgetTester tester) async {
    final FakeSearchGateway search = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-9', 'Ekincik Koyu')],
    );
    // Konum servisi BİLEREK "izin yok" döner: A→B akışı GPS'e dokunmadığı
    // için buna rağmen uçtan uca çalışmalıdır.
    await tester.pumpWidget(_app(search, location: FakeLocationService(null)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_btn));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('plan-two-points')));
    await tester.pumpAndSettle();

    // Hedef adıyla aranır ve seçilir.
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ekincik');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekincik Koyu'));
    await tester.pumpAndSettle();

    // Rota HENÜZ yok; BAŞLANGIÇ SEÇ modu açık (haritada şerit).
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    expect(c.read(mapControllerProvider).route, isNull);
    expect(c.read(mapControllerProvider).pickingOrigin, isTrue);

    // Haritaya dokunuş = A noktası (yüzey sahte; kontrolcü yolu birebir).
    await c
        .read(mapControllerProvider.notifier)
        .originPicked(const GeoPoint(lat: 36.80, lon: 28.90));
    await tester.pumpAndSettle();

    // Rota kuruldu: başlangıç GPS DEĞİL, hedef seçilen kayıt.
    final MapState s = c.read(mapControllerProvider);
    expect(s.route, isNotNull);
    expect(s.pickingOrigin, isFalse);
    expect(s.routeOrigin!.isDevice, isFalse);
    expect(s.routeWaypoints.single.id, 'loc-9');

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
