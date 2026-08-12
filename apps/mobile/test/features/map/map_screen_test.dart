import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_cache.dart';
import 'package:dockly_mobile/features/map/presentation/location_bottom_card.dart';
import 'package:dockly_mobile/features/map/presentation/map_screen.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';

import 'package:dockly_mobile/features/location/application/location_controller.dart';

import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/route/application/sea_route_engine.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';

import '../../support/fake_map_surface.dart';
import '../../support/location_fakes.dart';
import '../../support/checklist_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/search_fakes.dart';
import '../../support/trip_fakes.dart';
import '../../support/weather_fakes.dart';

/// İkonlar artık SVG tabanlı [DocklyIcon]; ikon verisiyle bulunur.
Finder _docklyIcon(DocklyIconData d) =>
    find.byWidgetPredicate((Widget w) => w is DocklyIcon && w.data == d);

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

/// Sahte rota motoru — gerçek maske varlığına gidilmez; sabit kısa plan döner.
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

Widget _app(
  FakeMapGateway gateway, {
  FakeMapCache? cache,
  MyBoat? boat,
  FakeNearbyGateway? nearby,
  FakeLocationService? location,
  SeaRouteEngine? routeEngine,
  FakeChecklistStore? checklist,
  FakeTripStore? trips,
}) {
  return ProviderScope(
    overrides: <Override>[
      if (location != null) locationServiceProvider.overrideWithValue(location),
      // Kontrol deposu HER ZAMAN sahte (gerçek shared_preferences'a gitmesin).
      checklistStoreProvider.overrideWithValue(checklist ?? FakeChecklistStore()),
      // Seyir deposu HER ZAMAN sahte (aynı gerekçe).
      tripStoreProvider.overrideWithValue(trips ?? FakeTripStore()),
      if (routeEngine != null)
        seaRouteEngineProvider.overrideWithValue(routeEngine),
      mapLocationsGatewayProvider.overrideWithValue(gateway),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      // Önbellek HER ZAMAN sahte: gerçek shared_preferences testler arasında
      // sızıntı yapar (önceki testin kaydettiği veri sonrakinde "çevrimdışı
      // görünüm" tetikler). Varsayılan: boş sahte önbellek.
      mapCacheProvider.overrideWithValue(cache ?? FakeMapCache()),
      // Yakın-liman rayı da HER ZAMAN sahte (varsayılan boş → ray gizli) —
      // gerçek ağ geçidi testte HTTP'ye çıkardı.
      nearbyGatewayProvider.overrideWithValue(nearby ?? FakeNearbyGateway()),
      // Tanıtım (2026-08) bu testlerin konusu değil — "görüldü" kabul edilir.
      onboardingStoreProvider.overrideWithValue(doneOnboardingStore()),
      // Hava ağ geçidi HER ZAMAN sahte (rota rüzgâr analizi ağa çıkmasın).
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

const ValueKey<String> _pinKey = ValueKey<String>('pin-loc-1');

void main() {
  testWidgets('açılışta görünüm bildirilir → marker çizilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    expect(find.byKey(_pinKey), findsOneWidget);
  });

  testWidgets('pin dokunma → seçim gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('selection')), findsOneWidget);
    expect(find.text('secili:loc-1'), findsOneWidget);
  });

  testWidgets('pin dokunma → alt detay kartı belirir; kapatınca kaybolur', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    expect(find.byKey(LocationBottomCard.cardKey), findsNothing);

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LocationBottomCard.cardKey), findsOneWidget);
    // Tip etiketi üstteki filtre çipinde de geçer; kartın İÇİNDE aranır.
    expect(
      find.descendant(
        of: find.byKey(LocationBottomCard.cardKey),
        matching: find.text('Özel Marina'),
      ),
      findsOneWidget,
    );

    await tester.tap(_docklyIcon(DocklyIcons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(LocationBottomCard.cardKey), findsNothing);
  });

  testWidgets('liste görünümüne geçince liman listesi görünür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing); // harita modu (sahte yüzey ListTile kullanmaz)

    await tester.tap(_docklyIcon(DocklyIcons.viewList));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget); // liste modu, tek pin
    expect(_docklyIcon(DocklyIcons.mapOutlined), findsOneWidget); // haritaya dön ikonu
  });

  testWidgets('tekne tanımlıysa alt kartta uyum rozeti görünür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      boat: const MyBoat(lengthM: 15, draftM: 2),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    // testPin limiti 40 m → 15 m tekne sığar.
    expect(find.text('Teknen sığar'), findsOneWidget);
  });

  testWidgets('tip çipine dokununca filtre sunucuya geçer', (WidgetTester tester) async {
    final FakeMapGateway gateway = FakeMapGateway(result: pinResult);
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Özel Marina'));
    await tester.pumpAndSettle();
    expect(gateway.typeArgs.last, <String>['private_marina']);
  });

  testWidgets('ilk yüklemede dost mesaj gösterilir (sunucu uyanıyor)', (WidgetTester tester) async {
    final FakeMapGateway gateway = FakeMapGateway()..pending = Completer<MapResult>();
    await tester.pumpWidget(_app(gateway));
    // Süreli pump: sahte-saat ilerlesin ki debounce zamanlayıcısı ateşlensin
    // (bare pump() zamanlayıcıları ÇALIŞTIRMAZ — saat ilerlemez).
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(); // durum değişikliği ekrana yansır
    expect(find.textContaining('Limanlar yükleniyor'), findsOneWidget);
    gateway.pending!.complete(pinResult); // testi temiz bitir
    await tester.pumpAndSettle();
  });

  testWidgets('boş bölge → boş görünüm', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(
      result: const MapResult(
        clusters: <Cluster>[],
        locations: <LocationPin>[],
        truncated: false,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('henüz liman yok'), findsOneWidget);
    // KAPSAM DÜRÜSTLÜĞÜ (Faz 2, denetim bulgusu): Karadeniz'e bakan kullanıcı
    // "veri yok" değil, kapsamın ne olduğunu okusun.
    expect(find.textContaining('Ege ve Akdeniz'), findsOneWidget);
  });

  testWidgets('truncated → yakınlaştırma ipucu', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(
      result: const MapResult(
        clusters: <Cluster>[],
        locations: <LocationPin>[testPin],
        truncated: true,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('yakınlaştırın'), findsOneWidget);
  });

  testWidgets('ağ yokken önbellek doluysa → çevrimdışı şerit + son limanlar', (WidgetTester tester) async {
    final FakeMapCache cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(_app(FakeMapGateway(error: const NetworkFailure()), cache: cache));
    await tester.pumpAndSettle();

    expect(find.textContaining('Çevrimdışı'), findsOneWidget);
    expect(find.byKey(_pinKey), findsOneWidget); // son görülen liman haritada
    expect(find.text('Tekrar dene'), findsNothing); // tam-ekran hata YOK
  });

  testWidgets('yakın rayı VARSAYILAN GİZLİ: şerit var, kartlar yok; dokununca açılır', (WidgetTester tester) async {
    final FakeNearbyGateway nearby = FakeNearbyGateway(results: <LocationSummary>[
      sampleSummary('n1', 'Marina Symi', ratingAvg: 4.7, distanceNm: 2.1),
      sampleSummary('n2', 'Gökkaya Koyu', type: 'mooring_point', distanceNm: 5.4),
    ]);
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult), nearby: nearby));
    await tester.pumpAndSettle();

    // Varsayılan: yalnız başlık şeridi görünür, kartlar GİZLİ.
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsOneWidget);
    expect(find.text('Marina Symi'), findsNothing);

    // Şeride dokun → kartlar açılır (ad + tip · ★puan · mesafe formatı).
    await tester.tap(find.text('Yakınımdaki Bağlanma Noktaları'));
    await tester.pumpAndSettle();
    expect(find.text('Marina Symi'), findsOneWidget);
    expect(find.text('Gökkaya Koyu'), findsOneWidget);
    expect(find.textContaining('★ 4.7'), findsOneWidget);
    expect(find.textContaining('2.1 nm'), findsOneWidget);

    // Tekrar dokun → yeniden gizlenir.
    await tester.tap(find.text('Yakınımdaki Bağlanma Noktaları'));
    await tester.pumpAndSettle();
    expect(find.text('Marina Symi'), findsNothing);
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsOneWidget);
  });

  testWidgets('pin seçilince yakın rayı gizlenir (yerini detay kartı alır)', (WidgetTester tester) async {
    final FakeNearbyGateway nearby = FakeNearbyGateway(results: <LocationSummary>[
      sampleSummary('n1', 'Marina Symi', distanceNm: 2.1),
    ]);
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult), nearby: nearby));
    await tester.pumpAndSettle();
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsOneWidget);

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsNothing);
    expect(find.byKey(LocationBottomCard.cardKey), findsOneWidget);
  });

  testWidgets('hata → hata görünümü + retry başarıyla toparlar', (WidgetTester tester) async {
    final gateway = FakeMapGateway(error: const NetworkFailure());
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byKey(_pinKey), findsNothing);

    gateway.error = null;
    gateway.result = pinResult;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.byKey(_pinKey), findsOneWidget);
  });

  testWidgets('Teknem sığar filtresi: sığmayan pin gizlenir, bilinmeyen kalır',
      (WidgetTester tester) async {
    const LocationPin small = LocationPin(
      id: 'loc-small',
      name: 'Küçük İskele',
      type: 'municipal_pier',
      position: GeoPoint(lat: 36.76, lon: 28.94),
      ratingAvg: null,
      priceTier: 'unknown',
      maxBoatLengthM: 8, // 15 m tekne SIĞMAZ
      maxDraftM: 1,
    );
    const LocationPin unknownLimits = LocationPin(
      id: 'loc-unknown',
      name: 'Bilinmeyen Koy',
      type: 'mooring_point',
      position: GeoPoint(lat: 36.77, lon: 28.95),
      ratingAvg: null,
      priceTier: 'free',
      // limit alanları null → BİLİNMEYEN: filtre gizleyemez (0-uydurma UI hali)
    );
    const MapResult threePins = MapResult(
      clusters: <Cluster>[],
      locations: <LocationPin>[testPin, small, unknownLimits],
      truncated: false,
    );
    await tester.pumpWidget(_app(
      FakeMapGateway(result: threePins),
      boat: const MyBoat(lengthM: 15, draftM: 2),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-small')), findsOneWidget);

    await tester.tap(find.text('Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.byKey(_pinKey), findsOneWidget); // 40 m limit → sığar, kalır
    expect(find.byKey(const ValueKey<String>('pin-loc-small')), findsNothing);
    expect(find.byKey(const ValueKey<String>('pin-loc-unknown')), findsOneWidget);

    // Tekrar dokun → filtre kapanır, pin geri gelir.
    await tester.tap(find.text('Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-small')), findsOneWidget);
  });

  testWidgets('Teknem sığar: tekne tanımlı değilse tekne sayfası açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.text('Tekneni tanımla'), findsOneWidget); // tekne sayfası
  });

  testWidgets('Konumum → haritada yelkenli imleç + kamera odak isteği',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: FakeLocationService(const GeoPoint(lat: 38.4, lon: 27.1)),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('device-boat')), findsNothing);

    await tester.tap(find.byTooltip('Konumum'));
    await tester.pumpAndSettle();

    // Tekne imleci yüzeye geçti + kamera odak isteği üretildi.
    expect(find.byKey(const ValueKey<String>('device-boat')), findsOneWidget);
    expect(find.text('ben:38.4,27.1'), findsOneWidget);
    expect(find.text('odak:38.4,27.1,1'), findsOneWidget);
    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Konum alınamazsa imleç çizilmez, bilgi mesajı çıkar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: FakeLocationService(null),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Konumum'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('device-boat')), findsNothing);
    expect(find.textContaining('Konum alınamadı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('AKILLI ROTA (2026-08): konum yokken "Deniz rotası" izin akışını '
      'kendiliğinden başlatır; izin gelince rota OTOMATİK çizilir',
      (WidgetTester tester) async {
    final FakeLocationService location =
        FakeLocationService(const GeoPoint(lat: 36.76, lon: 28.96));
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: location,
      routeEngine: _FakeRouteEngine(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    // Konum paylaşılmamış — düğmeye basınca izin istenir ve rota kendiliğinden
    // oluşur (koyu yeniden bulup basmak GEREKMEZ — kullanıcı isteği).
    await tester.tap(find.text('Deniz rotası'));
    await tester.pumpAndSettle();

    expect(location.calls, 1); // izin akışı otomatik tetiklendi
    expect(find.textContaining('≈'), findsOneWidget); // rota çipi ekranda
    // İlk ara nokta ipucu SnackBar'ı vb. zamanlayıcıları akıt.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
  testWidgets('SEYİR ÖNCESİ KONTROL (2026-08): rota çizilince nazik şerit '
      'GÜNDE BİR kez sorar; "Hazırım" kapatır, aynı gün tekrar çıkmaz',
      (WidgetTester tester) async {
    final FakeChecklistStore checklist = FakeChecklistStore();
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: FakeLocationService(const GeoPoint(lat: 36.76, lon: 28.96)),
      routeEngine: _FakeRouteEngine(),
      checklist: checklist,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deniz rotası'));
    await tester.pumpAndSettle();

    // Şerit geldi; "Hazırım" kapatır ve karar cihaza işlenir.
    expect(find.text('Seyir öncesi kontrollerini yaptın mı?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('checklist-ready')));
    await tester.pumpAndSettle();
    expect(find.text('Seyir öncesi kontrollerini yaptın mı?'), findsNothing);
    expect(checklist.askDay, isNotNull);

    // Aynı gün İKİNCİ rota → şerit BİR DAHA çıkmaz (onaylı doz: günde bir).
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    await c
        .read(mapControllerProvider.notifier)
        .routeTo(const GeoPoint(lat: 36.70, lon: 28.80), 'loc-2', name: 'B');
    await tester.pumpAndSettle();
    expect(find.text('Seyir öncesi kontrollerini yaptın mı?'), findsNothing);
    // Zamanlayıcı artıklarını akıt (snackbar vb.).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('SEYİR KAYDI (v2.0): rota kartından başlat → bitir; seyir '
      'depoya işlenir ve onay mesajı çıkar', (WidgetTester tester) async {
    final FakeTripStore trips = FakeTripStore();
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: FakeLocationService(const GeoPoint(lat: 36.76, lon: 28.96)),
      routeEngine: _FakeRouteEngine(),
      trips: trips,
    ));
    await tester.pumpAndSettle();

    // Rota çiz (pin → "Deniz rotası") ve günlük kontrol şeridini kapat.
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deniz rotası'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('checklist-ready')));
    await tester.pumpAndSettle();
    // Önceki bildirileri AKIT (CI dersi: ekranda bekleyen eski snackbar,
    // yenisini kuyruğa atar — "Defter'e işlendi" hiç görünmezdi).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Başlat: süren seyir satırı belirir ve cihaza yazılır.
    await tester.tap(find.byKey(const ValueKey<String>('trip-start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seyir sürüyor'), findsOneWidget);
    expect(trips.active, isNotNull);

    // Bitir: kayıt depoya düşer, onay mesajı görünür, satır sıfırlanır.
    // (Önce depo doğrulanır — mesaj bulunamazsa neden ayrışsın.)
    await tester.tap(find.byKey(const ValueKey<String>('trip-finish')));
    await tester.pumpAndSettle();
    expect(trips.active, isNull);
    expect(trips.data, hasLength(1));
    expect(trips.data.first.distanceNm, greaterThan(0));
    expect(find.textContaining('Defter\'e işlendi'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('trip-start')), findsOneWidget);

    // Snackbar zamanlayıcısını akıt.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('ROTA ÇİPİ KATLAMA (kullanıcı isteği 2026-08): çok duraklı '
      'rotada çip kendini toplar; ok düğmesi ayrıntıları açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      routeEngine: _FakeRouteEngine(),
    ));
    await tester.pumpAndSettle();

    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    // İki duraklı kayıtlı rota aç → çip OTOMATİK toplanır.
    await c.read(mapControllerProvider.notifier).openSavedRoute(
      const RouteOrigin(pos: GeoPoint(lat: 36.75, lon: 28.93), name: 'Göcek'),
      const <RouteWaypoint>[
        RouteWaypoint(
            pos: GeoPoint(lat: 36.72, lon: 28.92), name: 'Bedri Rahmi'),
        RouteWaypoint(
            pos: GeoPoint(lat: 36.70, lon: 28.90), name: 'Boynuz Bükü'),
      ],
      name: 'Üç koy turu',
    );
    await tester.pumpAndSettle();

    // Başlık ve istatistikler DURUR; durak listesi ve başlangıç satırı gizli.
    expect(find.text('Üç koy turu'), findsOneWidget);
    expect(find.text('DURAK'), findsOneWidget);
    expect(find.text('Bedri Rahmi'), findsNothing);
    expect(find.text('Boynuz Bükü'), findsNothing);
    // DÜRÜSTLÜK NOTU katlanmaz: kapalıyken de görünür.
    expect(find.textContaining('Tahminî deniz rotası'), findsOneWidget);

    // Ok düğmesi ayrıntıları açar.
    await tester.tap(find.byKey(const ValueKey<String>('route-chip-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Bedri Rahmi'), findsOneWidget);
    expect(find.text('Boynuz Bükü'), findsOneWidget);

    // Tekrar dokunmak kapatır.
    await tester.tap(find.byKey(const ValueKey<String>('route-chip-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Bedri Rahmi'), findsNothing);

    // DÜZENLEME SIRASINDA KAPANMAZ (inceleme dersi): kaptan açtıysa, durak
    // eklense bile açık kalır.
    await tester.tap(find.byKey(const ValueKey<String>('route-chip-toggle')));
    await tester.pumpAndSettle();
    await c.read(mapControllerProvider.notifier).addStop(
          const GeoPoint(lat: 36.68, lon: 28.88),
          'loc-x',
          'Kille Koyu',
        );
    await tester.pumpAndSettle();
    expect(find.text('Kille Koyu'), findsOneWidget);
    expect(find.text('Bedri Rahmi'), findsOneWidget);

    // Zamanlayıcı artıklarını akıt.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('ROTA ODAK MODU (2026-08): kayıtlı rota açılınca yalnız '
      'duraklar kalır; rota kapatılınca imleçler geri döner',
      (WidgetTester tester) async {
    const LocationPin second = LocationPin(
      id: 'loc-2',
      name: 'Gökkaya Koyu',
      type: 'mooring_point',
      position: GeoPoint(lat: 36.72, lon: 28.92),
      ratingAvg: null,
      priceTier: 'free',
    );
    await tester.pumpWidget(_app(
      FakeMapGateway(
        result: const MapResult(
          clusters: <Cluster>[],
          locations: <LocationPin>[testPin, second],
          truncated: false,
        ),
      ),
      routeEngine: _FakeRouteEngine(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pin-loc-2')), findsOneWidget);

    // Önce bir koy seçili olsun — odak açılınca seçim kartı KAPANMALI
    // (gizlenen imleci anlatan kart kalmasın).
    await tester.tap(find.byKey(const ValueKey<String>('pin-loc-1')));
    await tester.pumpAndSettle();
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    expect(c.read(mapControllerProvider).selectedPinId, 'loc-1');

    // Kayıtlı rota açılır (Kayıtlarım'daki "Haritada aç" bu yolu kullanır):
    // durağı loc-2 olan rota — sahnede yalnız rota ve durağı kalmalı.
    await c.read(mapControllerProvider.notifier).openSavedRoute(
      const RouteOrigin(pos: GeoPoint(lat: 36.75, lon: 28.93), name: 'Göcek'),
      const <RouteWaypoint>[
        RouteWaypoint(
            pos: GeoPoint(lat: 36.72, lon: 28.92),
            id: 'loc-2',
            name: 'Gökkaya Koyu'),
      ],
      name: 'Datça turu',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pin-loc-1')), findsNothing);
    expect(c.read(mapControllerProvider).selectedPinId, isNull); // kart kapandı

    // Rota kapatılınca (✕) normal görünüm döner.
    c.read(mapControllerProvider.notifier).clearRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pin-loc-2')), findsOneWidget);

    // Zamanlayıcı artıklarını akıt (kontrol şeridi/snackbar vb.).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
