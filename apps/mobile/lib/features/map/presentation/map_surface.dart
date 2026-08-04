import 'package:dockly_api/dockly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_viewport.dart';

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
}

/// Harita yüzeyinden gelen etkileşim geri çağrıları.
class MapSurfaceCallbacks {
  const MapSurfaceCallbacks({
    required this.onViewportChanged,
    required this.onPinTap,
    required this.onClusterTap,
  });

  /// Kamera durulunca yeni görünüm (bbox + zoom).
  final void Function(MapViewport viewport) onViewportChanged;
  final void Function(String pinId) onPinTap;
  final void Function(Cluster cluster) onClusterTap;
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
