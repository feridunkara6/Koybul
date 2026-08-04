import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/origin_provider.dart';
import '../../../core/providers.dart';
import '../../route/application/route_wind_advisor.dart';
import '../../route/application/sea_route_engine.dart';
import '../../route/domain/route_wind.dart';
import '../../route/domain/sea_router.dart';
import '../data/api_map_locations_gateway.dart';
import '../data/bundled_map_snapshot.dart';
import '../data/shared_prefs_map_cache.dart';
import '../domain/map_cache.dart';
import '../domain/map_locations_gateway.dart';
import '../domain/map_state.dart';
import '../domain/map_viewport.dart';

/// Harita verisi ağ geçidi sağlayıcısı — testte sahte ile override edilir.
final Provider<MapLocationsGateway> mapLocationsGatewayProvider =
    Provider<MapLocationsGateway>(
  (ref) => ApiMapLocationsGateway(ref.watch(locationsApiProvider)),
);

/// Çevrimdışı önbellek sağlayıcısı — testte sahte ile override edilir.
final Provider<MapCache> mapCacheProvider =
    Provider<MapCache>((ref) => const SharedPrefsMapCache());

/// Gömülü anlık görüntü sağlayıcısı (İLK ziyaret hızlandırması) — testte
/// sahte ile override edilir.
final Provider<BundledMapSnapshot> bundledMapSnapshotProvider =
    Provider<BundledMapSnapshot>((ref) => const BundledMapSnapshot());

/// "Teknem sığar" filtresi (ürün kararı): açıkken, tekne profiline SIĞMAYAN
/// yerler haritadan ve listeden gizlenir. Limiti BİLİNMEYEN yerler gizlenmez —
/// bilgi yokken yer saklamak yanlış olur (0-uydurma ilkesinin arayüz hali).
final StateProvider<bool> mapFitFilterProvider = StateProvider<bool>((ref) => false);

/// Keşfet sekmesi görünüm modu: false = harita, true = liste. Kullanıcı sağ
/// üstteki düğmeyle değiştirir; sekme değişse de korunur (uygulama-ömürlü).
final StateProvider<bool> mapViewIsListProvider = StateProvider<bool>((ref) => false);

/// Haritaya odaklanma isteği ("Konumum" → tekne imlecine uç). Yüzey bu değeri
/// izler; seq değişince kamerayı noktaya taşır.
final StateProvider<MapFocusRequest?> mapFocusProvider =
    StateProvider<MapFocusRequest?>((ref) => null);

/// Harita çağrılarının debounce süresi (docs/14 perf — pan/zoom sırasında
/// gereksiz istek olmasın). Kısa tutulur: harita yüzeyinin kendi debounce'u
/// (150ms) zaten var; ikisinin toplamı algılanan gecikmeyi belirler.
/// Testte `Duration.zero`'a override edilir.
final Provider<Duration> mapDebounceProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 120));

/// Sunucu pin eşiğinin aynası (apps/api cluster.ts MIN_PIN_ZOOM):
/// zoom ≥ 9 → pin modu. Bellek-içi hızlı yol bu eşiğe göre çalışır.
const int _minPinZoom = 9;

/// Bellek-içi pin önbelleğinin tazelik süresi — sunucunun CDN cache'iyle
/// (Cache-Control 120s) hizalı: bu süre içinde ağa çıkmak zaten aynı veriyi
/// döndürürdü.
const Duration _pinCacheTtl = Duration(seconds: 120);

/// Harita ekranının beyni (docs/26 §4): görünüm değişimi → debounce → yükleme,
/// marker/cluster durumu, seçim, hata + retry. Somut haritadan bağımsızdır.
class MapController extends Notifier<MapState> {
  Timer? _debounce;
  MapViewport? _lastRequested;
  int _seq = 0;
  int _routeReq = 0; // rota istekleri için AYRI sayaç (viewport _seq'ine karışmaz)

  // Bellek-içi pin önbelleği (perf): son BAŞARILI, filtre-siz, TAM (truncated
  // değil) pin yanıtı. Yakınlaşınca yeni bbox bu kapsamın İÇİNDEYSE ağa hiç
  // çıkılmaz — pinler anında süzülüp gösterilir (yakınlaştırma gecikmesi biter).
  Bbox? _pinCacheBbox;
  List<LocationPin> _pinCachePins = const <LocationPin>[];
  DateTime? _pinCacheAt;

