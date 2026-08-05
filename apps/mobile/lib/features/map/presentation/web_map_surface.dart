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
import '../../route/domain/sea_route.dart' show haversineNm;
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

/// Harita zemini (HARİTA KARARI 2026-08): ESRI_TILE_KEY verilirse ArcGIS
/// statik zemin karoları kullanılır — ayda 2 MİLYON karo ücretsiz, ticari
/// kullanım serbest, aşımda sabit paket yok (MapTiler emekli: 100k kota +
/// ücretsiz pakette ticari yasak + filigran). Stil ESRI_TILE_STYLE ile
/// seçilir; kullanıcı seçimi: arcgis/community. Diğerleri: arcgis/oceans,
/// arcgis/outdoor, arcgis/navigation, arcgis/nova, arcgis/light-gray...
/// Anahtar yoksa OSM'e güvenli düşüş — harita asla boş kalmaz.
const String _tileKey = String.fromEnvironment('ESRI_TILE_KEY');
const String _tileStyle =
    String.fromEnvironment('ESRI_TILE_STYLE', defaultValue: 'arcgis/community');
// PERF: ESRI karoları 512px'tir (belge: "512 x 512px PNG") — aynı ekran
// alanı 4 KAT AZ istekle dolar. flutter_map tarafında tileSize 512 +
// zoomOffset -1 ile ölçek birebir korunur. OSM düşüşü 256'da kalır.
// DİKKAT: ESRI yolu {z}/{y}/{x} sırasıyla ister (satır önce, sütun sonra).
final String _baseTileUrl = _tileKey.isEmpty
    ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
    : 'https://static-map-tiles-api.arcgis.com/arcgis/rest/services/'
        'static-basemap-tiles-service/v1/$_tileStyle/static/tile/{z}/{y}/{x}'
        '?token=$_tileKey';
final double _baseTileSize = _tileKey.isEmpty ? 256 : 512;
final double _baseZoomOffset = _tileKey.isEmpty ? 0 : -1;
final String _attributionText = _tileKey.isEmpty
    ? '© OpenStreetMap katkıcıları · OpenSeaMap'
    : 'Powered by Esri · © OpenStreetMap katkıcıları · OpenSeaMap';

