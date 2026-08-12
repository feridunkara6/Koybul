import 'dart:async';

import 'package:dockly_api/dockly_api.dart' show Bbox, Cluster, LocationPin;
import 'package:dockly_ui/dockly_ui.dart' show DocklyMapColors;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../domain/map_viewport.dart';
import 'map_surface.dart';

/// Gerçek Mapbox harita yüzeyi (docs/13 §5.1) — `MapSurface` soyutlamasını uygular.
/// Erişim token'ı bootstrap'ta `MapboxOptions.setAccessToken` ile verilir (repoya
/// gömülmez, `--dart-define` ile gelir). Pin'ler daire, cluster'lar sayı balonu.
///
/// Render stratejisi (Faz B.2 → PERF turu 2026-08, "kaydırınca kasıyor"):
/// 1. FARK (diff): eklenen pin yaratılır, kaybolan silinir, yalnız seçim durumu
///    değişen pin yeniden çizilir — O(değişen), O(hepsi) değil.
/// 2. TOPLU ÇAĞRI: yaratmalar `createMulti` ile TEK platform çağrısında gider.
///    Eskiden her pin için ayrı `await create(...)` vardı — 150 pinlik bir
///    görünümde 150 ardışık platform gidiş-dönüşü, tam gezinme sırasında ana
///    iş parçacığını meşgul ediyordu (kasmanın yerli kaynağı).
/// 3. KÜME AYRI YÖNETİCİDE: cluster'lar kendi manager'ında yaşar → topluca
///    `deleteAll` + `createMulti` (pinlere dokunmadan). Üstelik küme listesi
///    DEĞİŞMEDİYSE hiç dokunulmaz — eskiden her render'da (ör. bir pine
///    dokununca bile) tüm balonlar tek tek silinip yeniden yaratılıyordu.
/// 4. DEĞİŞMEYEN KARE: pinler, seçim ve kümeler aynıysa render hiç koşmaz.
/// Ayrıca eşzamanlılık kilidi iç içe render'ları (hayalet marker) önler; dispose
/// sonrası asenkron çağrılar `_disposed` ile susturulur (native kaynak/çökme koruması).
class MapboxMapSurface extends StatefulWidget {
  const MapboxMapSurface({required this.data, required this.callbacks, super.key});

  final MapSurfaceData data;
  final MapSurfaceCallbacks callbacks;

  @override
  State<MapboxMapSurface> createState() => _MapboxMapSurfaceState();
}

class _MapboxMapSurfaceState extends State<MapboxMapSurface> {
  MapboxMap? _map;
  CircleAnnotationManager? _circles; // pinler
  CircleAnnotationManager? _clusterCircles; // küme balonları (ayrı yönetici)
  PointAnnotationManager? _labels; // küme sayıları

  /// pinId → çizili annotation (fark için).
  final Map<String, CircleAnnotation> _pinAnnotations = <String, CircleAnnotation>{};

  /// annotationId → pinId (dokunma çözümü için).
  final Map<String, String> _annotationToPin = <String, String>{};

  final Map<String, Cluster> _annotationToCluster = <String, Cluster>{};

  /// Son çizilen küme listesi — değişmediyse kümelere HİÇ dokunulmaz (perf).
  List<Cluster> _lastClusters = const <Cluster>[];

  String? _lastSelectedPinId;
  bool _rendering = false;
  bool _renderQueued = false;
  bool _disposed = false;
  Timer? _idleTimer;

  /// Türkiye merkezli açılış görünümü (düşük zoom → cluster modu).
  static final CameraOptions _initialCamera = CameraOptions(
    center: Point(coordinates: Position(35.2, 39.0)),
    zoom: 5,
  );

