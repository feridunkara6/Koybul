import 'package:dockly_api/dockly_api.dart'
    show GeoPoint, SharedRouteDetail, SharedRouteStop, SharedRouteSummary;
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_state.dart' show MapState;
import 'package:dockly_mobile/features/premium/application/premium_controller.dart';
import 'package:dockly_mobile/features/route/application/route_quota_controller.dart';
import 'package:dockly_mobile/features/route/application/sea_route_engine.dart';
import 'package:dockly_mobile/features/route/application/shared_routes_controller.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:dockly_mobile/features/route/domain/shared_routes_gateway.dart';
import 'package:dockly_mobile/features/route/presentation/routes_through_section.dart';
import 'package:dockly_mobile/features/route/presentation/share_route_sheet.dart';
import 'package:dockly_mobile/features/route/presentation/shared_route_detail_screen.dart';
import 'package:dockly_mobile/features/route/presentation/shared_routes_screen.dart';
import 'package:dockly_mobile/features/today/presentation/today_pulse_cards.dart'
    show TodayCommunityHeader, TodayRouteCard;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/map_fakes.dart';

/// ROTA PAYLAŞIMI mobil testleri (Hafta 3, kurucu onayı 2026-10-24).
/// Kural (docs/15): ağ yok — ağ geçidi sahtedir.

SharedRouteSummary summary(
        {String id = 'r1', int saveCount = 23, String status = 'approved'}) =>
    SharedRouteSummary(
      id: id,
      status: status,
      name: '12 Adalar klasiği',
      authorId: 'u-author',
      authorName: 'Meltem Y.',
      startName: 'Göcek',
      endName: 'Bedri Rahmi',
      stopCount: 4,
      distanceNm: 14,
      durationHours: 4,
      season: 'Nisan-Ekim',
      saveCount: saveCount,
      doneCount: 4,
      createdAt: DateTime.utc(2026, 10, 20, 8),
    );

SharedRouteDetail routeDetail({bool savedByMe = false}) => SharedRouteDetail(
      summary: summary(),
      body: 'Öğlen meltemi güçlenmeden Yassıca molasını verin; '
          'Tersane girişindeki şamandıralara dikkat.',
      boatSuggestion: 'Her tür · günübirlik',
      status: 'approved',
      stops: const <SharedRouteStop>[
        SharedRouteStop(
            seq: 1,
            locationId: 'loc-gocek',
            name: 'Göcek',
            typeCode: 'private_marina'),
        SharedRouteStop(
            seq: 2,
            locationId: 'loc-yassica',
            name: 'Yassıca Adaları',
            typeCode: 'mooring_point'),
      ],
      mine: false,
      savedByMe: savedByMe,
      doneByMe: false,
    );

/// Koordinatlı detay — "Haritada aç" testleri (saha hatası 2026-10-26).
/// Göcek açığı → güneyi: sea_mask'e karşı doğrulanmış su noktaları
/// (tur örnek rotasıyla aynı bölge — sahte motorda fark etmez).
SharedRouteDetail routeDetailWithCoords() => SharedRouteDetail(
      summary: summary(),
      body: 'Öğlen meltemi güçlenmeden Yassıca molasını verin; '
          'Tersane girişindeki şamandıralara dikkat.',
      boatSuggestion: 'Her tür · günübirlik',
      status: 'approved',
      stops: const <SharedRouteStop>[
        SharedRouteStop(
            seq: 1,
            locationId: 'loc-gocek',
            name: 'Göcek',
            typeCode: 'private_marina',
            lat: 36.740,
            lon: 28.935),
        SharedRouteStop(
            seq: 2,
            locationId: 'loc-yassica',
            name: 'Yassıca Adaları',
            typeCode: 'mooring_point',
            lat: 36.660,
            lon: 28.900),
      ],
      mine: false,
      savedByMe: false,
      doneByMe: false,
    );

/// Sahte deniz motoru: iki noktayı dolaysız bağlar (tur testiyle aynı).
class _FakeRouteEngine implements SeaRouteEngine {
  @override
  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async =>
      SeaRoutePlan(
        points: <GeoPoint>[from, to],
        distanceNm: 5,
        reachedGoal: true,
        viaSea: true,
      );

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

class FakeSharedRoutesGateway implements SharedRoutesGateway {
  FakeSharedRoutesGateway({this.feedResult = const <SharedRouteSummary>[]});