/// KARO FRENİ — iptal-güvenli kısıcı (CI dersi 2026-08): flutter_map'in hazır
/// `TileUpdateTransformers.throttle`'ı abonelik kapanınca zamanlayıcısını
/// İPTAL ETMİYOR; gerçek yüzeyi çizen widget testleri "bekleyen Timer" ile
/// kırmızı yanıyordu. Bu sürüm aynı işi yapar (ilk olay HEMEN geçer, sonrası
/// en çok 250 ms'de bir, sondaki olay kaybolmaz) ama abonelik kapanınca
/// zamanlayıcıyı da söndürür — test/pil güvenli.
final TileUpdateTransformer _throttledTileUpdates =
    StreamTransformer<TileUpdateEvent, TileUpdateEvent>.fromBind(
  (Stream<TileUpdateEvent> input) {
    const Duration interval = Duration(milliseconds: 250);
    late StreamController<TileUpdateEvent> out;
    StreamSubscription<TileUpdateEvent>? sub;
    Timer? timer;
    TileUpdateEvent? trailing;
    void flush() {
      timer = null;
      final TileUpdateEvent? t = trailing;
      trailing = null;
      if (t != null) {
        out.add(t);
        timer = Timer(interval, flush);
      }
    }

    out = StreamController<TileUpdateEvent>(
      sync: true,
      onListen: () {
        sub = input.listen(
          (TileUpdateEvent e) {
            // Dokunuş kamerayı oynatmaz — hazır kısıcıyla birebir eşitlik
            // için dokunuş olayları karo yenilemesi tetiklemez.
            if (e.wasTriggeredByTap()) return;
            if (timer == null) {
              out.add(e);
              timer = Timer(interval, flush);
            } else {
              trailing = e; // aralık dolunca EN SON olay işlenir
            }
          },
          onError: out.addError,
          onDone: out.close,
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        timer?.cancel();
        timer = null;
        return sub?.cancel();
      },
    );
    return out.stream;
  },
);

Widget webMapSurfaceBuilder(
  BuildContext context,
  MapSurfaceData data,
  MapSurfaceCallbacks callbacks,
) {
  return _WebMapSurface(data: data, callbacks: callbacks);
}

/// Bacak boyunca TUTAMAÇ NOKTALARI (kullanıcı dostu sürükleme 2026-08):
/// bacağın MESAFECE eşit aralıklı kesirlerinde 1-5 nokta — uzun bacakta çok
/// tutamaç (çizgi her yerinden yakalanır), kısa bacakta tek, 0,5 nm altında
/// hiç (kalabalık olmaz). Saf işlev — birim testli. Saha dersi: açık denizde
/// sadeleştirilmiş bacak 2 kırıktan oluşabilir; dizin yerine mesafe boyunca
/// enterpolasyon şarttır.
List<GeoPoint> legHandlePoints(List<GeoPoint> pts) {
  if (pts.length < 2) return const <GeoPoint>[];
  final List<double> seg = <double>[];
  double total = 0;
  for (int i = 1; i < pts.length; i++) {
    final double d = haversineNm(pts[i - 1], pts[i]);
    seg.add(d);
    total += d;
  }
  if (total < 0.5) return const <GeoPoint>[];
  final int n = total < 3 ? 1 : (total < 10 ? 3 : 5);
  final List<GeoPoint> out = <GeoPoint>[];
  for (int k = 1; k <= n; k++) {
    double target = total * k / (n + 1);
    GeoPoint? point;
    for (int i = 0; i < seg.length; i++) {
      if (target <= seg[i]) {
        final double f = seg[i] <= 0 ? 0 : target / seg[i];
        final GeoPoint a = pts[i], b = pts[i + 1];
        point = GeoPoint(
          lat: a.lat + (b.lat - a.lat) * f,
          lon: a.lon + (b.lon - a.lon) * f,
        );
        break;
      }
      target -= seg[i];
    }
    out.add(point ?? pts.last);
  }
  return out;
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

/// Süren tutamaç sürüklemesi (ROTA DÜZENLEME 2026-08). Sürükleme boyunca
/// rota YENİDEN HESAPLANMAZ (A* pahalı) — kesikli önizleme çizgisi ve hayalet
/// tutamaç gösterilir; parmak kalkınca kontrolcü gerçek rotayı hesaplar.
class _RouteDrag {
  _RouteDrag({
    required this.isNew,
    required this.index,
    required this.anchorPrev,
    required this.anchorNext,
    required this.screen,
    required this.pos,
  });

  /// true → bacak tutamacı (bırakınca YENİ ara nokta); false → mevcut ara nokta.
  final bool isNew;

  /// isNew: bacak dizini; değilse ara noktanın durumdaki dizini.
  final int index;

  /// Önizleme kesikli çizgisinin sabit uçları (bacağın başı ve sonu).
  final LatLng anchorPrev;
  final LatLng anchorNext;

  /// Sürüklenen noktanın ekran koordinatı (delta'lar buna eklenir).
  math.Point<double> screen;

  /// Sürüklenen noktanın harita koordinatı (ekrandan çevrilir).
  LatLng pos;
}

class _WebMapSurfaceState extends ConsumerState<_WebMapSurface>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  Timer? _debounce;
  double _lastZoom = 7; // _initialZoom ile hizalı; eşik-geçişi tespiti için
  _RouteDrag? _drag;

  /// AÇILIŞ KAMERA İNİŞİ (onaylı E7): bekleyen odak isteğine sinematik uçuş.
  AnimationController? _flight;

  /// Tutamaç üzerinde duran parmak sayısı (MOBİL DÜZELTME 2026-08): parmak
  /// tutamaca değdiği AN haritanın tüm jestleri kilitlenir — sürükleme
  /// haritayla asla yarışmaz ("nokta sürükleme çalışmıyor" kök nedeni:
  /// haritanın kendi jest tanıyıcısı aynı parmağı izleyip haritayı kaydırıyordu).
  int _handleTouches = 0;

  void _handleTouchStart() => setState(() => _handleTouches++);

  void _handleTouchEnd() =>
      setState(() => _handleTouches = _handleTouches > 0 ? _handleTouches - 1 : 0);

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
      // Açılış uçuşu sürüyorsa iptal — kamera çekişmesi olmasın (denetim).
      _flight?.dispose();
      _flight = null;
      // İstek kendi zoom'unu taşıyabilir (bölge odağı 9); yoksa "Konumum"
      // davranışı: en az 12 — tekne imleci tek bakışta seçilsin.
      final double targetZoom = f.zoom ?? math.max(_map.camera.zoom, 12);
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
      // Açılış uçuşu sürüyorsa iptal — rota sığdırmasıyla çekişmesin.
      _flight?.dispose();
      _flight = null;
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
    _flight?.dispose();
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

  // --- ROTA DÜZENLEME: tutamaç sürükleme makinesi -------------------------

  void _startDrag({
    required bool isNew,
    required int index,
    required GeoPoint at,
    required LatLng anchorPrev,
    required LatLng anchorNext,
  }) {
    final LatLng p = LatLng(at.lat, at.lon);
    setState(() {
      _drag = _RouteDrag(
        isNew: isNew,
        index: index,
        anchorPrev: anchorPrev,
        anchorNext: anchorNext,
        screen: _map.camera.latLngToScreenPoint(p),
        pos: p,
      );
    });
  }

  void _updateDrag(Offset delta) {
    final _RouteDrag? d = _drag;
    if (d == null) return;
    setState(() {
      d.screen = math.Point<double>(d.screen.x + delta.dx, d.screen.y + delta.dy);
      d.pos = _map.camera.pointToLatLng(d.screen);
    });
  }

  void _endDrag() {
    final _RouteDrag? d = _drag;
    if (d == null) return;
    final GeoPoint dropped = GeoPoint(lat: d.pos.latitude, lon: d.pos.longitude);
    setState(() => _drag = null);
    if (d.isNew) {
      widget.callbacks.onRouteInsertVia?.call(d.index, dropped);
    } else {
      widget.callbacks.onRouteMoveVia?.call(d.index, dropped);
    }
  }

  void _cancelDrag() {
    if (_drag == null) return;
    setState(() => _drag = null);
  }

  /// Bacak boyundaki tutamaç işaretçileri (KULLANICI DOSTU sürükleme 2026-08:
  /// tek orta nokta yerine bacak uzunluğuna göre 1-5 tutamaç — kaptan çizgiyi
  /// istediği yerinden yakalar; dokunma alanı 44px, mobil parmak standardı).
  List<Marker> _legHandles() {
    final List<List<GeoPoint>>? legs = widget.data.routeLegPoints;
    if (legs == null) return const <Marker>[];
    final List<Marker> out = <Marker>[];
    for (int j = 0; j < legs.length; j++) {
      final List<GeoPoint> pts = legs[j];
      for (final GeoPoint h in legHandlePoints(pts)) {
        out.add(
          Marker(
            point: LatLng(h.lat, h.lon),
            width: 44, // dokunma hedefi (görsel nokta daha küçük çizilir)
            height: 44,
            child: _RouteHandle(
              size: 16,
              onTouchStart: _handleTouchStart,
              onTouchEnd: _handleTouchEnd,
              onDragStart: () => _startDrag(
                isNew: true,
                index: j,
                at: h,
                anchorPrev: LatLng(pts.first.lat, pts.first.lon),
                anchorNext: LatLng(pts.last.lat, pts.last.lon),
              ),
              onDragUpdate: _updateDrag,
              onDragEnd: _endDrag,
              onDragCancel: _cancelDrag,
            ),
          ),
        );
      }
    }
    return out;
  }

  /// Ara nokta sürüklemesi: önizleme uçları = gelen bacağın başı + giden
  /// bacağın sonu.
  void _startViaDrag(MapRouteVia v) {
    final List<List<GeoPoint>>? legs = widget.data.routeLegPoints;
    LatLng prev = LatLng(v.pos.lat, v.pos.lon);
    LatLng next = prev;
    if (legs != null && v.index < legs.length && legs[v.index].isNotEmpty) {
      prev = LatLng(legs[v.index].first.lat, legs[v.index].first.lon);
    }
    if (legs != null && v.index + 1 < legs.length && legs[v.index + 1].isNotEmpty) {
      next = LatLng(legs[v.index + 1].last.lat, legs[v.index + 1].last.lon);
    }
    _startDrag(
      isNew: false,
      index: v.index,
      at: v.pos,
      anchorPrev: prev,
      anchorNext: next,
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

  /// Kuruluşta bekleyen odak isteğini uygular (açılış bölge/konum seçimi).
  /// SİNEMATİK İNİŞ (onaylı E7): kamera geniş Türkiye görünümünden hedefe
  /// 1,2 sn'de easeOutCubic ile süzülür ("uçak inişi" hissi). Hareket
  /// azaltma açıksa animasyonsuz tek adımda gidilir.
  void _applyPendingFocus() {
    final MapFocusRequest? f = widget.data.focus;
    if (f == null) return;
    final double targetZoom = f.zoom ?? math.max(_map.camera.zoom, 12);
    final LatLng target = LatLng(f.point.lat, f.point.lon);
    if (MediaQuery.of(context).disableAnimations) {
      _lastZoom = targetZoom;
      _map.move(target, targetZoom);
      _emit(_map.camera);
      return;
    }
    final LatLng from = _map.camera.center;
    final double fromZoom = _map.camera.zoom;
    _flight?.dispose();
    // HIZ (kullanıcı geri bildirimi): 850 ms + zoom SONA yığılır — uçuşun
    // başında geniş görünümde kaydırılır, yakınlaşma son %70'te olur; ara
    // zoom seviyeleri için boşa karo indirilmez (kasma azalır).
    final AnimationController ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _flight = ctrl;
    ctrl.addListener(() {
      final double t = Curves.easeOutCubic.transform(ctrl.value);
      final double zt = const Interval(0.30, 1.0, curve: Curves.easeOutCubic)
          .transform(ctrl.value);
      _map.move(
        LatLng(
          from.latitude + (target.latitude - from.latitude) * t,
          from.longitude + (target.longitude - from.longitude) * t,
        ),
        fromZoom + (targetZoom - fromZoom) * zt,
      );
    });
    ctrl.addStatusListener((AnimationStatus s) {
      if (s != AnimationStatus.completed) return;
      _lastZoom = targetZoom;
      _emit(_map.camera); // pinler İNİŞ BİTİNCE yüklenir (uçuşta istek yok)
      if (_flight == ctrl) _flight = null;
      ctrl.dispose();
    });
    ctrl.forward();
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
        // MOBİL DÜZELTME (2026-08): parmak bir tutamaçtayken ya da sürükleme
        // sürerken haritanın jestleri TAMAMEN kapatılır — tutamaç sürükleme
        // haritayı kaydırmaz, kesin ve öngörülebilir çalışır.
        interactionOptions: InteractionOptions(
          flags: _handleTouches > 0 || _drag != null
              ? InteractiveFlag.none
              : InteractiveFlag.all,
        ),
        onPositionChanged: _onMove,
        // AÇILIŞ ODAĞI (onaylı tasarım E5, 2026-08): harita kurulmadan ÖNCE
        // verilmiş bir odak isteği varsa (seyir bölgesi seçimi) ilk karede
        // uygulanır. didUpdateWidget yalnız DEĞİŞEN seq'i görür; kuruluşta
        // bekleyen istek ancak burada yakalanır.
        onMapReady: _applyPendingFocus,
        // ROTA PLANLAMA (2026-08): boşluğa dokunuş — BAŞLANGIÇ SEÇ modunda
        // A noktası olur (kontrolcü mod dışında yok sayar).
        onTap: (TapPosition _, LatLng p) => widget.callbacks.onMapTap
            ?.call(GeoPoint(lat: p.latitude, lon: p.longitude)),
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: _baseTileUrl,
          userAgentPackageName: 'app.moorira.mobile',
          tileDisplay: const TileDisplay.instantaneous(),
          tileSize: _baseTileSize,
          zoomOffset: _baseZoomOffset,
          maxZoom: 19,
          // HIZ AYARI (kullanıcı geri bildirimi 2026-08, "geç doluyor/kasıyor"):
          // • panBuffer 0 — 512px karoda görünmez halkayı önceden indirmek
          //   her harekette isteği ikiye katlıyordu; ekran dışı karo beklemesin.
          // • keepBuffer 4 — geri dönüşte eski karolar atılmaz (korundu).
          // • throttle 250 ms — kaydırma/animasyon sırasında karo istekleri
          //   her karede değil saniyede en çok 4 kez tazelenir; açılış
          //   uçuşundaki karo fırtınası ve gezinme kasması kesilir.
          panBuffer: 0,
          keepBuffer: 4,
          tileUpdateTransformer: _throttledTileUpdates,
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
        //
        // SAHA DERSİ (rota düzenleme düzeltmesi): bu iki katman HER ZAMAN
        // ağaçta durur (rota/sürükleme yokken boş liste çizerler). Eskiden
        // `if (...)` ile koşulluydular; sürükleme başlayınca araya katman
        // girmesi çocuk listesini kaydırıyor, Flutter işaretçi katmanını
        // BAŞTAN kuruyor ve aktif sürükleme hareketi ilk karede ölüyordu —
        // "tutamaç hareket etmiyor" bunun sonucuydu. Yapı sabit kalmalı.
        PolylineLayer(
          polylines: <Polyline>[
            if (widget.data.routePoints != null &&
                widget.data.routePoints!.length >= 2)
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
        // SÜRÜKLEME ÖNİZLEMESİ (rota düzenleme): parmak ekrandayken kesikli
        // çizgi — bırakınca gerçek deniz rotası (A*) hesaplanır.
        PolylineLayer(
          polylines: <Polyline>[
            if (_drag != null)
              Polyline(
                points: <LatLng>[_drag!.anchorPrev, _drag!.pos, _drag!.anchorNext],
                strokeWidth: 3.5,
                color: DocklyColors.brandPrimary.withValues(alpha: 0.85),
                // NOT: `const` OLAMAZ — StrokePattern.dashed'in assert'i
                // `segments.length` okur; Dart sabit ifadede liste uzunluğuna
                // erişime izin vermez (CI dersi: const_eval_property_access).
                pattern: StrokePattern.dashed(segments: const <double>[10, 7]),
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
                // AÇILIŞ HİSSİ (onaylı E7): pin İLK göründüğünde küçükten
                // büyüyerek "damlar". Anahtar MARKER'da olmalı — MarkerLayer
                // öğeleri marker anahtarıyla eşler; anahtar çocukta kalırsa
                // her kaydırmada animasyon yeniden oynar (denetim bulgusu).
                key: ValueKey<String>('pin-drop-${p.id}'),
                point: LatLng(p.position.lat, p.position.lon),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  child: _DropIn(
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
              ),
            // --- ROTA DÜZENLEME işaretçileri (pinlerin ÜSTÜNDE) ---
            // A NOKTASI (rota planlama 2026-08): başlangıç GPS değilse rozet.
            if (widget.data.routeOriginBadge != null)
              Marker(
                point: LatLng(
                  widget.data.routeOriginBadge!.lat,
                  widget.data.routeOriginBadge!.lon,
                ),
                width: 28,
                height: 28,
                child: const IgnorePointer(child: _OriginBadge()),
              ),
            // Numaralı DURAK rozetleri (etkileşimsiz — pinin kendisi altta).
            for (final MapRouteStop s in widget.data.routeStops)
              Marker(
                point: LatLng(s.pos.lat, s.pos.lon),
                width: 26,
                height: 26,
                child: IgnorePointer(
                  child: _StopBadge(
                    number: s.number,
                    isLast: s.number == widget.data.routeStops.length,
                  ),
                ),
              ),
            // Bacak tutamaçları: bacağın ortasında küçük beyaz nokta —
            // sürükleyip bırakınca oraya YENİ ara nokta eklenir.
            if (widget.callbacks.onRouteInsertVia != null)
              ..._legHandles(),
            // Ara nokta tutamaçları: sürükle = taşı, dokun = kaldır.
            for (final MapRouteVia v in widget.data.routeVias)
              Marker(
                point: LatLng(v.pos.lat, v.pos.lon),
                width: 48, // ara nokta: en büyük dokunma hedefi (taşı/kaldır)
                height: 48,
                child: _RouteHandle(
                  size: 22,
                  onTouchStart: _handleTouchStart,
                  onTouchEnd: _handleTouchEnd,
                  onTap: () => widget.callbacks.onRouteRemoveVia?.call(v.index),
                  onDragStart: () => _startViaDrag(v),
                  onDragUpdate: _updateDrag,
                  onDragEnd: _endDrag,
                  onDragCancel: _cancelDrag,
                ),
              ),
            // Sürükleme hayaleti: PARMAĞIN ÜSTÜNDE görünür (mobil dostu —
            // işaret parmağın altında kaybolmaz); ince sap gerçek noktayı
            // gösterir, rota tam oradan geçer.
            if (_drag != null)
              Marker(
                point: _drag!.pos,
                width: 44,
                height: 74,
                alignment: Alignment.topCenter,
                child: const IgnorePointer(child: _GhostHandle()),
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
/// Pin "damlama" girişi (onaylı E7): küçükten büyüyerek belirme — TEK yönlü,
/// 260 ms'de biter (tekrar eden animasyon yok; test/pil dostu).
class _DropIn extends StatelessWidget {
  const _DropIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double s, Widget? c) =>
          Transform.scale(scale: s, child: c),
      child: child,
    );
  }
}

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

/// ROTA TUTAMACI (rota düzenleme 2026-08 → MOBİL DÜZELTME): beyaz daire +
/// marka mavisi halka. Jest arenasına GİRMEZ — ham işaretçi (Listener) ile
/// izlenir; parmak değdiği an yüzey haritayı kilitler (onTouchStart), 6px
/// üstü hareket SÜRÜKLEMEDİR, hareketsiz bırakma DOKUNUŞTUR (ara noktada:
/// kaldır). Böylece dokunmatikte sürükleme her zaman ve öngörülebilir çalışır.
class _RouteHandle extends StatefulWidget {
  const _RouteHandle({
    required this.size,
    required this.onTouchStart,
    required this.onTouchEnd,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    this.onTap,
  });

  final double size;
  final VoidCallback onTouchStart;
  final VoidCallback onTouchEnd;
  final VoidCallback onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final VoidCallback? onTap;

  @override
  State<_RouteHandle> createState() => _RouteHandleState();
}

class _RouteHandleState extends State<_RouteHandle> {
  Offset? _down; // işaretçinin indiği küresel nokta
  Offset? _last; // son küresel nokta (delta hesabı)
  bool _dragging = false;

  /// Sürükleme eşiği: bunun altı DOKUNUŞ sayılır (kaldırma), üstü SÜRÜKLEME.
  static const double _slop = 6;

  void _reset() {
    _down = null;
    _last = null;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) {
        _down = e.position;
        _last = e.position;
        _dragging = false;
        widget.onTouchStart(); // harita jestleri ANINDA kilitlenir
      },
      onPointerMove: (PointerMoveEvent e) {
        final Offset? down = _down;
        if (down == null) return;
        if (!_dragging) {
          if ((e.position - down).distance < _slop) return;
          _dragging = true;
          widget.onDragStart();
          widget.onDragUpdate(e.position - down); // biriken ilk kayma
          _last = e.position;
          return;
        }
        widget.onDragUpdate(e.position - (_last ?? e.position));
        _last = e.position;
      },
      onPointerUp: (PointerUpEvent _) {
        final bool wasDrag = _dragging;
        _reset();
        widget.onTouchEnd();
        if (wasDrag) {
          widget.onDragEnd();
        } else {
          widget.onTap?.call();
        }
      },
      onPointerCancel: (PointerCancelEvent _) {
        final bool wasDrag = _dragging;
        _reset();
        widget.onTouchEnd();
        if (wasDrag) widget.onDragCancel();
      },
      child: Center(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: DocklyColors.brandPrimary, width: 3),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x400A2540), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: widget.size >= 18
              ? Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: DocklyColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Sürükleme hayaleti (mobil dostu 2026-08): büyük daire PARMAĞIN ÜSTÜNDE
/// durur, ince sap + uç nokta rotanın GERÇEKTEN geçeceği yeri gösterir —
/// işaret parmağın altında kaybolmaz.
class _GhostHandle extends StatelessWidget {
  const _GhostHandle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: DocklyColors.brandPrimary, width: 4),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x590A2540), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DocklyColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        // Sap: daireden gerçek noktaya inen ince çizgi.
        Container(width: 2.5, height: 32, color: DocklyColors.brandPrimary),
        // Uç: rotanın geçeceği nokta.
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: DocklyColors.brandPrimary,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
          ),
        ),
      ],
    );
  }
}

/// A NOKTASI rozeti (rota planlama): lacivert daire içinde turkuaz "A" —
/// haritadan/koydan seçilen başlangıç.
class _OriginBadge extends StatelessWidget {
  const _OriginBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocklyColors.brandDeep,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x400A2540), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: const Center(
        child: Text(
          'A',
          style: TextStyle(
            color: Color(0xFF7FE3D9),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Numaralı DURAK rozeti: marka mavisi daire içinde sıra numarası (son numara
/// hedef — turkuaz).
class _StopBadge extends StatelessWidget {
  const _StopBadge({required this.number, this.isLast = false});

  final int number;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isLast ? DocklyColors.accentTurquoise : DocklyColors.brandPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x400A2540), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
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
