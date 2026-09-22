import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../../route/domain/route_wind.dart';
import '../../route/domain/sea_router.dart';
import '../../route/domain/sea_trip.dart';

/// Harita ekranı durumu (docs/26 §4). Yeniden yükleme sırasında mevcut
/// marker'lar korunur (`isLoading` bindirme göstergesi); hata da veriyi silmez.
class MapState {
  const MapState({
    this.pins = const <LocationPin>[],
    this.clusters = const <Cluster>[],
    this.truncated = false,
    this.isLoading = false,
    this.failure,
    this.selectedPinId,
    this.hasLoadedOnce = false,
    this.types = const <String>{},
    this.isOffline = false,
    this.offlineDataAt,
    this.route,
    this.isRouting = false,
    this.routeSeq = 0,
    this.routeWind,
    this.routeFailSeq = 0,
    this.routeWaypoints = const <RouteWaypoint>[],
    this.routeLegs = const <SeaRoutePlan>[],
    this.routeEditFailSeq = 0,
    this.routeOrigin,
    this.pickingOrigin = false,
    this.addingPoint = false,
    this.originPickFailSeq = 0,
    this.routeLabel,
    this.routeFocus = false,
    this.routeQuotaBlockSeq = 0,
    this.multiStopBlockSeq = 0,
  });

  final List<LocationPin> pins;
  final List<Cluster> clusters;
  final bool truncated;
  final bool isLoading;
  final AppFailure? failure;
  final String? selectedPinId;

  /// Seçili tip filtreleri (haritadaki renkli çipler). Boş = tüm tipler.
  final Set<String> types;

  /// Çevrimdışı görünüm: ağ hatasında cihazdaki son başarılı veri gösteriliyor.
  /// Bir sonraki başarılı yüklemede kapanır.
  final bool isOffline;

  /// Çevrimdışı gösterilen verinin KAYIT ZAMANI (FAZ 2 cila, S11 bulgusu,
  /// kurucu onayı 2026-09): şerit "ne kadar eski" bilgisini bununla söyler.
  /// null = yaş bilinmiyor (bu oturumda az önce inen veri) → şerit sade kalır.
  /// Yalnız [isOffline] doğruyken okunur; taze yüklemede anlamı yoktur.
  final DateTime? offlineDataAt;

  /// Çizili deniz rotası (kullanıcı "Deniz rotası"na dokundu). null = yok.
  final SeaRoutePlan? route;

  /// Rota hesabı sürüyor (düğme dönen gösterge gösterir).
  final bool isRouting;

  /// Her yeni rotada artar — harita yüzeyi kamerayı rotaya bu sayaçla sığdırır.
  final int routeSeq;

  /// Rota rüzgâr raporu (Rota v2) — analiz bitince dolar; en iyi çaba.
  final RouteWindReport? routeWind;

  /// Rota HESAPLANAMADI sinyali (kara yasağı): her başarısız denemede artar;
  /// arayüz kullanıcıya dürüst bir uyarı gösterir (düz çizgi çizilmez).
  final int routeFailSeq;

  /// Rotanın sıralı ara noktaları (ROTA DÜZENLEME 2026-08): duraklar (isimli
  /// koylar) + tutamaç ara noktaları (isimsiz). Son eleman hedeftir. Boş =
  /// rota yok.
  final List<RouteWaypoint> routeWaypoints;

  /// Bacak planları (ara nokta sayısı kadar) — tutamaçlar bacak ortalarına
  /// yerleştirilir; [route] bunların birleşimidir.
  final List<SeaRoutePlan> routeLegs;

  /// Rota DÜZENLEMESİ başarısız sinyali: tutamaç/durak değişikliği rota
  /// bulamadıysa artar — ESKİ ROTA KORUNUR, arayüz kısa bir uyarı gösterir.
  final int routeEditFailSeq;

  /// Rotanın başlangıcı (rota planlama 2026-08): GPS ("Konumum") ya da
  /// haritadan/koydan seçilen A noktası. null = rota yok.
  final RouteOrigin? routeOrigin;

  /// Açık rotanın kullanıcı adı (KAYITLI ROTA açıldıysa verdiği isim) — çipte
  /// gösterilir. Yeni rota kurulunca temizlenir (kullanıcı isteği 2026-08).
  final String? routeLabel;

  /// ROTA ODAK MODU (kullanıcı isteği 2026-08): kayıtlı rota AÇILDIĞINDA
  /// haritada yalnız rota ve durakları görünür — diğer tüm imleçler/kümeler
  /// gizlenir. Rota kapatılınca (✕) normal görünüm döner.
  final bool routeFocus;

  /// BAŞLANGIÇ SEÇ modu: haritaya/koya dokunuş A noktasını belirler; arayüz
  /// üstte lacivert seçim şeridi gösterir.
  final bool pickingOrigin;

  /// NOKTA EKLE modu (kullanıcı isteği 2026-08, mobil dostu): rota çiziliyken
  /// haritaya dokunuş rotaya ARA NOKTA ekler, koya dokunuş DURAK ekler —
  /// sürüklemeye gerek kalmadan dokunarak düzenleme.
  final bool addingPoint;

