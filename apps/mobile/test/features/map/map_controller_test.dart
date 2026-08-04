import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/core/origin_provider.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/data/bundled_map_snapshot.dart';
import 'package:dockly_mobile/features/map/data/shared_prefs_map_cache.dart';
import 'package:dockly_mobile/features/map/domain/map_cache.dart';
import 'package:dockly_mobile/features/map/domain/map_state.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:dockly_mobile/features/route/application/route_wind_advisor.dart';
import 'package:dockly_mobile/features/route/application/sea_route_engine.dart';
import 'package:dockly_mobile/features/route/domain/route_wind.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/map_fakes.dart';

/// Sahte gömülü anlık görüntü — determinizm: gerçek `rootBundle` varlığına
/// test ortamında ASLA gidilmez; verilen harita döner (varsayılan: yok).
class FakeBundledSnapshot extends BundledMapSnapshot {
  FakeBundledSnapshot([this.map]);

  final CachedMap? map;
  int loadCount = 0;

  @override
  Future<CachedMap?> load() async {
    loadCount++;
    return map;
  }
}

/// Sahte rota motoru — gerçek maske varlığına gidilmez; verilen plan döner.
class FakeSeaRouteEngine extends SeaRouteEngine {
  FakeSeaRouteEngine([this.plan]);

  final SeaRoutePlan? plan;
  int calls = 0;

  @override
  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async {
    calls++;
    return plan;
  }
}

/// Sahte rüzgâr danışmanı — ağa/varlığa gidilmez; verilen rapor döner.
class FakeRouteWindAdvisor extends RouteWindAdvisor {
  FakeRouteWindAdvisor(super.ref, [this.report]);

  final RouteWindReport? report;
  int calls = 0;

  @override
  Future<RouteWindReport?> analyze(
    SeaRoutePlan plan,
    String destinationIdOrSlug, {
    DateTime? departure,
  }) async {
    calls++;
    return report;
  }
}

/// Testte kurulan son sahte danışman (çağrı sayısı denetimi için).
FakeRouteWindAdvisor? lastFakeAdvisor;

