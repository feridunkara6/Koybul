import 'package:dockly_api/dockly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_viewport.dart';

/// Rota üzerindeki ARA NOKTA işaretçisi (rota düzenleme 2026-08): tutamaçla
/// eklenen serbest nokta. [index] durum listesindeki ara nokta dizinidir.
class MapRouteVia {
  const MapRouteVia({required this.index, required this.pos});

  final int index;
  final GeoPoint pos;
}

/// Rota DURAK işaretçisi: numaralı koy rozeti (1, 2, …; son numara hedef).
class MapRouteStop {
  const MapRouteStop({required this.number, required this.pos});

  final int number;
  final GeoPoint pos;
}

/// Harita yüzeyine çizilecek veri (marker/cluster + seçim + kullanıcı konumu).
class MapSurfaceData {
  const MapSurfaceData({
    required this.pins,
    required this.clusters,
    required this.selectedPinId,
    this.devicePosition,
    this.focus,
    this.routePoints,
    this.routeSeq = 0,
    this.routeLegPoints,
    this.routeVias = const <MapRouteVia>[],
    this.routeStops = const <MapRouteStop>[],
  });

  final List<LocationPin> pins;
  final List<Cluster> clusters;
  final String? selectedPinId;

  /// Kullanıcının GPS konumu — doluysa haritada TEKNE imleci çizilir.
  final GeoPoint? devicePosition;

  /// Kameraya "bu noktaya git" isteği (seq artınca uygulanır).
  final MapFocusRequest? focus;

  /// Çizili deniz rotası kırıklıkları (null = rota yok).
  final List<GeoPoint>? routePoints;

  /// Yeni rotada artar — yüzey kamerayı rotaya bir kez sığdırır.
  final int routeSeq;

  /// Bacak bacak rota kırıklıkları (rota düzenleme): her bacağın ortasına
  /// sürüklenebilir tutamaç konur. null/boş = tutamaç çizilmez.
  final List<List<GeoPoint>>? routeLegPoints;

  /// Serbest ara noktalar — sürüklenerek taşınır, dokununca kaldırılır.
  final List<MapRouteVia> routeVias;

  /// Numaralı duraklar (görsel rozet; etkileşimsiz).
  final List<MapRouteStop> routeStops;
}

/// Harita yüzeyinden gelen etkileşim geri çağrıları.
class MapSurfaceCallbacks {
  const MapSurfaceCallbacks({
    required this.onViewportChanged,
    required this.onPinTap,
    required this.onClusterTap,
    this.onRouteInsertVia,
    this.onRouteMoveVia,
    this.onRouteRemoveVia,
  });

  /// Kamera durulunca yeni görünüm (bbox + zoom).
  final void Function(MapViewport viewport) onViewportChanged;
  final void Function(String pinId) onPinTap;
  final void Function(Cluster cluster) onClusterTap;

  /// Bacak tutamacı bırakıldı → o bacağa yeni ara nokta (rota düzenleme).
  final void Function(int legIndex, GeoPoint pos)? onRouteInsertVia;

  /// Ara nokta yeni yerine bırakıldı.
  final void Function(int wpIndex, GeoPoint pos)? onRouteMoveVia;

  /// Ara noktaya dokunuldu → kaldır.
  final void Function(int wpIndex)? onRouteRemoveVia;
}

/// Somut harita yüzeyini üreten fabrika — prod'da Mapbox (4.3b), testte sahte.
/// Kontrolcü mantığı bu soyutlamanın arkasında somut haritadan bağımsızdır.
typedef MapSurfaceBuilder = Widget Function(
  BuildContext context,
  MapSurfaceData data,
  MapSurfaceCallbacks callbacks,
);

/// Varsayılan yüzey — Mapbox 4.3b'de bağlanana dek bilgilendirici placeholder.
/// (Bootstrap 4.3b'de gerçek Mapbox yüzeyiyle override eder.)
final Provider<MapSurfaceBuilder> mapSurfaceBuilderProvider =
    Provider<MapSurfaceBuilder>(
  (ref) => (BuildContext context, MapSurfaceData data, MapSurfaceCallbacks callbacks) =>
      const _PlaceholderMapSurface(),
);

class _PlaceholderMapSurface extends StatelessWidget {
  const _PlaceholderMapSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE9EEF2),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Harita, Mapbox bağlandığında burada görünecek.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
