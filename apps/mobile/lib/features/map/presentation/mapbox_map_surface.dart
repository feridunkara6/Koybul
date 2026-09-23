import 'dart:async';
import 'dart:typed_data';

import 'package:dockly_api/dockly_api.dart'
    show Bbox, Cluster, GeoPoint, LocationPin;
import 'package:dockly_ui/dockly_ui.dart' show DocklyIconData, DocklyMapColors;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../domain/map_viewport.dart';
import 'map_pin_images.dart';
import 'map_surface.dart';

/// Gerçek Mapbox harita yüzeyi (docs/13 §5.1) — `MapSurface` soyutlamasını uygular.
/// Erişim token'ı bootstrap'ta `MapboxOptions.setAccessToken` ile verilir (repoya
/// gömülmez, `--dart-define` ile gelir). Pin'ler tip rozetidir (tip renginde
/// daire + beyaz tip glifi — bkz. map_pin_images.dart), cluster'lar sayı balonu.
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
  PointAnnotationManager? _pins; // pin rozetleri (tip ikonu taşıyan resimler)
  CircleAnnotationManager? _clusterCircles; // küme balonları (ayrı yönetici)
  PointAnnotationManager? _labels; // küme sayıları
  PolylineAnnotationManager? _routeLines; // rota çizgisi (bacaklar)
  PointAnnotationManager? _routeMarks; // rota işaretçileri (A/duraklar/varış)
  PointAnnotationManager? _deviceMark; // kaptanın GPS imleci (tekne rozeti)

  /// Son çizilen rota imzası — değişmediyse rotaya HİÇ dokunulmaz (perf).
  int _lastRouteSig = 0;

  /// Son çizilen GPS imleci konumu.
  GeoPoint? _lastDevicePos;

  /// pinId → çizili annotation (fark için).
  final Map<String, PointAnnotation> _pinAnnotations = <String, PointAnnotation>{};

  /// Rozet PNG'leri BİR KEZ çizilir, stil yeniden yüklenirse baytlar buradan
  /// tekrar kaydedilir (stil yüklemesi resimleri silebilir).
  final Map<String, Uint8List> _pinImagePngs = <String, Uint8List>{};

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

  /// ZOOM ÖLÇEK KÖPRÜSÜ (kurucu bulgusu 2026-09-23: "ikonlar webteki oranda
  /// görünsün"): Mapbox 512px karo kullanır, web (flutter_map/Leaflet) 256px —
  /// AYNI görsel ölçekte Mapbox zoom sayısı webden 1 KÜÇÜKTÜR. Sunucu eşikleri
  /// (pin modu zoom ≥ 9, docs/23 §9.5) web ölçeğinde tanımlıdır; bu yüzden
  /// sunucuya bildirilen zoom'a +1 eklenir, dışarıdan gelen zoom istekleri
  /// (odak/bölge) kameraya -1 ile uygulanır. Bu köprü olmadan telefonda
  /// pinlerin ikona dönüşmesi için webden BİR SEVİYE fazla yaklaşmak
  /// gerekiyordu ("noktalar nokta kalıyor" hissinin ikinci yarısı).
  static const double _kZoomOffset = 1;

  /// Açılış görünümü (kurucu kararı 2026-09-23: web ile aynı — Ege + Akdeniz
  /// kıyısı odaklı açılır; tüm Türkiye değil). Mapbox 6 ≈ web 7; dikey telefon
  /// ekranında İzmir–Kaş bandı ve Ege adaları tek bakışta görünür.
  static final CameraOptions _initialCamera = CameraOptions(
    center: Point(coordinates: Position(28.5, 37.5)),
    zoom: 6,
  );

  @override
  void didUpdateWidget(covariant MapboxMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ODAK İSTEĞİ (2026-09-23 eksik parça: "Konumum" ve açılış bölge seçimi
    // web yüzeyinde çalışıyordu, Mapbox yüzeyinde YOK SAYILIYORDU): seq
    // değiştiyse kamera istenen noktaya uçar. Zoom web ölçeğinde gelir
    // (bölge 9, "Konumum" en az 12) — kameraya -1 köprüsüyle uygulanır.
    final MapFocusRequest? f = widget.data.focus;
    if (f != null && f.seq != oldWidget.data.focus?.seq) {
      unawaited(_flyToFocus(f));
    }
    unawaited(_render());
  }

  Future<void> _flyToFocus(MapFocusRequest f) async {
    final MapboxMap? map = _map;
    if (map == null || _disposed) return;
    double webZoom = f.zoom ?? 12;
    if (f.zoom == null) {
      // "Konumum" davranışı (web ile aynı): en az 12 — mevcut daha yakınsa koru.
      final CameraState cam = await map.getCameraState();
      if (_disposed) return;
      final double currentWeb = cam.zoom + _kZoomOffset;
      if (currentWeb > webZoom) webZoom = currentWeb;
    }
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(f.point.lon, f.point.lat)),
        zoom: webZoom - _kZoomOffset,
      ),
      MapAnimationOptions(duration: 800),
    );
    // Uçuş bitince kamera olayları zaten görünümü bildirir (idle zamanlayıcı).
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _map = null;
    _pins = null;
    _clusterCircles = null;
    _labels = null;
    _routeLines = null;
    _routeMarks = null;
    _deviceMark = null;
    super.dispose();
  }

  /// PİN ROZETLERİNİ STİLE KAYDET (kurucu bulgusu 2026-09-23: "noktalara
  /// yaklaşınca ikonlar belli olmuyor"): her `location_type` için tip renginde
  /// daire + beyaz glif PNG'si üretilir ve `addStyleImage` ile verilir; pinler
  /// `PointAnnotation(iconImage:)` üzerinden bu rozetleri kullanır. Stil
  /// yeniden yüklenirse resimler silinebileceği için çağrı İDEMPOTENTTİR
  /// (baytlar önbellekte, aynı kimliğe yeniden kayıt zararsız).
  Future<void> _registerPinImages(MapboxMap map) async {
    final int px = (kPinBadgeLogicalSize * kPinImageScale).round();
    Future<bool> add(String id, Uint8List png) async {
      await map.style.addStyleImage(
        id,
        kPinImageScale,
        MbxImage(width: px, height: px, data: png),
        false, // sdf değil — çok renkli bitmap
        const <ImageStretches?>[],
        const <ImageStretches?>[],
        null,
      );
      return _disposed;
    }

    for (final MapEntry<String, ({int fillArgb, DocklyIconData icon})> spec
        in mapPinBadgeSpecs().entries) {
      final Uint8List png = _pinImagePngs[spec.key] ??= await renderPinBadgePng(
        fillArgb: spec.value.fillArgb,
        icon: spec.value.icon,
      );
      if (_disposed || await add(spec.key, png)) return;
    }
    // Rota/imleç rozetleri (Rota Modu 2026-09-23): başlangıç, varış, durak
    // zemini ve GPS teknesi — aynı boru hattı, aynı keskinlik.
    for (final MapEntry<String,
            ({int fillArgb, int ringArgb, DocklyIconData? icon})> spec
        in mapRouteBadgeSpecs().entries) {
      final Uint8List png = _pinImagePngs[spec.key] ??= await renderPinBadgePng(
        fillArgb: spec.value.fillArgb,
        ringArgb: spec.value.ringArgb,
        icon: spec.value.icon,
      );
      if (_disposed || await add(spec.key, png)) return;
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.setCamera(_initialCamera);
    if (_disposed) return;
    // SÜS YERLEŞİMİ (gerçek cihaz dersi 2026-09, kurucu bulgusu): pusula
    // varsayılan sağ üstte, bizim arama hapı + sağ düğme kolonunun ALTINDA
    // kalıyordu ve harita kuzeye bakarken kendini gizliyordu — "kaybolmuş"
    // görünüyordu. Denizci uygulamasında pusula HER ZAMAN görünür ve boş
    // olan SOL tarafta, çiplerin altında durur. Ölçek çubuğu da hemen altına
    // alınır (varsayılan yeri arama hapının arkasıydı).
    await map.compass.updateSettings(CompassSettings(
      position: OrnamentPosition.TOP_LEFT,
      marginTop: 118,
      marginLeft: 12,
      fadeWhenFacingNorth: false, // kaptan pusulayı hep görür
    ));
    // Ölçek çubuğu KAPALI (kurucu kararı 2026-09-23: "çirkin durmuş, kaldır").
    // Mesafe bilgisi rota çipinde deniz mili olarak zaten veriliyor.
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    if (_disposed) return;
    // Rozet resimleri ANNOTASYONLARDAN ÖNCE kaydedilir — ilk pin yaratıldığında
    // iconImage çözülebilsin (kayıtsız kimlik = görünmez pin).
    await _registerPinImages(map);
    if (_disposed) return;
    // Katman sırası = yaratılış sırası: rota çizgisi EN ALTTA, üstünde
    // pinler/kümeler, en üstte rota işaretçileri ve GPS teknesi.
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    _pins = await map.annotations.createPointAnnotationManager();
    _clusterCircles = await map.annotations.createCircleAnnotationManager();
    _labels = await map.annotations.createPointAnnotationManager();
    _routeMarks = await map.annotations.createPointAnnotationManager();
    _deviceMark = await map.annotations.createPointAnnotationManager();
    if (_disposed) return;
    _pins!.tapEvents(onTap: _onPinTap);
    _clusterCircles!.tapEvents(onTap: _onClusterCircleTap);
    await _render();
    // Kuruluşta bekleyen odak isteği (açılış bölge/konum seçimi) uygulanır —
    // web yüzeyiyle aynı davranış (_applyPendingFocus karşılığı).
    final MapFocusRequest? pending = widget.data.focus;
    if (pending != null) unawaited(_flyToFocus(pending));
  }

  /// Stil yeniden yüklenirse (tema/stil değişimi) kayıtlı resimler silinebilir —
  /// önbellekten yeniden kaydedilir; annotasyonlar zaten kendi katmanında durur.
  void _onStyleLoaded(StyleLoadedEventData data) {
    final MapboxMap? map = _map;
    if (map == null || _disposed) return;
    unawaited(_registerPinImages(map));
  }

  void _onPinTap(PointAnnotation annotation) {
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

  /// Son CANLI (sürükleme sürerken) görünüm bildirimi anı — akış ~4 Hz'e
  /// kısılır ki platform kanalı boğulmasın.
  DateTime? _lastLiveReportAt;

  /// Kamera hareket edince görünen bbox + zoom bildirilir.
  void _onCameraChanged(CameraChangedEventData data) {
    _idleTimer?.cancel();
    // 350→200→120→80 ms (perf turları, kurucu bulgusu "noktalar daha da
    // hızlı gelsin"): parmak kalkar kalkmaz istek yola çıksın — önden geniş
    // getirme sayesinde çoğu kaydırma ağa çıkmadan bellekten dolar; bellekten
    // dolan karede bu bekleme tek gecikmedir, o yüzden kısa tutulur.
    _idleTimer = Timer(const Duration(milliseconds: 80), _reportViewport);
    // CANLI AKIŞ (kurucu bulgusu 2026-09-23, 3. hız turu): parmak DAHA
    // KALKMADAN da görünüm ~250 ms'de bir bildirilir. Önbellek kapsıyorsa
    // controller debounce'suz anında doldurur → pinler sürükleme sırasında
    // belirir. Ağa çıkacak istekleri controller'ın debounce'u zaten tekler —
    // bu akış ağ trafiği yaratmaz, yalnız bellekten kareyi erken doldurur.
    final DateTime now = DateTime.now();
    if (_lastLiveReportAt == null ||
        now.difference(_lastLiveReportAt!) >=
            const Duration(milliseconds: 250)) {
      _lastLiveReportAt = now;
      unawaited(_reportViewport());
    }
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
        // Web ölçeğine köprü: sunucu eşikleri (pin zoom ≥ 9) web sayısıyla
        // çalışır — Mapbox zoom'una +1 (bkz. _kZoomOffset).
        zoom: (camera.zoom + _kZoomOffset).round(),
      ),
    );
  }

  Future<void> _flyToCluster(Cluster cluster) async {
    final MapboxMap? map = _map;
    if (map == null || _disposed) return;
    // Web ile aynı davranış: mevcut + 2.5, [9.5, 14] aralığına kıstırılır
    // (web ölçeğinde) — tek dokunuşta "balon patlar", pinlere inilir.
    final CameraState cam = await map.getCameraState();
    if (_disposed) return;
    final double webZoom =
        (cam.zoom + _kZoomOffset + 2.5).clamp(9.5, 14.0).toDouble();
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(cluster.position.lon, cluster.position.lat)),
        zoom: webZoom - _kZoomOffset,
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

  /// Rota içerik imzası — rota değişmediyse (en sık durum) çizime hiç
  /// dokunulmaz. routeSeq yeterli değil: düzenlemeler (durak ekle/taşı)
  /// routeSeq'i artırmaz; imza bacak uçları + duraklar üzerinden kurulur.
  static int _routeSignature(MapSurfaceData d) {
    final List<List<GeoPoint>>? legs = d.routeLegPoints ??
        (d.routePoints == null ? null : <List<GeoPoint>>[d.routePoints!]);
    if (legs == null || legs.isEmpty) return 0;
    final List<Object?> parts = <Object?>[legs.length];
    for (final List<GeoPoint> l in legs) {
      if (l.isEmpty) continue;
      parts
        ..add(l.length)
        ..add(l.first.lat)
        ..add(l.first.lon)
        ..add(l.last.lat)
        ..add(l.last.lon);
    }
    for (final MapRouteStop s in d.routeStops) {
      parts
        ..add(s.number)
        ..add(s.pos.lat)
        ..add(s.pos.lon);
    }
    final GeoPoint? ob = d.routeOriginBadge;
    if (ob != null) {
      parts
        ..add(ob.lat)
        ..add(ob.lon);
    }
    return Object.hashAll(parts);
  }

  /// Rota çizgisi rengi — marka birincil (docs/09; web yüzeyiyle aynı ton).
  static const int _routeLineArgb = 0xFF0C7BDC;

  /// ROTA ÇİZİMİ (kritik eksik, kurucu onayı 2026-09-23: rota çizgisi yalnız
  /// web'de vardı — telefonda rota kurulunca haritada HİÇBİR ŞEY çizilmiyordu):
  /// bacak başına kalın marka-mavisi çizgi + başlangıç (yelken rozeti),
  /// numaralı duraklar (beyaz rozet) ve varış (yeşil flama rozeti).
  Future<void> _renderRoute(MapSurfaceData data, int sig) async {
    final PolylineAnnotationManager? lines = _routeLines;
    final PointAnnotationManager? marks = _routeMarks;
    if (lines == null || marks == null || _disposed) return;
    await lines.deleteAll();
    if (_disposed) return;
    await marks.deleteAll();
    if (_disposed) return;
    _lastRouteSig = sig;
    if (sig == 0) return; // rota yok — temizlik yeterli
    final List<List<GeoPoint>> legs = data.routeLegPoints ??
        <List<GeoPoint>>[if (data.routePoints != null) data.routePoints!];
    await lines.createMulti(<PolylineAnnotationOptions>[
      for (final List<GeoPoint> leg in legs)
        if (leg.length >= 2)
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: <Position>[
              for (final GeoPoint p in leg) Position(p.lon, p.lat),
            ]),
            lineColor: _routeLineArgb,
            lineWidth: 5.0,
            lineOpacity: 0.95,
          ),
    ]);
    if (_disposed) return;
    // İşaretçiler: başlangıç + duraklar (sonuncusu VARIŞ = yeşil flama).
    final List<PointAnnotationOptions> markOpts = <PointAnnotationOptions>[];
    final GeoPoint? start = data.routeOriginBadge ??
        (legs.isNotEmpty && legs.first.isNotEmpty ? legs.first.first : null);
    if (start != null) {
      markOpts.add(PointAnnotationOptions(
        geometry: Point(coordinates: Position(start.lon, start.lat)),
        iconImage: kRouteStartImageId,
      ));
    }
    final List<MapRouteStop> stops = data.routeStops;
    for (int i = 0; i < stops.length; i++) {
      final bool isDest = i == stops.length - 1;
      markOpts.add(PointAnnotationOptions(
        geometry:
            Point(coordinates: Position(stops[i].pos.lon, stops[i].pos.lat)),
        iconImage: isDest ? kRouteDestImageId : kRouteStopImageId,
        textField: isDest ? null : '${stops[i].number}',
        textSize: 12.0,
        textColor: _routeLineArgb,
      ));
    }
    if (stops.isEmpty && legs.isNotEmpty && legs.last.isNotEmpty) {
      // Duraksız düz rota — varış flaması son noktaya.
      final GeoPoint dest = legs.last.last;
      markOpts.add(PointAnnotationOptions(
        geometry: Point(coordinates: Position(dest.lon, dest.lat)),
        iconImage: kRouteDestImageId,
      ));
    }
    if (markOpts.isNotEmpty) await marks.createMulti(markOpts);
  }

  /// GPS TEKNE İMLECİ (eksik parça): kaptanın konumu artık telefonda da
  /// görünür — web'deki yelkenli imlecin Mapbox karşılığı.
  Future<void> _renderDeviceMark(GeoPoint? pos) async {
    final PointAnnotationManager? mark = _deviceMark;
    if (mark == null || _disposed) return;
    _lastDevicePos = pos;
    await mark.deleteAll();
    if (_disposed || pos == null) return;
    await mark.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(pos.lon, pos.lat)),
      iconImage: kDeviceBoatImageId,
    ));
  }

  static bool _samePos(GeoPoint? a, GeoPoint? b) =>
      identical(a, b) || (a != null && b != null && a.lat == b.lat && a.lon == b.lon);

  Future<void> _renderOnce() async {
    final PointAnnotationManager? pins = _pins;
    final CircleAnnotationManager? clusterCircles = _clusterCircles;
    final PointAnnotationManager? labels = _labels;
    if (pins == null || clusterCircles == null || labels == null || _disposed) {
      return;
    }

    final MapSurfaceData data = widget.data;
    final String? selectedId = data.selectedPinId;

    // --- ROTA + GPS İMLECİ: kendi değişim algılarıyla, pinlerden bağımsız ---
    final int routeSig = _routeSignature(data);
    if (routeSig != _lastRouteSig) {
      await _renderRoute(data, routeSig);
      if (_disposed) return;
    }
    if (!_samePos(data.devicePosition, _lastDevicePos)) {
      await _renderDeviceMark(data.devicePosition);
      if (_disposed) return;
    }

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
      await pins.deleteAll();
      if (_disposed) return;
      _pinAnnotations.clear();
      _annotationToPin.clear();
    } else {
      for (final String id in goneIds) {
        final PointAnnotation? ann = _pinAnnotations.remove(id);
        if (ann != null) {
          _annotationToPin.remove(ann.id);
          await pins.delete(ann);
          if (_disposed) return;
        }
      }
      // Seçim durumu değişen pinleri düşür — aşağıda toplu yaratılırlar.
      // (CI düzeltmesi: eleman tipi String? — eski ya da yeni seçim null
      // olabilir, örneğin seçim ilk kez yapılırken.)
      if (selectedId != _lastSelectedPinId) {
        for (final String? id in <String?>[selectedId, _lastSelectedPinId]) {
          final PointAnnotation? ann = id == null ? null : _pinAnnotations.remove(id);
          if (ann != null) {
            _annotationToPin.remove(ann.id);
            await pins.delete(ann);
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
      final List<PointAnnotationOptions> options = <PointAnnotationOptions>[
        for (final LocationPin pin in toCreate)
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(pin.position.lon, pin.position.lat)),
            // Rozet = location_type kanonik rengi + tip glifi (docs/09 §1.4;
            // kurucu bulgusu 2026-09-23 "ikonlar belli olmuyor"). Seçili pin
            // 1.3× ölçek (renk/glif değişmez — renk tip anlamına rezerve).
            iconImage: mapPinImageId(pin.type),
            iconSize: pin.id == selectedId ? 1.3 : 1.0,
          ),
      ];
      final List<PointAnnotation?> created = await pins.createMulti(options);
      if (_disposed) return;
      for (int i = 0; i < toCreate.length && i < created.length; i++) {
        final PointAnnotation? ann = created[i];
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
      onStyleLoadedListener: _onStyleLoaded,
      onCameraChangeListener: _onCameraChanged,
      // HARİTA DOKUNUŞU (Rota Modu paketi 2026-09-23 — eksik parça): web
      // yüzeyinde vardı, Mapbox'ta HİÇ bağlanmamıştı. "Başlangıç seç" ve
      // "+ nokta ekle" modları telefonda bu dinleyiciyle çalışır.
      // NOT (CI 2026-09-23): onTapListener 2.22'de "deprecated" işaretli ama
      // tam çalışır; önerilen addInteraction API'sine geçiş ayrı, riskli bir
      // iştir (annotation tap'leriyle etkileşimi cihazda doğrulanmalı) —
      // bilinçli olarak şimdilik bu kararlı yol kullanılır.
      // ignore: deprecated_member_use
      onTapListener: (MapContentGestureContext ctx) {
        // onMapTap isteğe bağlı (web/liste yüzeyleri vermeyebilir) — null
        // güvenli çağrı (CI: unchecked_use_of_nullable_value).
        widget.callbacks.onMapTap?.call(GeoPoint(
          lat: ctx.point.coordinates.lat.toDouble(),
          lon: ctx.point.coordinates.lng.toDouble(),
        ));
      },
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