  @override
  MapState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const MapState();
  }

  MapLocationsGateway get _gateway => ref.read(mapLocationsGatewayProvider);

  /// Harita kaydırılınca/zoom'lanınca çağrılır — aynı görünüm tekrarlanmaz,
  /// hızlı değişimler debounce ile tek isteğe indirgenir.
  void onViewportChanged(MapViewport viewport, {List<String>? types}) {
    if (viewport == _lastRequested) return;
    _lastRequested = viewport;
    _debounce?.cancel();
    _debounce = Timer(
      ref.read(mapDebounceProvider),
      () => loadViewport(viewport, types: types),
    );
  }

  /// Anında (debounce'suz) yükleme — retry ve debounce zamanlayıcısı kullanır.
  /// Eş zamanlı çağrılarda yalnız en son yanıt uygulanır (stale koruması).
  Future<void> loadViewport(MapViewport viewport, {List<String>? types}) async {
    _lastRequested = viewport;
    // Deniz-rota başlangıç noktası = görüntülenen alanın merkezi (P2). İleride
    // GPS ile gerçek konuma yükseltilecek; şimdilik "haritada baktığın yer".
    final Bbox b = viewport.bbox;
    // GPS konumu VARSA harita merkezi origin'i ezmez — kullanıcının gerçek
    // konumu mesafe/koordinat hesaplarında sabit kalır (kullanıcı isteği).
    if (ref.read(devicePositionProvider) == null) {
      ref.read(originProvider.notifier).state = GeoPoint(
        lat: (b.minLat + b.maxLat) / 2,
        lon: (b.minLon + b.maxLon) / 2,
      );
    }
    final seq = ++_seq;
    // Parametre verilmediyse haritadaki çip filtreleri kullanılır (boş = tümü).
    final List<String>? effectiveTypes =
        types ?? (state.types.isEmpty ? null : state.types.toList(growable: false));
    // HIZLI YOL (perf): pin modunda, elimizde bu alanı KAPSAYAN taze ve tam bir
    // pin yanıtı varsa ağa çıkmadan anında süz — yakınlaşınca pinler beklemeden
    // ayrı lokasyonlarına dağılır. (Filtre açıkken ve truncated yanıtlarda
    // kullanılmaz — eksik veri gösterme riski yok.)
    if (effectiveTypes == null &&
        viewport.zoom >= _minPinZoom &&
        _pinCacheBbox != null &&
        _pinCacheAt != null &&
        DateTime.now().difference(_pinCacheAt!) <= _pinCacheTtl &&
        _containsBbox(_pinCacheBbox!, viewport.bbox)) {
      state = state.copyWith(
        pins: _pinsInBbox(_pinCachePins, viewport.bbox),
        clusters: const <Cluster>[],
        truncated: false,
        isLoading: false,
        clearFailure: true,
        hasLoadedOnce: true,
        isOffline: false,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearFailure: true);
    // SICAK BAŞLANGIÇ (algılanan hız): ilk yüklemede, taze veri gelene dek
    // cihazdaki son başarılı veri ANINDA gösterilir — açılışta boş harita ve
    // uzun spinner yerine dolu harita + ince yükleme çubuğu.
    if (!state.hasLoadedOnce && !state.hasData) {
      CachedMap? warm = await ref.read(mapCacheProvider).load();
      // İLK ZİYARET (perf, 2026-08): cihaz önbelleği boşsa uygulamayla gömülü
      // gelen anlık görüntü kullanılır — harita ilk açılışta da ağı beklemeden
      // dolar; taze veri gelince yerini bırakır.
      if (warm == null || warm.isEmpty) {
        warm = await ref.read(bundledMapSnapshotProvider).load();
      }
      if (seq == _seq && warm != null && !warm.isEmpty && !state.hasData) {
        state = state.copyWith(pins: warm.pins, clusters: warm.clusters);
      }
      if (seq != _seq) return;
    }
    try {
      final result = await _gateway.loadViewport(viewport, types: effectiveTypes);
      if (seq != _seq) return;
      // Hızlı yolun kaynağını güncelle: filtre-siz, tam pin yanıtları saklanır.
      if (effectiveTypes == null && viewport.zoom >= _minPinZoom && !result.truncated) {
        _pinCacheBbox = viewport.bbox;
        _pinCachePins = result.locations;
        _pinCacheAt = DateTime.now();
      }
      state = state.copyWith(
        pins: result.locations,
        clusters: result.clusters,
        truncated: result.truncated,
        isLoading: false,
        clearFailure: true,
        hasLoadedOnce: true,
        isOffline: false,
      );
      // Çevrimdışı görünüm için son başarılı veriyi sakla (en iyi çaba;
      // filtresiz genel görünümü bozmasın diye yalnız filtre yokken).
      if (state.types.isEmpty && (result.locations.isNotEmpty || result.clusters.isNotEmpty)) {
        await ref.read(mapCacheProvider).save(result.locations, result.clusters);
      }
    } on AppFailure catch (failure) {
      if (seq != _seq) return;
      // Ekranda veri VARSA (sıcak başlangıç ya da önceki yükleme): tam-ekran
      // hata yerine çevrimdışı şerit — veri korunur, gezinmek yeniden dener.
      if (state.hasData) {
        state = state.copyWith(
          isLoading: false,
          clearFailure: true,
          hasLoadedOnce: true,
          isOffline: true,
        );
        return;
      }
      // Ağ yoksa ve ekranda hiç veri yoksa: cihazdaki son başarılı veriyi
      // göster (çevrimdışı görünüm) — denizde bağlantı gidince uygulama kör
      // kalmasın.
      if (!state.hasData) {
        final CachedMap? cached = await ref.read(mapCacheProvider).load();
        if (seq != _seq) return;
        if (cached != null && !cached.isEmpty) {
          state = state.copyWith(
            pins: cached.pins,
            clusters: cached.clusters,
            isLoading: false,
            clearFailure: true,
            hasLoadedOnce: true,
            isOffline: true,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  /// Tip filtresini aç/kapat (haritadaki renkli çipler; aynı zamanda lejant).
  /// Değişince son görünüm yeni filtreyle hemen yeniden yüklenir. Bellek-içi
  /// pin önbelleği düşürülür — filtre oynadıktan sonra taze veri çekilir.
  Future<void> toggleType(String code) async {
    final Set<String> next = Set<String>.of(state.types);
    if (!next.add(code)) next.remove(code);
    state = state.copyWith(types: next);
    _pinCacheBbox = null;
    _pinCacheAt = null;
    _pinCachePins = const <LocationPin>[];
    final viewport = _lastRequested;
    if (viewport != null) await loadViewport(viewport);
  }

  /// AKILLI DENİZ ROTASI (2026-08): kullanıcının PAYLAŞILAN GPS konumundan
  /// seçili noktaya, denizden (karadan kaçınan) rota. KONUM ŞARTI (kullanıcı
  /// kararı 2026-08): konum paylaşılmadan rota OLUŞTURULMAZ — harita merkezi
  /// gibi tahmini başlangıç kullanılmaz; arayüz "konumunu paylaş" uyarısı
  /// gösterir. Motor rota bulamazsa (kapsam dışı, kapalı havza) rota
  /// ÇİZİLMEZ ve "hesaplanamadı" uyarısı verilir — kara üzerinden düz
  /// çizgi ASLA gösterilmez (kaptan kuralı).
  Future<void> routeToPin(LocationPin pin) async {
    final GeoPoint? origin = ref.read(devicePositionProvider);
    if (origin == null || state.isRouting) return;
    state = state.copyWith(isRouting: true);
    final int req = ++_routeReq; // stale koruması (rota istekleri arasında)
    SeaRoutePlan? plan;
    try {
      plan = await ref.read(seaRouteEngineProvider).route(origin, pin.position);
    } catch (_) {
      plan = null;
    }
    if (req != _routeReq) return;
    // KARA YASAĞI (kaptan kuralı 2026-08): motor rota bulamazsa DÜZ ÇİZGİ
    // ÇİZİLMEZ — kullanıcıya dürüst "hesaplanamadı" uyarısı gösterilir.
    if (plan == null) {
      state = state.copyWith(
        isRouting: false,
        routeFailSeq: state.routeFailSeq + 1,
      );
      return;
    }
    final SeaRoutePlan resolved = plan;
    state = state.copyWith(
      route: resolved,
      isRouting: false,
      routeSeq: state.routeSeq + 1,
      clearRouteWind: true, // yeni rota → eski rüzgâr raporu geçersiz
    );
    // RÜZGÂR ANALİZİ (Rota v2): arka planda, en iyi çaba — rota çizimi bunu
    // BEKLEMEZ. Rapor gelince çipe rüzgâr satırı eklenir; gelmezse sessiz.
    if (resolved.viaSea) {
      final RouteWindReport? wind = await ref
          .read(routeWindAdvisorProvider)
          .analyze(resolved, pin.id);
      if (req != _routeReq || !identical(state.route, resolved)) return;
      if (wind != null) state = state.copyWith(routeWind: wind);
    }
  }

  /// Çizili rotayı kaldırır (rota çipindeki kapat düğmesi).
  void clearRoute() {
    state = state.copyWith(clearRoute: true, isRouting: false);
  }

  void selectPin(String pinId) {
    state = state.copyWith(selectedPinId: pinId);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Hata ekranından son görünümü yeniden dener.
  Future<void> retry({List<String>? types}) async {
    final viewport = _lastRequested;
    if (viewport != null) await loadViewport(viewport, types: types);
  }
}

final NotifierProvider<MapController, MapState> mapControllerProvider =
    NotifierProvider<MapController, MapState>(MapController.new);

/// `inner` bbox'ı `outer` tarafından tamamen kapsanıyor mu? (Hızlı yol koşulu.)
bool _containsBbox(Bbox outer, Bbox inner) =>
    inner.minLon >= outer.minLon &&
    inner.maxLon <= outer.maxLon &&
    inner.minLat >= outer.minLat &&
    inner.maxLat <= outer.maxLat;

/// Önbellekteki pinlerden yalnız görünür alana düşenler (istemci-yanı süzme).
List<LocationPin> _pinsInBbox(List<LocationPin> pins, Bbox b) => pins
    .where((LocationPin p) =>
        p.position.lon >= b.minLon &&
        p.position.lon <= b.maxLon &&
        p.position.lat >= b.minLat &&
        p.position.lat <= b.maxLat)
    .toList(growable: false);
