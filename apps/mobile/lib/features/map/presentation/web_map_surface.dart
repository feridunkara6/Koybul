import 'dart:async';
import 'dart:math' as math;

import 'package:dockly_api/dockly_api.dart' show Bbox, Cluster, GeoPoint, LocationPin;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../domain/map_viewport.dart';
import 'map_surface.dart';

/// Web harita yüzeyi. Mapbox web'de çalışmadığı için tarayıcıda çalışan gerçek
/// bir harita kullanılır: flutter_map + MapTiler yumuşak stil (anahtar varsa)
/// ya da OpenStreetMap karoları (anahtarsız güvenli düşüş).
/// Görsel dil, tasarım sistemi (design/dockly-design-system.html §06 Map
/// Markers) ile birebir: damla-formlu, beyaz konturlu tip-renkli pinler; cam
/// görünümlü dairede sayı taşıyan cluster'lar; seçili pin büyür. Cluster'a
/// dokununca kamera o bölgeye yaklaşır → sunucu tekil pinleri döndürür.

/// Açılışta yüklenecek varsayılan görünüm — Ege–Marmara–İstanbul kıyısı.
/// Her kenar ≤ 5° (sunucu bbox sınırı, docs/23 §9.5) → veri hemen gelir.
const Bbox _initialBbox = Bbox(minLon: 25.9, minLat: 36.6, maxLon: 30.2, maxLat: 41.1);
const int _initialZoom = 7;

/// Harita stili: MAP_TILE_KEY verilirse MapTiler'ın stilleri kullanılır.
/// Varsayılan: aquarelle (suluboya — renkli ama "gerçek harita" hissinden uzak,
/// ürün kararı). MAP_TILE_STYLE ile ör. ocean/dataviz/streets-v2-pastel
/// seçilebilir. Anahtar yoksa OSM'e güvenli düşüş — harita asla boş kalmaz.
const String _tileKey = String.fromEnvironment('MAP_TILE_KEY');
const String _tileStyle =
    String.fromEnvironment('MAP_TILE_STYLE', defaultValue: 'aquarelle');
// PERF (2026-08): MapTiler'da 512px karo kullanılır (URL'de /256/ yok =
// varsayılan 512). Aynı ekran alanı 4 KAT AZ istekle dolar → daha az ağ
// turu, daha az çözme işi, daha akıcı kaydırma. flutter_map tarafında
// tileSize 512 + zoomOffset -1 ile ölçek birebir korunur. OSM düşüşü
// 512 sunmadığı için 256'da kalır.
final String _baseTileUrl = _tileKey.isEmpty
    ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
    : 'https://api.maptiler.com/maps/$_tileStyle/{z}/{x}/{y}.png?key=$_tileKey';
final double _baseTileSize = _tileKey.isEmpty ? 256 : 512;
final double _baseZoomOffset = _tileKey.isEmpty ? 0 : -1;
final String _attributionText = _tileKey.isEmpty
    ? '© OpenStreetMap katkıcıları · OpenSeaMap'
    : '© MapTiler · © OpenStreetMap katkıcıları · OpenSeaMap';

Widget webMapSurfaceBuilder(
  BuildContext context,
  MapSurfaceData data,
  MapSurfaceCallbacks callbacks,
) {
  return _WebMapSurface(data: data, callbacks: callbacks);
}

class _WebMapSurface extends ConsumerStatefulWidget {
  const _WebMapSurface({required this.data, required this.callbacks});

  final MapSurfaceData data;
  final MapSurfaceCallbacks callbacks;

  @override
  ConsumerState<_WebMapSurface> createState() => _WebMapSurfaceState();
}

/// Sunucu pin eşiğinin aynası (apps/api cluster.ts MIN_PIN_ZOOM): zoom ≥ 9 →
/// pin modu. Eşik GEÇİLİRKEN debounce beklenmez — pinler anında istenir.
const int _minPinZoom = 9;

class _WebMapSurfaceState extends ConsumerState<_WebMapSurface> {
  final MapController _map = MapController();
  Timer? _debounce;
  double _lastZoom = 7; // _initialZoom ile hizalı; eşik-geçişi tespiti için

