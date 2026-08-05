import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/application/sea_route_engine.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:dockly_mobile/features/route/presentation/saved_routes_screen.dart';
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/location_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/saved_routes_fakes.dart';
import '../../support/weather_fakes.dart';

/// Sabit plan döndüren sahte motor (kart testi için yeterli).
class _FakeRouteEngine implements SeaRouteEngine {
  int calls = 0;

  @override
  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async {
    calls++;
    return const SeaRoutePlan(
      points: <GeoPoint>[
        GeoPoint(lat: 36.76, lon: 28.96),
        GeoPoint(lat: 36.75, lon: 28.93),
      ],
      distanceNm: 12,
      reachedGoal: true,
      viaSea: true,
    );
  }

  @override
  Future<SeaTrip?> trip(GeoPoint from, List<GeoPoint> stops) async {
    final SeaRoutePlan? leg = await route(from, stops.last);
    if (leg == null) return null;
    return SeaTrip(
      legs: <SeaRoutePlan>[leg],
      combined: combineTripLegs(<SeaRoutePlan>[leg]),
    );
  }

  @override
  Future<GeoPoint?> snapWater(GeoPoint p) async => p;
}

const SavedRoute _deviceRoute = SavedRoute(
  id: 'r1',
  name: 'Eve dönüş',
  origin: RouteOrigin(pos: GeoPoint(lat: 0, lon: 0), isDevice: true),
  waypoints: <RouteWaypoint>[
    RouteWaypoint(
        pos: GeoPoint(lat: 36.75, lon: 28.93), id: 'loc-1', name: 'Göcek'),
  ],
  distanceNm: 12,
  savedAtMs: 1000,
);

/// KAYITLI ROTA KARTI testleri (kullanıcı isteği 2026-08): kartın TAMAMI
/// tıklanır; "Konumum" başlangıçlı kayıtta izin akışı OTOMATİK başlar ve
/// onay gelince rota kullanıcı verdiği İSİMLE kurulur.
void main() {
  testWidgets('karta dokun: konum izni otomatik istenir, rota İSMİYLE kurulur, '
      'Keşfet sekmesine dönülür', (WidgetTester tester) async {
    final FakeLocationService location =
        FakeLocationService(const GeoPoint(lat: 36.76, lon: 28.96));
    final _FakeRouteEngine engine = _FakeRouteEngine();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        locationServiceProvider.overrideWithValue(location),
        seaRouteEngineProvider.overrideWithValue(engine),
        mapLocationsGatewayProvider
            .overrideWithValue(FakeMapGateway(result: pinResult)),
        mapDebounceProvider.overrideWithValue(Duration.zero),
        mapCacheProvider.overrideWithValue(FakeMapCache()),
        savedRoutesStoreProvider.overrideWithValue(FakeSavedRoutesStore()),
        // Rüzgâr analizi ağa çıkmasın (rota kurulunca tetiklenir).
        weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SavedRouteCard(route: _deviceRoute)),
      ),
    ));
    await tester.pumpAndSettle();

    // Kartın tamamına dokun (düğme değil — kullanıcı isteği).
    await tester.tap(find.byKey(const ValueKey<String>('saved-route-r1')));
    await tester.pumpAndSettle();

    expect(location.calls, 1); // izin akışı otomatik tetiklendi
    final ProviderContainer c = ProviderScope.containerOf(
        tester.element(find.byType(SavedRouteCard)));
    expect(c.read(mapControllerProvider).route, isNotNull); // rota kuruldu
    expect(c.read(mapControllerProvider).routeLabel, 'Eve dönüş'); // ismiyle
    expect(c.read(shellTabProvider), 0); // Keşfet'e dönüldü
  });

  testWidgets('izin REDDEDİLİRSE dürüst uyarı çıkar, rota kurulmaz', (
    WidgetTester tester,
  ) async {
    final _FakeRouteEngine engine = _FakeRouteEngine();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        locationServiceProvider.overrideWithValue(FakeLocationService(null)),
        seaRouteEngineProvider.overrideWithValue(engine),
        mapLocationsGatewayProvider
            .overrideWithValue(FakeMapGateway(result: pinResult)),
        mapDebounceProvider.overrideWithValue(Duration.zero),
        mapCacheProvider.overrideWithValue(FakeMapCache()),
        savedRoutesStoreProvider.overrideWithValue(FakeSavedRoutesStore()),
        // Rüzgâr analizi ağa çıkmasın (rota kurulunca tetiklenir).
        weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SavedRouteCard(route: _deviceRoute)),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('saved-route-r1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('önce konumunu paylaşmalısın'), findsOneWidget);
    final ProviderContainer c = ProviderScope.containerOf(
        tester.element(find.byType(SavedRouteCard)));
    expect(c.read(mapControllerProvider).route, isNull);
    // Snackbar zamanlayıcısını akıt (CI dersi).
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });
}
