import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sea_mask.dart';
import '../data/tr_coast_grid.dart';
import '../domain/sea_router.dart';
import '../domain/sea_trip.dart';

/// Deniz rotası motoru — maskeyi bir kez yükler, sonra bellekten hesaplar.
/// Maske yüklenemezse ya da noktalar kapsam dışıysa null döner; çağıran
/// kuş uçuşu yedeğine düşer (akış asla kırılmaz). Testler sahtesiyle
/// override eder (bkz. seaRouteEngineProvider).
class SeaRouteEngine {
  SeaMask? _mask;
  TrCoastGrid? _waters;
  bool _loadTried = false;

  Future<SeaMask?> _ensureLoaded() async {
    if (_mask == null && !_loadTried) {
      _loadTried = true;
      _mask = await SeaMask.load();
      // Karasuları tercihi ızgarası — yüklenemezse rota TERCİHSİZ çalışır
      // (en iyi çaba; rota yine tamamen denizden).
      _waters = await TrCoastGrid.load();
    }
    return _mask;
  }

  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async {
    final SeaMask? m = await _ensureLoaded();
    if (m == null) return null;
    return planSeaRoute(m, from, to, waters: _waters);
  }

  /// ÇOK DURAKLI YOLCULUK (rota düzenleme 2026-08): başlangıçtan sırayla her
  /// ara noktaya birer bacak. Bacaklar [route] üzerinden hesaplanır — testteki
  /// sahte motor yalnız [route]'u override ederek yolculukları da sahteler.
  /// Herhangi bir bacak bulunamazsa yolculuk YOK (null) — kara yasağı bütünde
  /// geçerlidir; eski rota arayüzde korunur.
  Future<SeaTrip?> trip(GeoPoint origin, List<GeoPoint> waypoints) async {
    if (waypoints.isEmpty) return null;
    final List<SeaRoutePlan> legs = <SeaRoutePlan>[];
    GeoPoint from = origin;
    for (final GeoPoint wp in waypoints) {
      final SeaRoutePlan? leg = await route(from, wp);
      if (leg == null) return null;
      legs.add(leg);
      from = wp;
    }
    return SeaTrip(legs: legs, combined: combineTripLegs(legs));
  }

  /// Tutamaç bırakılan noktayı suya oturtur (karaya bırakılırsa en yakın
  /// denize kayar). Kapsam dışı ya da yakında su yoksa null.
  Future<GeoPoint?> snapWater(GeoPoint p) async {
    final SeaMask? m = await _ensureLoaded();
    if (m == null) return null;
    return nearestWaterCenter(m, p, maxR: 10);
  }
}

/// Motor sağlayıcısı — testte sahte ile override edilir.
final Provider<SeaRouteEngine> seaRouteEngineProvider =
    Provider<SeaRouteEngine>((ref) => SeaRouteEngine());