  @override
  void initState() {
    super.initState();
    // Açılışta varsayılan bölgeyi bildir → pinler/cluster'lar yüklensin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.callbacks.onViewportChanged(
        const MapViewport(bbox: _initialBbox, zoom: _initialZoom),
      );
    });
  }

  @override
  void didUpdateWidget(covariant _WebMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "Konumum" odak isteği: seq değiştiyse kamerayı kullanıcının konumuna
    // taşı (en az zoom 12 — tekne imleci tek bakışta seçilsin) ve yeni
    // görünümü bildir (programatik hareket gesture saymaz).
    final MapFocusRequest? f = widget.data.focus;
    if (f != null && f.seq != oldWidget.data.focus?.seq) {
      final double targetZoom = math.max(_map.camera.zoom, 12);
      _lastZoom = targetZoom;
      _map.move(LatLng(f.point.lat, f.point.lon), targetZoom);
      _emit(_map.camera);
    }
    // Yeni deniz rotası: kamera rotanın tamamını görecek şekilde BİR KEZ
    // sığdırılır (sonrasında kullanıcı serbestçe gezebilir).
    final List<GeoPoint>? route = widget.data.routePoints;
    if (route != null &&
        route.length >= 2 &&
        widget.data.routeSeq != oldWidget.data.routeSeq) {
      final LatLngBounds b = LatLngBounds.fromPoints(
        <LatLng>[for (final GeoPoint p in route) LatLng(p.lat, p.lon)],
      );
      _map.fitCamera(
        CameraFit.bounds(
          bounds: b,
          padding: const EdgeInsets.fromLTRB(48, 132, 48, 228),
          maxZoom: 13,
        ),
      );
      _lastZoom = _map.camera.zoom;
      _emit(_map.camera);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // Kullanıcı haritayı gezdirince, durulmasını bekleyip (kısa debounce) yeni
  // görünür alanı bildir. Sunucu limiti gereği her kenar ≤ 5°'ye kırpılır.
  // İSTİSNA: zoom pin eşiğini (10) GEÇERKEN hiç beklenmez — balonlardan pinlere
  // geçiş isteği parmak daha ekrandayken atılır, pinler gecikmeden dağılır.
  void _onMove(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    final bool crossedPinThreshold =
        (_lastZoom.round() >= _minPinZoom) != (camera.zoom.round() >= _minPinZoom);
    _lastZoom = camera.zoom;
    _debounce?.cancel();
    if (crossedPinThreshold) {
      _emit(camera);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () => _emit(camera));
  }

  void _emit(MapCamera camera) {
    if (!mounted) return;
    final LatLngBounds b = camera.visibleBounds;
    const double maxSpan = 5.0;
    double west = b.west, east = b.east, south = b.south, north = b.north;
    final double cLon = (west + east) / 2, cLat = (south + north) / 2;
    if (east - west > maxSpan) {
      west = cLon - maxSpan / 2;
      east = cLon + maxSpan / 2;
    }
    if (north - south > maxSpan) {
      south = cLat - maxSpan / 2;
      north = cLat + maxSpan / 2;
    }
    widget.callbacks.onViewportChanged(
      MapViewport(
        bbox: Bbox(minLon: west, minLat: south, maxLon: east, maxLat: north),
        zoom: camera.zoom.round(),
      ),
    );
  }

  /// Cluster'a dokununca: kontrolcüye haber ver + kamerayı o bölgeye yaklaştır,
  /// ardından yeni görünümü bildir (programatik hareket onPositionChanged'te
  /// hasGesture=false geldiği için elle emit edilir).
  void _onClusterTap(Cluster c) {
    widget.callbacks.onClusterTap(c);
    // Pin eşiği 10 olduğundan hedef en az 10.5 — baloncuğa dokunuş her zaman
    // tekil pin bölgesine indirir (bir kez daha dokunma gereği kalmaz).
    final double targetZoom = math.min(math.max(_map.camera.zoom + 2.5, 9.5), 14.0);
    _lastZoom = targetZoom; // programatik hareket — eşik-geçiş takibi güncel kalsın
    _map.move(LatLng(c.position.lat, c.position.lon), targetZoom);
    _emit(_map.camera);
  }

  @override
  Widget build(BuildContext context) {
    // Tekne tanımlıysa pinlerde uyum rozeti gösterilir (wow kişiselleştirme).
    final MyBoat? boat = ref.watch(myBoatProvider);
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        // Karo gelene dek gri yerine DENİZ tonu — "bozuk görünüm" hissini keser.
        backgroundColor: DocklyMapColors.seaBackground,
        initialCenter: const LatLng(38.85, 28.05),
        initialZoom: _initialZoom.toDouble(),
        minZoom: 4,
        maxZoom: 18,
        onPositionChanged: _onMove,
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: _baseTileUrl,
          userAgentPackageName: 'app.moorira.mobile',
          tileDisplay: const TileDisplay.instantaneous(),
          tileSize: _baseTileSize,
          zoomOffset: _baseZoomOffset,
          maxZoom: 19,
          // Perf: kaydırırken bir halka komşu karo önceden yüklenir; geri
          // dönüşte karo atılmasın diye tampon büyütüldü → akıcı gezinme.
          panBuffer: 1,
          keepBuffer: 4,
        ),
        // Denizcilik katmanı: OpenSeaMap seamark'ları (şamandıra, fener, liman
        // işaretleri) — açık lisanslı, jetonsuz. Şeffaf bindirme. Perf: işaretler
        // ancak yakın zoom'da çizildiğinden katman zoom ≥ 9'da yüklenir — uzak
        // görünümde her karede boş karo indirme maliyeti sıfırlanır.
        Builder(
          builder: (BuildContext context) {
            if (MapCamera.of(context).zoom < 9) return const SizedBox.shrink();
            return TileLayer(
              urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.moorira.mobile',
              tileDisplay: const TileDisplay.instantaneous(),
              maxZoom: 18,
            );
          },
        ),
        // AKILLI DENİZ ROTASI (2026-08): karaları tanıyan rota çizgisi —
        // beyaz kontur + marka mavisi; işaretçilerin ALTINDA kalır.
        if (widget.data.routePoints != null && widget.data.routePoints!.length >= 2)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: <LatLng>[
                  for (final GeoPoint p in widget.data.routePoints!)
                    LatLng(p.lat, p.lon),
                ],
                strokeWidth: 4,
                color: DocklyColors.brandPrimary,
                borderColor: const Color(0xFFFFFFFF),
                borderStrokeWidth: 1.6,
              ),
            ],
          ),
        MarkerLayer(
          markers: <Marker>[
            // KULLANICININ KONUMU — yelkenli imleç (kullanıcı isteği): beyaz
            // halkalı marka mavisi tekne. En altta eklenmez; pinlerden önce
            // çizilir ki liman pinlerine dokunuş engellenmesin.
            if (widget.data.devicePosition != null)
              Marker(
                point: LatLng(
                  widget.data.devicePosition!.lat,
                  widget.data.devicePosition!.lon,
                ),
                width: 52,
                height: 52,
                child: const RepaintBoundary(child: _DeviceBoatMarker()),
              ),
            // Cluster'lar — ÜLKE renkli baloncukta sayı + ülke kodu; kalabalık
            // büyür, dokununca yaklaşır. (TR mavi, GR turkuaz.)
            for (final Cluster c in widget.data.clusters)
              Marker(
                point: LatLng(c.position.lat, c.position.lon),
                width: 64,
                height: 64,
                // RepaintBoundary (perf): kamera oynarken işaretçiler yeniden
                // boyanmaz — kendi katmanlarında taşınır.
                child: RepaintBoundary(
                  child: _ClusterMarker(
                    count: c.count,
                    countryCode: c.countryCode,
                    onTap: () => _onClusterTap(c),
                  ),
                ),
              ),
            // Tekil pinler — damla form, tip rengi, beyaz kontur + beyaz ikon.
            // Damlanın ucu koordinata basar (alignment: topCenter).
            for (final LocationPin p in widget.data.pins)
              Marker(
                point: LatLng(p.position.lat, p.position.lon),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  child: _PinMarker(
                    type: p.type,
                    selected: p.id == widget.data.selectedPinId,
                    fit: computeBoatFit(
                      boat: boat,
                      maxBoatLengthM: p.maxBoatLengthM,
                      maxDraftM: p.maxDraftM,
                    ),
                    onTap: () => widget.callbacks.onPinTap(p.id),
                  ),
                ),
              ),
          ],
        ),
        // Yasal atıf: OSM karoları + OpenSeaMap katmanı (ODbL/CC — zorunlu).
        const _MapAttribution(),
      ],
    );
  }
}