  List<SharedRouteSummary> feedResult;
  final List<String> feedSorts = <String>[];
  final List<Map<String, Object?>> shares = <Map<String, Object?>>[];
  int saveToggles = 0;
  int doneToggles = 0;

  final List<String?> feedLocationIds = <String?>[];

  @override
  Future<List<SharedRouteSummary>> feed(
      {required String sort, String? locationId}) async {
    feedSorts.add(sort);
    feedLocationIds.add(locationId);
    return feedResult;
  }

  SharedRouteDetail detailResult = routeDetail();

  @override
  Future<SharedRouteDetail> detail(String routeId) async => detailResult;

  @override
  Future<({String id, String status})> share({
    required String name,
    required String body,
    String? season,
    String? boatSuggestion,
    required double distanceNm,
    double? durationHours,
    required List<String> stopLocationIds,
  }) async {
    shares.add(<String, Object?>{
      'name': name,
      'body': body,
      'season': season,
      'distanceNm': distanceNm,
      'stops': stopLocationIds,
    });
    return (id: 'r-new', status: 'pending');
  }

  @override
  Future<({bool saved, int saveCount})> toggleSave(String routeId) async {
    saveToggles++;
    return (saved: true, saveCount: 24);
  }

  @override
  Future<({bool done, int doneCount})> toggleDone(String routeId) async {
    doneToggles++;
    return (done: true, doneCount: 5);
  }
}

Widget _app(FakeSharedRoutesGateway gw, Widget home,
    {List<Override> extra = const <Override>[]}) {
  return ProviderScope(
    overrides: <Override>[
      sharedRoutesGatewayProvider.overrideWithValue(gw),
      ...extra,
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  group('shareableStopIds (saf kural)', () {
    SavedRoute route(List<RouteWaypoint> wps) => SavedRoute(
          id: 's1',
          name: 'Test rotası',
          origin: const RouteOrigin(
              pos: GeoPoint(lat: 36.75, lon: 28.94), name: 'Göcek'),
          waypoints: wps,
          distanceNm: 14,
          savedAtMs: 0,
        );

    test('kimliksiz (serbest) noktalar paylaşılmaz; ardışık tekrar ayıklanır', () {
      final ids = shareableStopIds(route(const <RouteWaypoint>[
        RouteWaypoint(pos: GeoPoint(lat: 36.7, lon: 28.9), id: 'a', name: 'A'),
        RouteWaypoint(pos: GeoPoint(lat: 36.8, lon: 28.8)), // serbest nokta
        RouteWaypoint(pos: GeoPoint(lat: 36.9, lon: 28.7), id: 'a', name: 'A'),
        RouteWaypoint(pos: GeoPoint(lat: 36.9, lon: 28.6), id: 'b', name: 'B'),
      ]));
      // Serbest nokta düşer; a,a ardışıklaşır ve teke iner → [a, b].
      expect(ids, <String>['a', 'b']);
    });
  });

  testWidgets('Keşif: kartlar çizilir; sıralama çipi yeni akış ister',
      (WidgetTester tester) async {
    final gw = FakeSharedRoutesGateway(
        feedResult: <SharedRouteSummary>[summary()]);
    await tester.pumpWidget(_app(gw, const SharedRoutesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('12 Adalar klasiği'), findsOneWidget);
    expect(find.textContaining('Göcek → Bedri Rahmi'), findsOneWidget);
    expect(gw.feedSorts, <String>['new']);

    await tester.tap(find.byKey(const ValueKey<String>('rt-sort-popular')));
    await tester.pumpAndSettle();
    expect(gw.feedSorts, contains('popular'));
  });

  testWidgets('Keşif: boş akışta davet metni görünür', (tester) async {
    final gw = FakeSharedRoutesGateway();
    await tester.pumpWidget(_app(gw, const SharedRoutesScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('ilk rotayı sen paylaş'), findsOneWidget);
  });

  testWidgets('Detay: duraklar + notlar + beyan kutusu; MİSAFİR kaydedemez',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final gw = FakeSharedRoutesGateway();
    await tester.pumpWidget(
        _app(gw, const SharedRouteDetailScreen(routeId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('rtd-name')), findsOneWidget);
    expect(find.text('Yassıca Adaları'), findsOneWidget);
    expect(find.textContaining('şamandıralara dikkat'), findsOneWidget);
    expect(find.textContaining('beyan'), findsOneWidget); // dürüstlük kutusu

    await tester.tap(find.byKey(const ValueKey<String>('rtd-save')));
    await tester.pumpAndSettle();
    // Misafir: geçide istek GİTMEZ, kibar not çıkar.
    expect(gw.saveToggles, 0);
    expect(find.textContaining('giriş yapmalısın'), findsOneWidget);
  });

  testWidgets('Detay: hesaplı kullanıcı kaydeder ve yaptım işaretler',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final gw = FakeSharedRoutesGateway();
    await tester.pumpWidget(_app(
        gw, const SharedRouteDetailScreen(routeId: 'r1'),
        extra: <Override>[signedInAuthOverride()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('rtd-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('rtd-done')));
    await tester.pumpAndSettle();
    expect(gw.saveToggles, 1);
    expect(gw.doneToggles, 1);
  });

  testWidgets('HAFTA 4 — Bugün: rota köprüsü en yeni rotayı gösterir; '
      'başlıktaki tümü Rota Keşfini açar', (WidgetTester tester) async {
    final gw =
        FakeSharedRoutesGateway(feedResult: <SharedRouteSummary>[summary()]);
    await tester.pumpWidget(_app(
      gw,
      const Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[TodayCommunityHeader(), TodayRouteCard()],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Çevrende olanlar'.toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('today-route')), findsOneWidget);
    expect(find.text('12 Adalar klasiği'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('today-community-all')));
    await tester.pumpAndSettle();
    expect(find.byType(SharedRoutesScreen), findsOneWidget);
  });

  testWidgets('HAFTA 4 — Bugün: akış boşken rota köprüsü kendini çizmez',
      (WidgetTester tester) async {
    final gw = FakeSharedRoutesGateway();
    await tester.pumpWidget(
        _app(gw, const Scaffold(body: TodayRouteCard())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('today-route')), findsNothing);
  });

  testWidgets('HAFTA 4 — koy köprüsü: rotalar duraktan süzülür; boşsa bölüm yok',
      (WidgetTester tester) async {
    final gw =
        FakeSharedRoutesGateway(feedResult: <SharedRouteSummary>[summary()]);
    await tester.pumpWidget(_app(
        gw,
        const Scaffold(
            body: SingleChildScrollView(
                child: RoutesThroughSection(locationId: 'loc-gocek')))));
    await tester.pumpAndSettle();

    expect(find.text('Buradan geçen rotalar'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('rt-through-r1')), findsOneWidget);
    // Süzgeç geçide duraktan gitti (sunucu süzer — istemci süzmez).
    expect(gw.feedLocationIds, contains('loc-gocek'));

    final bos = FakeSharedRoutesGateway();
    await tester.pumpWidget(_app(
        bos,
        const Scaffold(
            body: SingleChildScrollView(
                child: RoutesThroughSection(locationId: 'loc-bos')))));
    await tester.pumpAndSettle();
    expect(find.text('Buradan geçen rotalar'), findsNothing);
  });

  testWidgets('Paylaşım: kısa deneyim metni gönderilmez; geçerli form gider',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final gw = FakeSharedRoutesGateway();
    const SavedRoute route = SavedRoute(
      id: 's1',
      name: 'Göcek → Bedri Rahmi',
      origin:
          RouteOrigin(pos: GeoPoint(lat: 36.75, lon: 28.94), name: 'Göcek'),
      waypoints: <RouteWaypoint>[
        RouteWaypoint(
            pos: GeoPoint(lat: 36.7, lon: 28.9), id: 'loc-a', name: 'Yassıca'),
        RouteWaypoint(
            pos: GeoPoint(lat: 36.6, lon: 28.8), id: 'loc-b', name: 'Bedri'),
      ],
      distanceNm: 14,
      savedAtMs: 0,
    );
    await tester.pumpWidget(_app(
      gw,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              key: const ValueKey<String>('open-share'),
              onPressed: () => openShareRouteSheet(context, route),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
      extra: <Override>[signedInAuthOverride()],
    ));
    await tester.tap(find.byKey(const ValueKey<String>('open-share')));
    await tester.pumpAndSettle();

    // Kısa gövde → gönderilmez, uyarı çıkar.
    await tester.enterText(
        find.byKey(const ValueKey<String>('rts-body')), 'kısa');
    await tester.tap(find.byKey(const ValueKey<String>('rts-send')));
    await tester.pumpAndSettle();
    expect(gw.shares, isEmpty);
    expect(find.textContaining('en az 30 karakter'), findsOneWidget);

    // Geçerli gövde → geçide tam sözleşmeyle gider ve sayfa kapanır.
    await tester.enterText(find.byKey(const ValueKey<String>('rts-body')),
        'Öğlen meltemi güçlenmeden Yassıca molasını verin, dönüş erken.');
    await tester.tap(find.byKey(const ValueKey<String>('rts-send')));
    await tester.pumpAndSettle();
    expect(gw.shares, hasLength(1));
    expect(gw.shares.single['stops'], <String>['loc-a', 'loc-b']);
    expect(gw.shares.single['distanceNm'], 14.0);
    expect(find.textContaining('moderasyon onayına gönderildi'), findsOneWidget);
  });

  // ─── HARİTADA AÇ (saha hatası 2026-10-26) ───

  testWidgets('rota kartı: koordinat yoksa "Haritada aç" GİZLİ (eski sunucu '
      'uyumu — yarım rota çizilmez)', (WidgetTester tester) async {
    final FakeSharedRoutesGateway gw = FakeSharedRoutesGateway();
    await tester.pumpWidget(
        _app(gw, const SharedRouteDetailScreen(routeId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('rtd-open-map')), findsNothing);
  });

  testWidgets('rota kartı: "Haritada aç" rotayı gerçek motor akışıyla kurar, '
      'adını yazar ve Keşfet sekmesine döner', (WidgetTester tester) async {
    final FakeSharedRoutesGateway gw = FakeSharedRoutesGateway()
      ..detailResult = routeDetailWithCoords();
    await tester.pumpWidget(_app(
      gw,
      const SharedRouteDetailScreen(routeId: 'r1'),
      extra: <Override>[
        // Harita beyni gerçek; motor/ağ/kota sahte (tur testleriyle aynı).
        mapLocationsGatewayProvider
            .overrideWithValue(FakeMapGateway(result: pinResult)),
        mapCacheProvider.overrideWithValue(FakeMapCache()),
        mapDebounceProvider.overrideWithValue(Duration.zero),
        seaRouteEngineProvider.overrideWithValue(_FakeRouteEngine()),
        isPremiumActiveProvider.overrideWithValue(true),
        routeQuotaStoreProvider.overrideWithValue(FakeRouteQuotaStore()),
      ],
    ));
    await tester.pumpAndSettle();

    final Finder btn = find.byKey(const ValueKey<String>('rtd-open-map'));
    expect(btn, findsOneWidget);
    final ProviderContainer c = ProviderScope.containerOf(
      tester.element(find.byType(SharedRouteDetailScreen)),
      listen: false,
    );
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();

    final MapState ms = c.read(mapControllerProvider);
    expect(ms.route, isNotNull); // çizgi gerçek motor akışından geldi
    expect(ms.routeLabel, '12 Adalar klasiği'); // rota adı çipte
    expect(c.read(shellTabProvider), 0); // Keşfet'e dönüldü
  });

  // SAHA İSTEĞİ (2026-10-27, "paylaştım ama görünmüyor"): liste bakanın
  // KENDİ bekleyen rotasını "Onay bekliyor" rozetiyle taşır.
  testWidgets('KENDİ BEKLEYENİM: listede pending rota dürüst rozetle görünür',
      (WidgetTester tester) async {
    final FakeSharedRoutesGateway gw = FakeSharedRoutesGateway(
      feedResult: <SharedRouteSummary>[
        summary(id: 'p1', status: 'pending'),
        summary(id: 'a1'),
      ],
    );
    await tester.pumpWidget(_app(gw, const SharedRoutesScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('rt-pending-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('rt-pending-a1')), findsNothing);
  });
}