  /// Başlangıç seçimi BAŞARISIZ sinyali (dokunulan yerin yakınında deniz yok):
  /// her başarısızlıkta artar; arayüz kısa bir uyarı gösterir.
  final int originPickFailSeq;

  /// GÜNLÜK ROTA KOTASI DOLDU sinyali (P4b, premium v3 K3): ücretsiz kullanıcı
  /// günün 3. rotasından SONRA yeni rota istediğinde artar — arayüz kota
  /// sayfasını (alt sayfa) gösterir; rota hesabı hiç başlamaz.
  final int routeQuotaBlockSeq;

  /// ÇOK DURAKLI ROTA KİLİDİ sinyali (P4b, premium v3 K4): ücretsiz kullanıcı
  /// rotaya İKİNCİ DURAK eklemeye çalıştığında artar — arayüz premium tanıtım
  /// alt sayfasını gösterir; mevcut rota olduğu gibi kalır.
  final int multiStopBlockSeq;

  /// En az bir yükleme tamamlandı mı? İlk yükleme bitmeden "boş durum" GÖSTERİLMEZ
  /// (aksi halde açılışta kısa süre yanlış "liman yok" mesajı yanıp söner — P9).
  final bool hasLoadedOnce;

  bool get hasData => pins.isNotEmpty || clusters.isNotEmpty;

  /// Boş durum ekranı: yalnızca bir yükleme BİTTİKTEN sonra veri yoksa gösterilir.
  bool get isEmpty => hasLoadedOnce && !hasData && !isLoading && failure == null;

  /// Seçili pin'in verisi (alt detay kartı için). Seçim yoksa ya da pin artık
  /// görünür pinler arasında değilse null (kart otomatik kaybolur).
  LocationPin? get selectedPin {
    final String? id = selectedPinId;
    if (id == null) return null;
    for (final LocationPin pin in pins) {
      if (pin.id == id) return pin;
    }
    return null;
  }

  MapState copyWith({
    List<LocationPin>? pins,
    List<Cluster>? clusters,
    bool? truncated,
    bool? isLoading,
    AppFailure? failure,
    bool clearFailure = false,
    String? selectedPinId,
    bool clearSelection = false,
    bool? hasLoadedOnce,
    Set<String>? types,
    bool? isOffline,
    DateTime? offlineDataAt,
    SeaRoutePlan? route,
    bool clearRoute = false,
    bool? isRouting,
    int? routeSeq,
    RouteWindReport? routeWind,
    bool clearRouteWind = false,
    int? routeFailSeq,
    List<RouteWaypoint>? routeWaypoints,
    List<SeaRoutePlan>? routeLegs,
    int? routeEditFailSeq,
    RouteOrigin? routeOrigin,
    bool? pickingOrigin,
    bool? addingPoint,
    int? originPickFailSeq,
    String? routeLabel,
    bool clearRouteLabel = false,
    bool? routeFocus,
    int? routeQuotaBlockSeq,
    int? multiStopBlockSeq,
  }) {
    return MapState(
      pins: pins ?? this.pins,
      clusters: clusters ?? this.clusters,
      truncated: truncated ?? this.truncated,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      selectedPinId: clearSelection ? null : (selectedPinId ?? this.selectedPinId),
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      types: types ?? this.types,
      isOffline: isOffline ?? this.isOffline,
      offlineDataAt: offlineDataAt ?? this.offlineDataAt,
      route: clearRoute ? null : (route ?? this.route),
      isRouting: isRouting ?? this.isRouting,
      routeSeq: routeSeq ?? this.routeSeq,
      routeWind: (clearRoute || clearRouteWind)
          ? null
          : (routeWind ?? this.routeWind),
      routeFailSeq: routeFailSeq ?? this.routeFailSeq,
      routeWaypoints: clearRoute
          ? const <RouteWaypoint>[]
          : (routeWaypoints ?? this.routeWaypoints),
      routeLegs:
          clearRoute ? const <SeaRoutePlan>[] : (routeLegs ?? this.routeLegs),
      routeEditFailSeq: routeEditFailSeq ?? this.routeEditFailSeq,
      routeOrigin: clearRoute ? null : (routeOrigin ?? this.routeOrigin),
      pickingOrigin: pickingOrigin ?? this.pickingOrigin,
      addingPoint: clearRoute ? false : (addingPoint ?? this.addingPoint),
      originPickFailSeq: originPickFailSeq ?? this.originPickFailSeq,
      routeLabel: (clearRoute || clearRouteLabel)
          ? null
          : (routeLabel ?? this.routeLabel),
      routeFocus: clearRoute ? false : (routeFocus ?? this.routeFocus),
      routeQuotaBlockSeq: routeQuotaBlockSeq ?? this.routeQuotaBlockSeq,
      multiStopBlockSeq: multiStopBlockSeq ?? this.multiStopBlockSeq,
    );
  }
}