/// Kullanıcının konum imleci — YELKENLİ (tasarım dili: beyaz konturlu marka
/// mavisi). Dış halka yumuşak mavi hare; iç beyaz dairede yelkenli ikonu.
/// Dokunulamaz (arkadaki pinleri engellemez) — salt gösterge.
class _DeviceBoatMarker extends StatelessWidget {
  const _DeviceBoatMarker();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DocklyColors.brandPrimary.withValues(alpha: 0.18),
        ),
        padding: const EdgeInsets.all(7),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFFFFF),
            border: Border.all(color: DocklyColors.brandPrimary, width: 2.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x400A2540), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: DocklyIcon(
              DocklyIcons.sailing,
              size: 20,
              color: DocklyColors.brandPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sağ-alt köşede zorunlu kaynak atfı (ODbL/CC): yarı saydam şerit üstünde
/// küçük metin. Harici bileşen yerine yerli — davranışı tamamen bizde.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xB3FFFFFF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _attributionText,
          style: const TextStyle(fontSize: 10, color: Color(0xFF0A2540)),
        ),
      ),
    );
  }
}

/// Damla-formlu liman pini (tasarım §06): tip rengi zemin, 2.5px beyaz kontur,
/// içinde beyaz tip ikonu; seçiliyse %25 büyür. Tekne tanımlıysa sağ-üstte
/// uyum rozeti: yeşil = sığar, turuncu = sığmayabilir (bilinmiyorsa rozet yok).
class _PinMarker extends StatelessWidget {
  const _PinMarker({
    required this.type,
    required this.selected,
    required this.onTap,
    this.fit = BoatFit.unknown,
  });