  @override
  void didUpdateWidget(covariant MapboxMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_render());
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _map = null;
    _circles = null;
    _clusterCircles = null;
    _labels = null;
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.setCamera(_initialCamera);
    if (_disposed) return;
    _circles = await map.annotations.createCircleAnnotationManager();
    _clusterCircles = await map.annotations.createCircleAnnotationManager();
    _labels = await map.annotations.createPointAnnotationManager();
    if (_disposed) return;
    _circles!.tapEvents(onTap: _onPinCircleTap);
    _clusterCircles!.tapEvents(onTap: _onClusterCircleTap);
    await _render();
  }

  void _onPinCircleTap(CircleAnnotation annotation) {
    final String? pinId = _annotationToPin[annotation.id];
    if (pinId != null) widget.callbacks.onPinTap(pinId);
  }

  void _onClusterCircleTap(CircleAnnotation annotation) {
    final Cluster? cluster = _annotationToCluster[annotation.id];
    if (cluster != null) {
      widget.callbacks.onClusterTap(cluster);
      unawaited(_flyToCluster(cluster));
    }
  }

  /// Kamera hareket edince (debounce sonrası) görünen bbox + zoom bildirilir.
  void _onCameraChanged(CameraChangedEventData data) {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 350), _reportViewport);
  }

  Future<void> _reportViewport() async {
    final MapboxMap? map = _map;
    if (map == null || _disposed) return;
    final CameraState camera = await map.getCameraState();
    if (_disposed) return;
    final CoordinateBounds bounds = await map.coordinateBoundsForCamera(
      CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        bearing: camera.bearing,
        pitch: camera.pitch,
      ),
    );
    if (_disposed) return;
    final Position sw = bounds.southwest.coordinates;
    final Position ne = bounds.northeast.coordinates;
    widget.callbacks.onViewportChanged(
      MapViewport(
        bbox: Bbox(
          minLon: sw.lng.toDouble(),
          minLat: sw.lat.toDouble(),
          maxLon: ne.lng.toDouble(),
          maxLat: ne.lat.toDouble(),
        ),
        zoom: camera.zoom.round(),
      ),
    );
  }

  Future<void> _flyToCluster(Cluster cluster) async {
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(cluster.position.lon, cluster.position.lat)),
        zoom: 12,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  /// Eşzamanlılık kilidi: aynı anda tek render koşar; sırasında gelen istek tek
  /// bir ek tur olarak kuyruğa alınır (iç içe render → hayalet marker önlenir).
  Future<void> _render() async {
    if (_disposed) return;
    if (_rendering) {
      _renderQueued = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _renderQueued = false;
        await _renderOnce();
      } while (_renderQueued && !_disposed);
    } finally {
      _rendering = false;
    }
  }

  /// İki küme listesi aynı sahneyi mi anlatıyor? (Konum + sayı + ülke.)
  static bool _sameClusters(List<Cluster> a, List<Cluster> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final Cluster x = a[i], y = b[i];
      if (x.count != y.count ||
          x.countryCode != y.countryCode ||
          x.position.lat != y.position.lat ||
          x.position.lon != y.position.lon) {
        return false;
      }
    }
    return true;
  }

  Future<void> _renderOnce() async {
    final CircleAnnotationManager? circles = _circles;
    final CircleAnnotationManager? clusterCircles = _clusterCircles;
    final PointAnnotationManager? labels = _labels;
    if (circles == null || clusterCircles == null || labels == null || _disposed) {
      return;
    }

    final MapSurfaceData data = widget.data;
    final String? selectedId = data.selectedPinId;

    // --- PINLER: fark uygula ---
    final Set<String> newPinIds = <String>{for (final LocationPin p in data.pins) p.id};

    // DEĞİŞMEYEN KARE: pin kümesi, seçim ve kümeler aynıysa hiç dokunma —
    // ekran her yeniden kurulduğunda (alt kart, şerit, konum güncellemesi)
    // platforma boşuna tek çağrı bile gitmesin.
    final bool pinsUnchanged = newPinIds.length == _pinAnnotations.length &&
        newPinIds.every(_pinAnnotations.containsKey);
    if (pinsUnchanged &&
        selectedId == _lastSelectedPinId &&
        _sameClusters(data.clusters, _lastClusters)) {
      return;
    }

    // Kaybolan pinleri sil. ÇOK pin kaybolduysa (görünüm değişti) tek tek
    // platform çağrısı yerine sıfırdan kurmak daha ucuz: deleteAll (1 çağrı)
    // + createMulti (1 çağrı).
    final List<String> goneIds =
        _pinAnnotations.keys.where((String id) => !newPinIds.contains(id)).toList();
    final bool rebuildAll = goneIds.length > 20;
    if (rebuildAll) {
      await circles.deleteAll();
      if (_disposed) return;
      _pinAnnotations.clear();
      _annotationToPin.clear();
    } else {
      for (final String id in goneIds) {
        final CircleAnnotation? ann = _pinAnnotations.remove(id);
        if (ann != null) {
          _annotationToPin.remove(ann.id);
          await circles.delete(ann);
          if (_disposed) return;
        }
      }
      // Seçim durumu değişen pinleri düşür — aşağıda toplu yaratılırlar.
      // (CI düzeltmesi: eleman tipi String? — eski ya da yeni seçim null
      // olabilir, örneğin seçim ilk kez yapılırken.)
      if (selectedId != _lastSelectedPinId) {
        for (final String? id in <String?>[selectedId, _lastSelectedPinId]) {
          final CircleAnnotation? ann = id == null ? null : _pinAnnotations.remove(id);
          if (ann != null) {
            _annotationToPin.remove(ann.id);
            await circles.delete(ann);
            if (_disposed) return;
          }
        }
      }
    }

    // Eksik pinleri TEK toplu çağrıyla yarat.
    final List<LocationPin> toCreate = <LocationPin>[
      for (final LocationPin pin in data.pins)
        if (!_pinAnnotations.containsKey(pin.id)) pin,
    ];
    if (toCreate.isNotEmpty) {
      final List<CircleAnnotationOptions> options = <CircleAnnotationOptions>[
        for (final LocationPin pin in toCreate)
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(pin.position.lon, pin.position.lat)),
            // Dolgu = location_type kanonik rengi (docs/09 §1.4); seçili pin
            // 1.3× ölçek + beyaz halka (renk değişmez — renk tip anlamına rezerve).
            circleColor: DocklyMapColors.argbForType(pin.type),
            circleRadius: pin.id == selectedId ? 9.1 : 7.0,
            circleStrokeColor: DocklyMapColors.strokeArgb,
            circleStrokeWidth: 2.0,
          ),
      ];
      final List<CircleAnnotation?> created = await circles.createMulti(options);
      if (_disposed) return;
      for (int i = 0; i < toCreate.length && i < created.length; i++) {
        final CircleAnnotation? ann = created[i];
        if (ann == null) continue;
        _pinAnnotations[toCreate[i].id] = ann;
        _annotationToPin[ann.id] = toCreate[i].id;
      }
    }

    // --- KÜMELER: yalnız DEĞİŞTİLERSE topluca yenile ---
    if (!_sameClusters(data.clusters, _lastClusters)) {
      _annotationToCluster.clear();
      await clusterCircles.deleteAll();
      if (_disposed) return;
      await labels.deleteAll();
      if (_disposed) return;
      if (data.clusters.isNotEmpty) {
        final List<CircleAnnotation?> anns = await clusterCircles.createMulti(
          <CircleAnnotationOptions>[
            for (final Cluster cluster in data.clusters)
              CircleAnnotationOptions(
                geometry: Point(
                    coordinates:
                        Position(cluster.position.lon, cluster.position.lat)),
                // Kibar/pastel baloncuk: açık dolgu + ülkeye göre canlı halka
                // (TR mavi, GR turkuaz) — web ile aynı semantik.
                circleColor:
                    DocklyMapColors.clusterFillArgbForCountry(cluster.countryCode),
                circleRadius: 18.0,
                circleStrokeColor:
                    DocklyMapColors.clusterAccentArgbForCountry(cluster.countryCode),
                circleStrokeWidth: 2.0,
              ),
          ],
        );
        if (_disposed) return;
        for (int i = 0; i < data.clusters.length && i < anns.length; i++) {
          final CircleAnnotation? ann = anns[i];
          if (ann != null) _annotationToCluster[ann.id] = data.clusters[i];
        }
        await labels.createMulti(
          <PointAnnotationOptions>[
            for (final Cluster cluster in data.clusters)
              PointAnnotationOptions(
                geometry: Point(
                    coordinates:
                        Position(cluster.position.lon, cluster.position.lat)),
                textField: '${cluster.count}',
                // Açık pastel dolguda okunması için sayı vurgu renginde.
                textColor:
                    DocklyMapColors.clusterAccentArgbForCountry(cluster.countryCode),
                textSize: 12.0,
              ),
          ],
        );
        if (_disposed) return;
      }
      _lastClusters = data.clusters;
    }

    _lastSelectedPinId = selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey<String>('dockly-mapbox'),
      onMapCreated: _onMapCreated,
      onCameraChangeListener: _onCameraChanged,
    );
  }
}

/// `mapSurfaceBuilderProvider` override'ında kullanılan gerçek yüzey fabrikası.
Widget mapboxMapSurfaceBuilder(
  BuildContext context,
  MapSurfaceData data,
  MapSurfaceCallbacks callbacks,
) =>
    MapboxMapSurface(data: data, callbacks: callbacks);