ProviderContainer _containerWith(
  FakeMapGateway gateway, {
  Duration debounce = Duration.zero,
  FakeMapCache? cache,
  FakeBundledSnapshot? snapshot,
  FakeSeaRouteEngine? routeEngine,
  RouteWindReport? windReport,
}) {
  lastFakeAdvisor = null; // önceki testten sarkmasın (determinizm)
  final container = ProviderContainer(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(gateway),
      mapDebounceProvider.overrideWithValue(debounce),
      // Önbellek HER ZAMAN sahte (testler arası sızıntı olmasın — determinizm).
      mapCacheProvider.overrideWithValue(cache ?? FakeMapCache()),
      bundledMapSnapshotProvider.overrideWithValue(snapshot ?? FakeBundledSnapshot()),
      seaRouteEngineProvider.overrideWithValue(routeEngine ?? FakeSeaRouteEngine()),
      // Danışman HER ZAMAN sahte: gerçek danışman ağa (hava tahmini + detay)
      // çıkar — testler asla ağa çıkmaz.
      routeWindAdvisorProvider.overrideWith(
        (ref) => lastFakeAdvisor = FakeRouteWindAdvisor(ref, windReport),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

MapController _ctrl(ProviderContainer c) => c.read(mapControllerProvider.notifier);

/// KONUM ŞARTI (2026-08): rota testleri paylaşılmış GPS konumu kurar —
/// rota yalnız gerçek konumdan hesaplanır (harita merkezi yeterli DEĞİL).
void _shareLocation(ProviderContainer c) =>
    c.read(devicePositionProvider.notifier).state =
        const GeoPoint(lat: 36.76, lon: 28.96);
MapState _state(ProviderContainer c) => c.read(mapControllerProvider);

void main() {
  test('başlangıç: marker yok, yükleme yok; boş-durum HENÜZ gösterilmez (P9 flicker yok)', () {
    final container = _containerWith(FakeMapGateway());
    final state = _state(container);
    expect(state.pins, isEmpty);
    expect(state.clusters, isEmpty);
    expect(state.isLoading, isFalse);
    expect(state.hasLoadedOnce, isFalse);
    expect(state.isEmpty, isFalse); // ilk yükleme bitmeden "liman yok" gösterilmez
  });

  test('ilk yükleme boş sonuç döndürünce → boş durum gösterilir', () async {
    const emptyResult = MapResult(
      clusters: <Cluster>[],
      locations: <LocationPin>[],
      truncated: false,
    );
    final container = _containerWith(FakeMapGateway(result: emptyResult));
    await _ctrl(container).loadViewport(pinViewport);
    final state = _state(container);
    expect(state.hasLoadedOnce, isTrue);
    expect(state.hasData, isFalse);
    expect(state.isEmpty, isTrue);
  });

  test('loadViewport → origin haritanın merkezine yazılır (deniz-rota başlangıcı)', () async {
    final container = _containerWith(FakeMapGateway(result: pinResult));
    await _ctrl(container).loadViewport(pinViewport);
    final GeoPoint? origin = container.read(originProvider);
    expect(origin, isNotNull);
    expect(origin!.lat, moreOrLessEquals(36.75, epsilon: 0.001)); // (36.70+36.80)/2
    expect(origin.lon, moreOrLessEquals(28.95, epsilon: 0.001)); // (28.90+29.00)/2
  });

  test('loadViewport başarı → pin modu verisi', () async {
    final container = _containerWith(FakeMapGateway(result: pinResult));
    await _ctrl(container).loadViewport(pinViewport);
    final state = _state(container);
    expect(state.pins.single.id, 'loc-1');
    expect(state.clusters, isEmpty);
    expect(state.isLoading, isFalse);
    expect(state.failure, isNull);
    expect(state.hasData, isTrue);
  });

  test('loadViewport cluster modu → balon verisi', () async {
    final container = _containerWith(FakeMapGateway(result: clusterResult));
    await _ctrl(container).loadViewport(clusterViewport);
    expect(_state(container).clusters.single.count, 34);
    expect(_state(container).pins, isEmpty);
  });

  test('veri varken hata → önceki marker korunur + çevrimdışı şerit (tam-ekran hata YOK)', () async {
    final gateway = FakeMapGateway(result: pinResult);
    final container = _containerWith(gateway);
    await _ctrl(container).loadViewport(pinViewport);
    expect(_state(container).pins, hasLength(1));

    gateway.error = const NetworkFailure();
    await _ctrl(container).loadViewport(clusterViewport);
    final state = _state(container);
    // Yeni sözleşme: ekranda veri varsa hata bindirilmez; veri korunur ve
    // çevrimdışı şerit gösterilir (gezinmek yeniden dener).
    expect(state.failure, isNull);
    expect(state.isOffline, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.pins, hasLength(1)); // eski veri silinmedi
  });

  test('retry: hatadan sonra başarıyla toparlar', () async {
    final gateway = FakeMapGateway(error: const NetworkFailure());
    final container = _containerWith(gateway);
    await _ctrl(container).loadViewport(pinViewport);
    expect(_state(container).failure, isA<NetworkFailure>());

    gateway.error = null;
    gateway.result = pinResult;
    await _ctrl(container).retry();
    final state = _state(container);
    expect(state.failure, isNull);
    expect(state.pins.single.id, 'loc-1');
  });

  test('toggleType: filtre eklenir → son görünüm filtreyle yeniden yüklenir; ikinci dokunuş kaldırır', () async {
    final gateway = FakeMapGateway();
    final container = _containerWith(gateway);
    await _ctrl(container).loadViewport(pinViewport);
    expect(gateway.typeArgs.last, isNull); // filtre yok = tümü

    await _ctrl(container).toggleType('private_marina');
    expect(_state(container).types, contains('private_marina'));
    expect(gateway.typeArgs.last, <String>['private_marina']);

    await _ctrl(container).toggleType('private_marina'); // kapat
    expect(_state(container).types, isEmpty);
    expect(gateway.typeArgs.last, isNull);
  });

  test('başarılı yükleme önbelleğe yazılır; filtre açıkken YAZILMAZ', () async {
    final cache = FakeMapCache();
    final gateway = FakeMapGateway(result: pinResult);
    final container = _containerWith(gateway, cache: cache);
    await _ctrl(container).loadViewport(pinViewport);
    expect(cache.saveCount, 1);
    expect(cache.cached!.pins.single.id, 'loc-1');

    await _ctrl(container).toggleType('private_marina'); // filtreli yeniden yükleme
    expect(cache.saveCount, 1); // filtreli sonuç önbelleği KİRLETMEZ
  });

  test('ağ hatası + boş ekran + önbellek dolu → çevrimdışı görünüm (veri + isOffline)', () async {
    final cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    final gateway = FakeMapGateway(error: const NetworkFailure());
    final container = _containerWith(gateway, cache: cache);
    await _ctrl(container).loadViewport(pinViewport);
    final state = _state(container);
    expect(state.isOffline, isTrue);
    expect(state.pins.single.id, 'loc-1');
    expect(state.failure, isNull); // veri gösteriliyor → tam-ekran hata yok
  });

  test('ağ hatası + önbellek boş → eski davranış (failure)', () async {
    final gateway = FakeMapGateway(error: const NetworkFailure());
    final container = _containerWith(gateway, cache: FakeMapCache());
    await _ctrl(container).loadViewport(pinViewport);
    expect(_state(container).failure, isA<NetworkFailure>());
    expect(_state(container).isOffline, isFalse);
  });

  test('çevrimdışıyken bağlantı dönerse → isOffline kapanır, taze veri gelir', () async {
    final cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    final gateway = FakeMapGateway(error: const NetworkFailure());
    final container = _containerWith(gateway, cache: cache);
    await _ctrl(container).loadViewport(pinViewport);
    expect(_state(container).isOffline, isTrue);

    gateway.error = null;
    gateway.result = clusterResult;
    await _ctrl(container).loadViewport(clusterViewport);
    expect(_state(container).isOffline, isFalse);
    expect(_state(container).clusters.single.count, 34);
  });

  test('sıcak başlangıç: önbellek ANINDA gösterilir, taze veri gelince yerini alır', () async {
    final cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    final gateway = FakeMapGateway()..pending = Completer<MapResult>();
    final container = _containerWith(gateway, cache: cache);

    final Future<void> loading = _ctrl(container).loadViewport(clusterViewport);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    // Taze veri henüz gelmedi ama harita DOLU (önbellek) + ince yükleme sürüyor.
    expect(_state(container).pins.single.id, 'loc-1');
    expect(_state(container).isLoading, isTrue);
    expect(_state(container).isOffline, isFalse);

    gateway.pending!.complete(clusterResult);
    await loading;
    expect(_state(container).clusters.single.count, 34); // taze veri kazandı
    expect(_state(container).isLoading, isFalse);
  });

  test('sıcak başlangıç sonrası ağ hatası → veri korunur + çevrimdışı şerit (tam-ekran hata YOK)', () async {
    final cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    final gateway = FakeMapGateway(error: const NetworkFailure());
    final container = _containerWith(gateway, cache: cache);
    await _ctrl(container).loadViewport(pinViewport);
    final state = _state(container);
    expect(state.pins.single.id, 'loc-1');
    expect(state.isOffline, isTrue);
    expect(state.failure, isNull);
  });

  test('selectPin / clearSelection', () {
    final container = _containerWith(FakeMapGateway());
    _ctrl(container).selectPin('loc-1');
    expect(_state(container).selectedPinId, 'loc-1');
    _ctrl(container).clearSelection();
    expect(_state(container).selectedPinId, isNull);
  });

  test('onViewportChanged: aynı görünüm tekrar yüklenmez (dedup)', () async {
    final gateway = FakeMapGateway();
    final container = _containerWith(gateway);
    _ctrl(container).onViewportChanged(pinViewport);
    _ctrl(container).onViewportChanged(pinViewport); // aynı → atlanır
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gateway.calls, hasLength(1));
  });

  test('onViewportChanged: farklı görünüm yüklenir', () async {
    final gateway = FakeMapGateway();
    final container = _containerWith(gateway);
    _ctrl(container).onViewportChanged(pinViewport);
    _ctrl(container).onViewportChanged(clusterViewport);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gateway.calls, contains(clusterViewport));
  });

  test('hızlı yol: kapsanan alana yakınlaşınca ağa çıkılmaz — pinler anında süzülür', () async {
    final gateway = FakeMapGateway(result: pinResult);
    final container = _containerWith(gateway);
    await _ctrl(container).loadViewport(pinViewport); // ağ: önbelleği doldurur
    expect(gateway.calls, hasLength(1));

    // testBbox İÇİNDE kalan daha dar alan + daha derin zoom → ağ çağrısı YOK.
    const MapViewport zoomedIn = MapViewport(
      bbox: Bbox(minLon: 28.92, minLat: 36.73, maxLon: 28.96, maxLat: 36.78),
      zoom: 14,
    );
    await _ctrl(container).loadViewport(zoomedIn);
    expect(gateway.calls, hasLength(1)); // ikinci ağ çağrısı olmadı
    expect(_state(container).pins.single.id, 'loc-1'); // (28.93, 36.75) alanda
    expect(_state(container).isLoading, isFalse);
    expect(_state(container).clusters, isEmpty);

    // Pin'i DIŞARIDA bırakan dar köşe → yine ağ yok, pinler doğru süzülür (boş).
    const MapViewport farCorner = MapViewport(
      bbox: Bbox(minLon: 28.96, minLat: 36.76, maxLon: 28.99, maxLat: 36.79),
      zoom: 14,
    );
    await _ctrl(container).loadViewport(farCorner);
    expect(gateway.calls, hasLength(1));
    expect(_state(container).pins, isEmpty);
  });

  test('hızlı yol: truncated yanıt önbelleğe alınmaz → yakınlaşma ağa gider', () async {
    final gateway = FakeMapGateway(
      result: const MapResult(
        clusters: <Cluster>[],
        locations: <LocationPin>[testPin],
        truncated: true, // 500 tavanı aşıldı — eksik olabilir, süzme güvensiz
      ),
    );
    final container = _containerWith(gateway);
    await _ctrl(container).loadViewport(pinViewport);
    expect(gateway.calls, hasLength(1));

    const MapViewport zoomedIn = MapViewport(
      bbox: Bbox(minLon: 28.92, minLat: 36.73, maxLon: 28.96, maxLat: 36.78),
      zoom: 14,
    );
    await _ctrl(container).loadViewport(zoomedIn);
    expect(gateway.calls, hasLength(2)); // önbellek yok → normal ağ yolu
  });

  test('hızlı yol: cluster modunda (zoom < 10) kullanılmaz', () async {
    final gateway = FakeMapGateway(result: pinResult);
    final container = _containerWith(gateway);
    await _ctrl(container).loadViewport(pinViewport); // pin önbelleği dolu
    gateway.result = clusterResult;
    await _ctrl(container).loadViewport(clusterViewport); // zoom 6 → ağ
    expect(gateway.calls, hasLength(2));
    expect(_state(container).clusters.single.count, 34);
  });

  test('gömülü anlık görüntü: İLK ziyarette (önbellek boş) harita anında dolar, taze veri gelince yerini bırakır', () async {
    final snapshot = FakeBundledSnapshot(CachedMap(
      pins: const <LocationPin>[],
      clusters: clusterResult.clusters,
      savedAt: DateTime(2026),
    ));
    final gateway = FakeMapGateway()..pending = Completer<MapResult>();
    final container = _containerWith(gateway, snapshot: snapshot);

    final Future<void> loading = _ctrl(container).loadViewport(clusterViewport);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    // Ağ yanıtı henüz yok ama harita DOLU: gömülü balonlar gösteriliyor.
    expect(snapshot.loadCount, 1);
    expect(_state(container).clusters.single.count, 34);
    expect(_state(container).isLoading, isTrue);

    gateway.pending!.complete(pinResult);
    await loading;
    expect(_state(container).pins.single.id, 'loc-1'); // taze veri kazandı
    expect(_state(container).isLoading, isFalse);
  });

  test('gömülü anlık görüntü: cihaz önbelleği DOLUYSA hiç okunmaz', () async {
    final snapshot = FakeBundledSnapshot(CachedMap(
      pins: const <LocationPin>[],
      clusters: clusterResult.clusters,
      savedAt: DateTime(2026),
    ));
    final cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    final container = _containerWith(
      FakeMapGateway(result: pinResult),
      cache: cache,
      snapshot: snapshot,
    );
    await _ctrl(container).loadViewport(pinViewport);
    expect(snapshot.loadCount, 0); // cihaz önbelleği yeterliydi
  });

  test('gömülü anlık görüntü + ağ hatası → veri korunur, çevrimdışı şerit (tam-ekran hata YOK)', () async {
    final snapshot = FakeBundledSnapshot(CachedMap(
      pins: const <LocationPin>[],
      clusters: clusterResult.clusters,
      savedAt: DateTime(2026),
    ));
    final gateway = FakeMapGateway(error: const NetworkFailure());
    final container = _containerWith(gateway, snapshot: snapshot);
    await _ctrl(container).loadViewport(clusterViewport);
    final state = _state(container);
    expect(state.clusters.single.count, 34); // gömülü veri ekranda kaldı
    expect(state.isOffline, isTrue);
    expect(state.failure, isNull);
  });

  test('deniz rotası: motor plan dönerse duruma yazılır, seq artar', () async {
    const SeaRoutePlan plan = SeaRoutePlan(
      points: <GeoPoint>[
        GeoPoint(lat: 36.75, lon: 28.95),
        GeoPoint(lat: 36.70, lon: 28.90),
        GeoPoint(lat: 36.60, lon: 28.90),
      ],
      distanceNm: 12.5,
      reachedGoal: true,
      viaSea: true,
    );
    final engine = FakeSeaRouteEngine(plan);
    final container = _containerWith(FakeMapGateway(result: pinResult), routeEngine: engine);
    await _ctrl(container).loadViewport(pinViewport);
    _shareLocation(container); // KONUM ŞARTI: rota paylaşılan konumdan
    await _ctrl(container).routeToPin(testPin);
    final state = _state(container);
    expect(engine.calls, 1);
    expect(state.route, same(plan));
    expect(state.isRouting, isFalse);
    expect(state.routeSeq, 1);
  });

  test('deniz rotası: motor null dönerse DÜRÜST kuş uçuşu yedeği (viaSea=false)', () async {
    final container =
        _containerWith(FakeMapGateway(result: pinResult), routeEngine: FakeSeaRouteEngine());
    await _ctrl(container).loadViewport(pinViewport);
    _shareLocation(container);
    await _ctrl(container).routeToPin(testPin);
    final state = _state(container);
    expect(state.route, isNotNull);
    expect(state.route!.viaSea, isFalse);
    expect(state.route!.points, hasLength(2));
    expect(state.route!.points.last.lat, testPin.position.lat);
  });

  test('KONUM ŞARTI: konum paylaşılmadan rota OLUŞTURULMAZ (harita merkezi yetmez)', () async {
    final engine = FakeSeaRouteEngine();
    final container = _containerWith(FakeMapGateway(result: pinResult), routeEngine: engine);
    // Harita yüklendi → origin (harita merkezi) var ama GPS konumu YOK.
    await _ctrl(container).loadViewport(pinViewport);
    await _ctrl(container).routeToPin(testPin);
    expect(engine.calls, 0); // motor hiç çağrılmadı
    expect(_state(container).route, isNull);
  });

  test('clearRoute: çizili rota kaldırılır', () async {
    const SeaRoutePlan plan = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.7, lon: 28.9), GeoPoint(lat: 36.6, lon: 28.9)],
      distanceNm: 6,
      reachedGoal: true,
      viaSea: true,
    );
    final container =
        _containerWith(FakeMapGateway(result: pinResult), routeEngine: FakeSeaRouteEngine(plan));
    await _ctrl(container).loadViewport(pinViewport);
    _shareLocation(container);
    await _ctrl(container).routeToPin(testPin);
    expect(_state(container).route, isNotNull);
    _ctrl(container).clearRoute();
    expect(_state(container).route, isNull);
  });

  test('rüzgâr raporu (Rota v2): analiz sonucu duruma yazılır', () async {
    const RouteSample rs = RouteSample(
      point: GeoPoint(lat: 36.7, lon: 28.9),
      etaHours: 1,
      bearingDeg: 0,
    );
    final RouteWindReport report = buildRouteWindReport(const <RouteWindSample>[
      RouteWindSample(sample: rs, windKn: 21, gustKn: null, windDirDeg: 10),
    ])!;
    const SeaRoutePlan plan = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.75, lon: 28.95), GeoPoint(lat: 36.6, lon: 28.9)],
      distanceNm: 10,
      reachedGoal: true,
      viaSea: true,
    );
    final container = _containerWith(
      FakeMapGateway(result: pinResult),
      routeEngine: FakeSeaRouteEngine(plan),
      windReport: report,
    );
    await _ctrl(container).loadViewport(pinViewport);
    _shareLocation(container);
    await _ctrl(container).routeToPin(testPin);
    expect(lastFakeAdvisor!.calls, 1);
    expect(_state(container).routeWind, same(report));
  });

  test('rüzgâr analizi kuş uçuşu yedeğinde ÇAĞRILMAZ (viaSea=false)', () async {
    final container = _containerWith(
      FakeMapGateway(result: pinResult),
      routeEngine: FakeSeaRouteEngine(), // motor null → kuş uçuşu
    );
    await _ctrl(container).loadViewport(pinViewport);
    _shareLocation(container);
    await _ctrl(container).routeToPin(testPin);
    expect(_state(container).route!.viaSea, isFalse);
    // Danışman hiç OKUNMADI bile (tembel sağlayıcı) — ağ maliyeti sıfır.
    expect(lastFakeAdvisor?.calls ?? 0, 0);
    expect(_state(container).routeWind, isNull);
  });

  test('clearRoute rüzgâr raporunu da temizler', () async {
    const RouteSample rs = RouteSample(
      point: GeoPoint(lat: 36.7, lon: 28.9),
      etaHours: 1,
      bearingDeg: 0,
    );
    final RouteWindReport report = buildRouteWindReport(const <RouteWindSample>[
      RouteWindSample(sample: rs, windKn: 18, gustKn: null, windDirDeg: 90),
    ])!;
    const SeaRoutePlan plan = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.75, lon: 28.95), GeoPoint(lat: 36.6, lon: 28.9)],
      distanceNm: 10,
      reachedGoal: true,
      viaSea: true,
    );
    final container = _containerWith(
      FakeMapGateway(result: pinResult),
      routeEngine: FakeSeaRouteEngine(plan),
      windReport: report,
    );
    await _ctrl(container).loadViewport(pinViewport);
    _shareLocation(container);
    await _ctrl(container).routeToPin(testPin);
    expect(_state(container).routeWind, isNotNull);
    _ctrl(container).clearRoute();
    expect(_state(container).route, isNull);
    expect(_state(container).routeWind, isNull);
  });

  test('decodeCachedMapJson: geçerli anlık görüntü çözülür; bozuk girdi null', () {
    const String raw = '{"pins":[],"clusters":[{"position":{"lat":38.9,"lon":27.1},'
        '"count":12,"bbox":[26.7,38.5,27.4,39.2],"countryCode":"TR"}]}';
    final CachedMap? map = decodeCachedMapJson(raw);
    expect(map, isNotNull);
    expect(map!.pins, isEmpty);
    expect(map.clusters.single.count, 12);
    expect(map.clusters.single.countryCode, 'TR');
    expect(map.clusters.single.bbox.minLon, 26.7);

    expect(decodeCachedMapJson('çöp'), isNull);
    expect(decodeCachedMapJson('[1,2]'), isNull);
  });

  test('stale koruması: eski yanıt geç gelirse yok sayılır (en son kazanır)', () async {
    final gateway = FakeMapGateway();
    final container = _containerWith(gateway);

    // İlk yükleme elle kontrol edilen completer ile askıda
    final slow = Completer<MapResult>();
    gateway.pending = slow;
    final firstFuture = _ctrl(container).loadViewport(pinViewport);

    // İkinci yükleme hızlı tamamlanır
    gateway.pending = null;
    gateway.result = clusterResult;
    await _ctrl(container).loadViewport(clusterViewport);
    expect(_state(container).clusters.single.count, 34);

    // Şimdi eski (yavaş) yanıt gelir — yok sayılmalı
    slow.complete(pinResult);
    await firstFuture;
    expect(_state(container).pins, isEmpty);
    expect(_state(container).clusters.single.count, 34);
  });
}
