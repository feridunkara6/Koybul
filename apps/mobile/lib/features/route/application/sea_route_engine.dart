import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sea_mask.dart';
import '../domain/sea_router.dart';

/// Deniz rotası motoru — maskeyi bir kez yükler, sonra bellekten hesaplar.
/// Maske yüklenemezse ya da noktalar kapsam dışıysa null döner; çağıran
/// kuş uçuşu yedeğine düşer (akış asla kırılmaz). Testler sahtesiyle
/// override eder (bkz. seaRouteEngineProvider).
class SeaRouteEngine {
  SeaMask? _mask;
  bool _loadTried = false;

  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async {
    if (_mask == null && !_loadTried) {
      _loadTried = true;
      _mask = await SeaMask.load();
    }
    final SeaMask? m = _mask;
    if (m == null) return null;
    return planSeaRoute(m, from, to);
  }
}

/// Motor sağlayıcısı — testte sahte ile override edilir.
final Provider<SeaRouteEngine> seaRouteEngineProvider =
    Provider<SeaRouteEngine>((ref) => SeaRouteEngine());
