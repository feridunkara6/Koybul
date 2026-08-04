import 'package:dockly_api/dockly_api.dart' show GeoPoint;

import 'sea_trip.dart';

/// KAYITLI ROTA (rota planlama 2026-08, kullanıcı onaylı). Dürüstlük kararı:
/// çizginin fotoğrafı DEĞİL, başlangıç + ara noktalar saklanır — "Haritada aç"
/// rotayı aynı motorla YENİDEN hesaplar. Kıyı verisi güncellense bile kayıtlı
/// rota asla eski/riskli bir çizgi göstermez; mesafe/süre yalnız listede
/// bilgi amaçlı özettir.
class SavedRoute {
  const SavedRoute({
    required this.id,
    required this.name,
    required this.origin,
    required this.waypoints,
    required this.distanceNm,
    required this.savedAtMs,
  });

  final String id;
  final String name;
  final RouteOrigin origin;
  final List<RouteWaypoint> waypoints;

  /// Kayıt anındaki toplam mesafe (liste özeti — açılışta yeniden hesaplanır).
  final double distanceNm;

  /// Kayıt zamanı (epoch ms) — sıralama için.
  final int savedAtMs;

  int get stopCount => waypoints.where((RouteWaypoint w) => w.isStop).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'origin': <String, dynamic>{
          'lat': origin.pos.lat,
          'lon': origin.pos.lon,
          if (origin.name != null) 'name': origin.name,
          'device': origin.isDevice,
        },
        'wps': <Map<String, dynamic>>[
          for (final RouteWaypoint w in waypoints)
            <String, dynamic>{
              'lat': w.pos.lat,
              'lon': w.pos.lon,
              if (w.id != null) 'id': w.id,
              if (w.name != null) 'name': w.name,
            },
        ],
        'nm': distanceNm,
        'at': savedAtMs,
      };

  /// Bozuk kayıt → null (sürüm/veri hatası kullanıcıya çökme olarak dönmez).
  static SavedRoute? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      final Map<String, dynamic> o = raw['origin'] as Map<String, dynamic>;
      final List<RouteWaypoint> wps = <RouteWaypoint>[
        for (final Object? e in raw['wps'] as List<dynamic>)
          RouteWaypoint(
            pos: GeoPoint(
              lat: (((e as Map<String, dynamic>)['lat']) as num).toDouble(),
              lon: (e['lon'] as num).toDouble(),
            ),
            id: e['id'] as String?,
            name: e['name'] as String?,
          ),
      ];
      if (wps.isEmpty) return null;
      return SavedRoute(
        id: raw['id'] as String,
        name: raw['name'] as String,
        origin: RouteOrigin(
          pos: GeoPoint(
            lat: (o['lat'] as num).toDouble(),
            lon: (o['lon'] as num).toDouble(),
          ),
          name: o['name'] as String?,
          isDevice: o['device'] as bool? ?? false,
        ),
        waypoints: wps,
        distanceNm: (raw['nm'] as num).toDouble(),
        savedAtMs: (raw['at'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Kayıt adı önerisi: "Başlangıç → Hedef" (koy adları; serbest başlangıçta
/// çağıran yerelleştirilmiş "Konumum"/"Seçilen nokta" etiketini verir).
String suggestRouteName(String originLabel, List<RouteWaypoint> waypoints) {
  final String dest = waypoints.isEmpty
      ? ''
      : (waypoints.last.name ?? '');
  return dest.isEmpty ? originLabel : '$originLabel → $dest';
}

/// Kayıtlı rota deposu — en iyi çaba (bozuk depo asla fırlatmaz).
abstract interface class SavedRoutesStore {
  Future<List<SavedRoute>> load();
  Future<void> save(List<SavedRoute> routes);
}
