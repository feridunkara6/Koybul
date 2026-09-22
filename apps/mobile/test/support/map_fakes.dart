import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/map/domain/map_cache.dart';
import 'package:dockly_mobile/features/map/domain/map_locations_gateway.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:dockly_mobile/features/route/application/route_quota_controller.dart';

const Bbox testBbox = Bbox(minLon: 28.90, minLat: 36.70, maxLon: 29.00, maxLat: 36.80);
const MapViewport pinViewport = MapViewport(bbox: testBbox, zoom: 13);
const MapViewport clusterViewport = MapViewport(bbox: testBbox, zoom: 6);

const LocationPin testPin = LocationPin(
  id: 'loc-1',
  name: 'D-Marin Göcek',
  type: 'private_marina',
  position: GeoPoint(lat: 36.75, lon: 28.93),
  ratingAvg: 4.8,
  priceTier: 'paid',
  maxBoatLengthM: 40,
  maxDraftM: 5,
);

const Cluster testCluster = Cluster(
  position: GeoPoint(lat: 40.0, lon: 30.0),
  count: 34,
  bbox: Bbox(minLon: 29.5, minLat: 39.5, maxLon: 30.5, maxLat: 40.5),
  countryCode: 'TR',
);

const MapResult pinResult = MapResult(
  clusters: <Cluster>[],
  locations: <LocationPin>[testPin],
  truncated: false,
);

const MapResult clusterResult = MapResult(
  clusters: <Cluster>[testCluster],
  locations: <LocationPin>[],
  truncated: false,
);

/// Testte `MapLocationsGateway` yerine geçen sahte (yalnız testte mock, docs/15).
class FakeMapGateway implements MapLocationsGateway {
  FakeMapGateway({this.result = pinResult, this.error});

  MapResult result;
  AppFailure? error;

  final List<MapViewport> calls = <MapViewport>[];

  /// Her çağrıda geçirilen tip filtresi (null = tümü) — filtre testleri için.
  final List<List<String>?> typeArgs = <List<String>?>[];

  /// Ayarlanırsa yanıt bu completer ile elle tamamlanır (yarış/stale testi).
  Completer<MapResult>? pending;

  @override
  Future<MapResult> loadViewport(MapViewport viewport, {List<String>? types}) {
    calls.add(viewport);
    typeArgs.add(types);
    final controlled = pending;
    if (controlled != null) return controlled.future;
    final err = error;
    if (err != null) return Future<MapResult>.error(err);
    return Future<MapResult>.value(result);
  }
}

/// Testte `MapCache` yerine geçen sahte (bellek içi).
class FakeMapCache implements MapCache {
  FakeMapCache({this.cached});

  CachedMap? cached;
  int saveCount = 0;

  @override
  Future<CachedMap?> load() async => cached;

  @override
  Future<void> save(List<LocationPin> pins, List<Cluster> clusters) async {
    saveCount += 1;
    cached = CachedMap(pins: pins, clusters: clusters, savedAt: DateTime(2026));
  }
}

/// Sahte ROTA KOTASI deposu (P4b) — bellek içi; cihaz deposuna asla gidilmez.
class FakeRouteQuotaStore implements RouteQuotaStore {
  FakeRouteQuotaStore([this.day, this.used]);

  String? day;
  int? used;

  @override
  Future<(String, int)?> load() async {
    final String? d = day;
    final int? u = used;
    return (d == null || u == null) ? null : (d, u);
  }

  @override
  Future<void> save(String dayKey, int usedCount) async {
    day = dayKey;
    used = usedCount;
  }
}