  final String type;
  final bool selected;
  final VoidCallback onTap;
  final BoatFit fit;

  @override
  Widget build(BuildContext context) {
    final Color color = DocklyMapColors.forType(type);
    final double s = selected ? 40 : 32;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          if (fit != BoatFit.unknown)
            Positioned(
              right: 0,
              top: 0,
              child: _FitDot(fits: fit == BoatFit.fits),
            ),
          _pinBody(color, s),
        ].reversed.toList(growable: false),
      ),
    );
  }

  Widget _pinBody(Color color, double s) {
    return Center(
        child: Transform.rotate(
          // CSS eşleniği: rotate(-45deg) → damlanın ucu (bottomLeft) aşağı bakar.
          angle: -math.pi / 4,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(s / 2),
                topRight: Radius.circular(s / 2),
                bottomRight: Radius.circular(s / 2),
                bottomLeft: const Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFFFFFFFF), width: 2.5),
              // Hafif gölge (perf: yüksek blur yüzlerce pinde kasmaya yol açar).
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x400A2540), blurRadius: 5, offset: Offset(0, 3)),
              ],
            ),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Center(
                child: DocklyIcon(
                  DocklyIcons.forLocationType(type),
                  size: s * 0.48,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

/// Pin köşesindeki uyum rozeti: yeşil (sığar) / turuncu (sığmayabilir), beyaz
/// konturlu küçük daire — haritada tek bakışta uygunluk.
class _FitDot extends StatelessWidget {
  const _FitDot({required this.fits});

  final bool fits;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: fits ? DocklyColors.success : DocklyColors.warning,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
      ),
      child: Center(
        child: DocklyIcon(
          fits ? DocklyIcons.checkCircle : DocklyIcons.errorOutline,
          size: 9,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

/// Cluster işaretçisi — KİBAR/PASTEL tasarım: açık pastel dolgu üstünde ülkeye
/// göre canlı halka + sayı (TR mavi, GR turkuaz; tasarım §06 cam baloncuk dili).
/// Koyu dolgu yok — harita üstünde yumuşak durur, sayı yüksek kontrastla okunur.
/// Kalabalık bölge daha büyük baloncuk (<10 → 40, <50 → 50, 50+ → 60).
/// Dokununca kamera bölgeye yaklaşır.
class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.count,
    required this.onTap,
    this.countryCode = '',
  });

  final int count;
  final VoidCallback onTap;
  final String countryCode;

  @override
  Widget build(BuildContext context) {
    final double s = count >= 50 ? 60 : (count >= 10 ? 50 : 40);
    // Ülke → renk eşlemesi tasarım paketinde (ham hex yasak — docs/09 §0).
    final Color fill = DocklyMapColors.clusterFillColorForCountry(countryCode);
    final Color accent = DocklyMapColors.clusterAccentColorForCountry(countryCode);
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
            // Hafif gölge (perf: düşük blur — yüzlerce işaretçide fark eder).
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x2E0A2540), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: s * 0.30,
                  height: 1.05,
                  color: accent,
                ),
              ),
              if (countryCode.isNotEmpty)
                Text(
                  countryCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: s * 0.16,
                    height: 1.0,
                    letterSpacing: 0.6,
                    color: accent.withValues(alpha: 0.72),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
