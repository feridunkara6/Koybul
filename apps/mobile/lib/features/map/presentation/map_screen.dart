import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../../emergency/presentation/emergency_screen.dart';
import '../../location/presentation/locate_button.dart';
import '../../nearby/presentation/nearby_sheet.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/presentation/onboarding_overlay.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/route_wind.dart';
import '../../route/domain/saved_route.dart';
import '../../route/domain/sea_route.dart';
import '../../route/domain/sea_router.dart';
import '../../route/domain/sea_trip.dart';
import '../../search/presentation/search_screen.dart';
import '../../checklist/application/checklist_controller.dart';
import '../../checklist/presentation/checklist_sheet.dart';
import '../../logbook/domain/log_entry.dart';
import '../../logbook/presentation/logbook_screen.dart' show showLogEntryEditor;
import '../application/map_controller.dart';
import '../domain/map_state.dart';
import 'location_bottom_card.dart';
import 'map_surface.dart';
import 'route_origin_menu.dart';

/// Harita ekranı (S-06). Somut harita yüzeyi üstüne durum katmanları:
/// yükleme, boş, hata+retry, "çok fazla sonuç" ipucu (docs/26 §4, docs/23 §9.5).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapState state = ref.watch(mapControllerProvider);
    final MapController controller = ref.read(mapControllerProvider.notifier);
    // KARA YASAĞI uyarısı: rota hesaplanamadıysa (düz çizgi çizilmez) kullanıcı
    // dürüstçe bilgilendirilir — sinyal sayacı her başarısız denemede artar.
    // SEYİR ÖNCESİ KONTROL (kullanıcı onayı 2026-08, günde bir nazik şerit):
    // yeni rota çizildi → kontrol şeridi (düzenlemeler routeSeq artırmaz).
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.routeSeq),
      (int? prev, int next) {
        if (prev != null && next > prev) {
          ref.read(checklistProvider.notifier).maybePrompt();
        }
      },
    );
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.routeFailSeq),
      (int? prev, int next) {
        if (next > (prev ?? 0)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).routeDirectNote)),
            );
        }
      },
    );
    // ROTA DÜZENLEME uyarısı (2026-08): tutamaç/durak değişikliği rota
    // bulamadıysa ESKİ ROTA KORUNUR ve kısa bir açıklama gösterilir.
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.routeEditFailSeq),
      (int? prev, int next) {
        if (next > (prev ?? 0)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).routeEditFail)),
            );
        }
      },
    );
    // BAŞLANGIÇ SEÇİMİ başarısız (yakında deniz yok): kısa uyarı, mod açık kalır.
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.originPickFailSeq),
      (int? prev, int next) {
        if (next > (prev ?? 0)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).originPickFail)),
            );
        }
      },
    );
    // İlk ara nokta eklenince tek seferlik ipucu: taşımak için sürükle,
    // kaldırmak için dokun (keşfedilebilirlik).
    ref.listen<int>(
      mapControllerProvider.select((MapState s) =>
          s.routeWaypoints.where((RouteWaypoint w) => !w.isStop).length),
      (int? prev, int next) {
        if ((prev ?? 0) == 0 && next > 0) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).routeViaHint)),
            );
        }
      },
    );
    final MapSurfaceBuilder surfaceBuilder = ref.watch(mapSurfaceBuilderProvider);
    // YENİ KULLANICI TANITIMI (2026-08): karşılama + tur + ilk-dokunuş ipuçları.
    final OnboardingState onb = ref.watch(onboardingControllerProvider);
    final bool isList = ref.watch(mapViewIsListProvider);
    final selectedPin = state.selectedPin;
    // "Teknem sığar" filtresi: SIĞMAYANLAR gizlenir; bilinmeyenler kalır.
    final bool fitOn = ref.watch(mapFitFilterProvider);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final List<LocationPin> visiblePins = (fitOn && boat != null)
        ? state.pins
            .where((LocationPin p) =>
                computeBoatFit(
                  boat: boat,
                  maxBoatLengthM: p.maxBoatLengthM,
                  maxDraftM: p.maxDraftM,
                ) !=
                BoatFit.tooBig)
            .toList(growable: false)
        : state.pins;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: isList
                ? _MapListView(pins: visiblePins)
                : surfaceBuilder(
                    context,
                    MapSurfaceData(
                      pins: visiblePins,
                      clusters: state.clusters,
                      selectedPinId: state.selectedPinId,
                      // Kullanıcının GPS konumu → haritada yelkenli imleç;
                      // "Konumum" isteği → kamera odaklanır (kullanıcı isteği).
                      devicePosition: ref.watch(devicePositionProvider),
                      focus: ref.watch(mapFocusProvider),
                      routePoints: state.route?.points,
                      routeSeq: state.routeSeq,
                      // ROTA DÜZENLEME (2026-08): bacaklar → tutamaçlar,
                      // ara noktalar → taşınabilir tutamaçlar, duraklar →
                      // numaralı rozetler.
                      routeLegPoints: state.routeLegs.isEmpty
                          ? null
                          : <List<GeoPoint>>[
                              for (final SeaRoutePlan l in state.routeLegs) l.points,
                            ],
                      routeVias: <MapRouteVia>[
                        for (int i = 0; i < state.routeWaypoints.length; i++)
                          if (!state.routeWaypoints[i].isStop)
                            MapRouteVia(index: i, pos: state.routeWaypoints[i].pos),
                      ],
                      routeStops: _stopMarkers(state.routeWaypoints),
                      // A NOKTASI rozeti: başlangıç GPS değilse çizilir.
                      routeOriginBadge: state.routeOrigin != null &&
                              !state.routeOrigin!.isDevice
                          ? state.routeOrigin!.pos
                          : null,
                    ),
                    MapSurfaceCallbacks(
                      onViewportChanged: controller.onViewportChanged,
                      onPinTap: controller.selectPin,
                      onClusterTap: (_) => controller.clearSelection(),
                      onRouteInsertVia: controller.insertVia,
                      onRouteMoveVia: controller.moveVia,
                      onRouteRemoveVia: controller.removeWaypoint,
                      onMapTap: controller.onMapTapped,
                    ),
                  ),
          ),
          // Üst şerit: tip filtre çipleri TAM GENİŞLİK (renk noktalı lejant).
          // Kullanıcı isteği (2026-07): ekranın üstünü rozetler kaplasın,
          // konum/liste düğmeleri bir alt sıraya insin.
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SafeArea(child: _TypeFilterRow(selected: state.types)),
          ),
          // Çip şeridinin HEMEN ALTINDA sağda: "Konumum" (her zaman) +
          // harita↔liste geçişi (yalnız pin/yakın zoom verisi varken).
          Positioned(
            top: 60, // 12 (çip üst boşluğu) + 40 (çip şeridi) + 8 (ara)
            right: 12,
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  // ACİL DURUM KISAYOLU (UX analizi 2026-08): panik anında tek
                  // dokunuş — Profil'in derinliğinde kalmasın. Üyelik kapısı YOK.
                  const _SosButton(),
                  const SizedBox(height: 8),
                  const LocateButton(),
                  const SizedBox(height: 8),
                  // HARİTADA ARAMA (UX analizi 2026-08): sekme değiştirmeden
                  // arama — sonuçtan detay açılır, harita durumu korunur.
                  const _MapSearchButton(),
                  if (state.pins.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _ViewToggle(
                      isList: isList,
                      onToggle: () =>
                          ref.read(mapViewIsListProvider.notifier).state = !isList,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (state.isLoading && state.hasData)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          // Üst-orta bilgi katmanı: çevrimdışı şeridi + deniz rotası çipi.
          if (state.isOffline || state.route != null)
            Positioned(
              top: 60,
              left: 64,
              right: 64,
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    if (state.isOffline) const Center(child: _OfflineBanner()),
                    if (state.isOffline && state.route != null)
                      const SizedBox(height: 8),
                    if (state.route != null)
                      Center(
                        child: _RouteChip(
                          route: state.route!,
                          wind: state.routeWind,
                          waypoints: state.routeWaypoints,
                          origin: state.routeOrigin,
                          onClear: controller.clearRoute,
                          onRemoveStop: controller.removeWaypoint,
                          onSave: () => _saveRouteDialog(context, ref, state),
                          label: state.routeLabel,
                          onChangeOrigin: () =>
                              showRouteOriginMenu(context, ref),
                          onAddPoint: controller.beginAddPoint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (state.truncated) const _TruncatedHint(),
          if (state.isLoading && !state.hasData)
            const Positioned.fill(child: _CenterProgress()),
          if (state.isEmpty) const Positioned.fill(child: _EmptyView()),
          if (state.failure != null)
            Positioned.fill(
              child: _ErrorView(
                message: state.failure!.message,
                onRetry: () => controller.retry(),
              ),
            ),
          // "Yakınındaki Limanlar" alt-sayfası (tasarım §07 peek durumu):
          // harita modunda, seçili pin yokken. Pin seçilince yerini karta bırakır.
          if (!isList && selectedPin == null)
            const Positioned(left: 0, right: 0, bottom: 0, child: NearbySheet()),
          if (!isList && selectedPin != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // İLK-DOKUNUŞ İPUCU (tanıtım 2026-08): ilk pin seçiminde
                  // kartın üstünde tek seferlik açıklama balonu.
                  if (onb.showHint(kHintBottomCard))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: OnboardingHintBubble(
                            hintKey: kHintBottomCard,
                            title: ref.watch(l10nProvider).onbHintCardTitle,
                            body: ref.watch(l10nProvider).onbHintCardBody,
                          ),
                        ),
                      ),
                    ),
                  LocationBottomCard(
                pin: selectedPin,
                // Tekne tanımlıysa kartta uyum rozeti (harita pinleriyle tutarlı).
                fit: computeBoatFit(
                  boat: ref.watch(myBoatProvider),
                  maxBoatLengthM: selectedPin.maxBoatLengthM,
                  maxDraftM: selectedPin.maxDraftM,
                ),
                onClose: controller.clearSelection,
                onOpenDetail: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LocationDetailScreen(idOrSlug: selectedPin.id),
                  ),
                ),
                routing: state.isRouting,
                // ROTA DÜZENLEME (2026-08): rota ÇİZİLİYKEN başka koya
                // dokununca "Durak ekle" gösterilir (rota baştan kurulmaz);
                // koy zaten rotadaysa yalnız Detay kalır.
                onAddStop: state.route != null &&
                        !state.routeWaypoints
                            .any((RouteWaypoint w) => w.id == selectedPin.id)
                    ? () => controller.addStop(
                          selectedPin.position,
                          selectedPin.id,
                          selectedPin.name,
                        )
                    : null,
                // AKILLI ROTA (kullanıcı isteği 2026-08): konum yoksa izin
                // OTOMATİK istenir; onay gelince rota kendiliğinden çizilir.
                onRoute: state.route != null
                    ? null
                    : () => startSeaRoute(
                          context,
                          ref,
                          destPos: selectedPin.position,
                          destId: selectedPin.id,
                          destName: selectedPin.name,
                        ),
                  ),
                ],
              ),
            ),
          // MOD ŞERİTLERİ: başlangıç seçimi / rotaya nokta ekleme (üstte).
          if (state.pickingOrigin)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ModeBanner(
                text: ref.watch(l10nProvider).routePickBanner,
                onCancel: controller.cancelOriginPick,
              ),
            ),
          if (state.addingPoint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ModeBanner(
                text: ref.watch(l10nProvider).routeAddPointBanner,
                onCancel: controller.cancelAddPoint,
              ),
            ),
          // SEYİR ÖNCESİ KONTROL ŞERİDİ (günde bir; onaylı doz): nazik soru,
          // iki saygın çıkış — "Listeyi aç" / "Hazırım".
          if (ref.watch(checklistProvider).promptVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ChecklistBanner(
                onOpen: () {
                  ref.read(checklistProvider.notifier).dismissPrompt();
                  showChecklistSheet(context);
                },
                onReady: () =>
                    ref.read(checklistProvider.notifier).dismissPrompt(),
              ),
            ),
          // TANITIM KARTLARI v2 (en üstte): ilk açılışta kendiliğinden başlar,
          // ekrana dokundukça ilerler (kullanıcı isteği 2026-08).
          if (!isList && onb.tourActive)
            Positioned.fill(child: TourOverlay(step: onb.tourStep)),
        ],
      ),
    );
  }
}

/// Harita ↔ liste geçiş düğmesi (sağ üst).
class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.isList, required this.onToggle});

  final bool isList;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: IconButton(
        icon: DocklyIcon(isList ? DocklyIcons.mapOutlined : DocklyIcons.viewList),
        tooltip: isList ? t.mapViewTooltip : t.listViewTooltip,
        onPressed: onToggle,
      ),
    );
  }
}

/// Keşfet sekmesinin liste görünümü: görünen limanlar, haritada baktığın
/// noktaya (başlangıç) göre en yakından uzağa sıralı. Dokununca detay açılır.
class _MapListView extends ConsumerWidget {
  const _MapListView({required this.pins});

  final List<LocationPin> pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final GeoPoint? origin = ref.watch(originProvider);
    final List<LocationPin> items = List<LocationPin>.of(pins);
    if (origin != null) {
      items.sort((LocationPin a, LocationPin b) =>
          haversineNm(origin, a.position).compareTo(haversineNm(origin, b.position)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (BuildContext _, int __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final LocationPin pin = items[i];
        final double? distNm = origin != null ? haversineNm(origin, pin.position) : null;
        final String subtitle = pin.ratingAvg != null
            ? '${t.typeLabel(pin.type)} · ★ ${pin.ratingAvg!.toStringAsFixed(1)}'
            : t.typeLabel(pin.type);
        return ListTile(
          leading: DocklyTypeAvatar(type: pin.type),
          title: Text(pin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: distNm != null ? Text('${_fmtNm(distNm)} ${t.nmUnit}') : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => LocationDetailScreen(idOrSlug: pin.id),
            ),
          ),
        );
      },
    );
  }
}

String _fmtNm(double nm) => nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);

/// MOD ŞERİDİ (rota planlama/nokta ekleme): lacivert, tek satır yönerge +
/// Vazgeç. Mod açıkken haritaya/koya dokunuşun anlamını açıklar.
/// Seyir öncesi kontrol şeridi (kullanıcı onayı 2026-08): lacivert zemin,
/// soru + iki eylem. Günde bir kez görünür; "Hazırım" ya da liste açılınca
/// aynı gün bir daha çıkmaz.
class _ChecklistBanner extends ConsumerWidget {
  const _ChecklistBanner({required this.onOpen, required this.onReady});

  final VoidCallback onOpen;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      color: DocklyColors.brandDeep,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: <Widget>[
              const DocklyIcon(DocklyIcons.checkCircle,
                  size: 18, color: Color(0xFF7FE7DC)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.checklistAsk,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('checklist-open'),
                onPressed: onOpen,
                child: Text(
                  t.checklistOpenBtn,
                  style: const TextStyle(
                    color: Color(0xFF7FE7DC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('checklist-ready'),
                onPressed: onReady,
                child: Text(
                  t.checklistReadyBtn,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBanner extends ConsumerWidget {
  const _ModeBanner({required this.text, required this.onCancel});

  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      color: DocklyColors.brandDeep,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: DocklyColors.accentTurquoise.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: DocklyIcon(DocklyIcons.place,
                      size: 14, color: Color(0xFF7FE3D9)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text(
                  t.cancelLabel,
                  style: TextStyle(
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ROTAYI KAYDET diyaloğu (rota planlama 2026-08): ad önerilir, Kaydet cihaza
/// yazar (başlangıç + duraklar — açılışta aynı motorla yeniden hesaplanır).
Future<void> _saveRouteDialog(
    BuildContext context, WidgetRef ref, MapState state) async {
  final L10n t = ref.read(l10nProvider);
  final RouteOrigin? origin = state.routeOrigin;
  final SeaRoutePlan? route = state.route;
  if (origin == null || route == null || state.routeWaypoints.isEmpty) return;
  final String originLabel =
      origin.name ?? (origin.isDevice ? t.routeOriginDevice : t.routeOriginPicked);
  final TextEditingController nameCtrl = TextEditingController(
    text: suggestRouteName(originLabel, state.routeWaypoints),
  );
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(t.routeSaveTitle),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: t.routeSaveNameHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.saveLabel),
        ),
      ],
    ),
  );
  final String name = nameCtrl.text.trim();
  nameCtrl.dispose(); // diyalog kapandı — denetleyici sızdırılmaz
  if (ok != true || !context.mounted) return;
  final int now = DateTime.now().millisecondsSinceEpoch;
  await ref.read(savedRoutesProvider.notifier).add(SavedRoute(
        id: 'r$now',
        name: name.isEmpty ? originLabel : name,
        origin: origin,
        waypoints: state.routeWaypoints,
        distanceNm: route.distanceNm,
        savedAtMs: now,
      ));
  if (!context.mounted) return;
  // GÜNLÜK KISAYOLU (kullanıcı onayı 2026-08): rota kaydedildi → tek
  // dokunuşla günlüğe not düşülür; rota bağlamı kendiliğinden eklenir.
  final LogContext logCtx = LogContext(
    routeName: name.isEmpty ? originLabel : name,
    distanceNm: route.distanceNm,
    stops: state.routeWaypoints.where((RouteWaypoint w) => w.isStop).length,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(t.routeSaved),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: t.logbookSnackAction,
        onPressed: () {
          if (context.mounted) {
            showLogEntryEditor(context, ref, logContext: logCtx);
          }
        },
      ),
    ));
}

/// Duraklardan numaralı harita rozetleri (1, 2, …). Tek duraklı rotada (yalnız
/// hedef) rozet çizilmez — hedefin pini zaten oradadır.
List<MapRouteStop> _stopMarkers(List<RouteWaypoint> wps) {
  final List<MapRouteStop> out = <MapRouteStop>[];
  int n = 0;
  for (final RouteWaypoint w in wps) {
    if (w.isStop) out.add(MapRouteStop(number: ++n, pos: w.pos));
  }
  return out.length <= 1 ? const <MapRouteStop>[] : out;
}

class _CenterProgress extends ConsumerWidget {
  const _CenterProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // İlk yükleme dost mesajı: sunucu ısınırken kullanıcı "uygulama bozuk"
    // sanmasın (P0 algı). Veri geldikten sonra görünmez.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              ref.watch(l10nProvider).loadingHarbors,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Çevrimdışı bilgi şeridi: bağlantı yokken cihazdaki son görülen limanların
/// gösterildiğini söyler. Haritayı gezdirmek yeniden denemeyi tetikler.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DocklyIcon(
              DocklyIcons.infoOutline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              ref.watch(l10nProvider).offlineBanner,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Harita üstü tip filtre çipleri: her çipte tipin harita rengi nokta olarak
/// bulunur — filtre + lejant tek bileşende. Boş seçim = tüm tipler.
class _TypeFilterRow extends ConsumerWidget {
  const _TypeFilterRow({required this.selected});

  final Set<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<String> types = DocklyMapColors.knownTypes.toList();
    final bool fitOn = ref.watch(mapFitFilterProvider);
    final bool hasBoat = ref.watch(myBoatProvider) != null;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: types.length + 1,
        separatorBuilder: (BuildContext _, int __) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int i) {
          // İlk çip: "Teknem sığar" — tekne yoksa dokununca tekne sayfası açılır.
          if (i == 0) {
            return Center(
              child: FilterChip(
                label: Text(t.fitChip),
                avatar: const DocklyIcon(
                  DocklyIcons.checkCircle,
                  size: 14,
                  color: DocklyColors.success,
                ),
                selected: fitOn,
                onSelected: (bool _) {
                  if (!hasBoat) {
                    showBoatSheet(context);
                    return;
                  }
                  ref.read(mapFitFilterProvider.notifier).state = !fitOn;
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          }
          final String type = types[i - 1];
          return Center(
            child: FilterChip(
              label: Text(t.typeLabel(type)),
              avatar: DocklyIcon(
                DocklyIcons.circle,
                size: 12,
                color: DocklyMapColors.forType(type),
              ),
              selected: selected.contains(type),
              onSelected: (bool _) =>
                  ref.read(mapControllerProvider.notifier).toggleType(type),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          ref.watch(l10nProvider).emptyArea,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TruncatedHint extends ConsumerWidget {
  const _TruncatedHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            ref.watch(l10nProvider).tooManyHint,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Acil Durum kısayolu (2026-08): kırmızı SOS — panikte tek dokunuş.
/// Bilinçli olarak üyelik kapısız; Acil Durum sayfası tamamen çevrimdışıdır.
class _SosButton extends ConsumerWidget {
  const _SosButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      elevation: 3,
      color: DocklyColors.error,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()),
        ),
        child: Tooltip(
          message: t.emergencyTitle,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Haritada arama kısayolu (2026-08): sekmeye gitmeden arama sayfasını açar.
class _MapSearchButton extends ConsumerWidget {
  const _MapSearchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: IconButton(
        icon: const DocklyIcon(DocklyIcons.search),
        tooltip: t.navSearch,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
        ),
      ),
    );
  }
}

/// Deniz rotası bilgi çipi: mesafe + kaba süre + dürüst uyarı notu +
/// (analiz gelince) rüzgâr satırı ve varış açık-yön uyarısı (Rota v2) +
/// DURAK LİSTESİ (rota düzenleme 2026-08: sıralı, ✕ ile çıkarılabilir).
/// Kapat düğmesi rotayı haritadan kaldırır.
class _RouteChip extends ConsumerWidget {
  const _RouteChip({
    required this.route,
    required this.onClear,
    this.wind,
    this.waypoints = const <RouteWaypoint>[],
    this.origin,
    this.onRemoveStop,
    this.onSave,
    this.onChangeOrigin,
    this.onAddPoint,
    this.label,
  });

  /// KAYITLI ROTA adı (kullanıcı isteği 2026-08): kayıttan açılan rotanın
  /// kullanıcı verdiği ismi başlıkta görünür.
  final String? label;

  final SeaRoutePlan route;
  final RouteWindReport? wind;
  final VoidCallback onClear;

  /// Rotanın sıralı ara noktaları (duraklar + tutamaç noktaları).
  final List<RouteWaypoint> waypoints;

  /// Rotanın başlangıcı — çipte "A:" satırı (rota planlama 2026-08).
  final RouteOrigin? origin;

  /// Çipteki ✕ ile durak çıkarma (dizin, durum listesine göredir).
  final void Function(int wpIndex)? onRemoveStop;

  /// Rotayı kaydet (yer imi simgesi).
  final VoidCallback? onSave;

  /// Başlangıcı değiştir ("A:" satırındaki bağlantı).
  final VoidCallback? onChangeOrigin;

  /// NOKTA EKLE modunu açar (kullanıcı isteği 2026-08): dokunarak ara nokta /
  /// durak ekleme — mobilde sürüklemeye alternatif en kolay yol.
  final VoidCallback? onAddPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final double hours = route.etaHoursAtCruise;
    final int h = hours.floor();
    final int min = ((hours - h) * 60).round();
    final String eta = h > 0
        ? L10n.fmt2(t.etaHmFmt, '$h', '$min')
        : L10n.fmt(t.etaMFmt, '$min');
    // Dürüstlük notu: rota tahminîdir; koya ulaşmadıysa ya da motor
    // çalışmadıysa (kuş uçuşu) bunu AÇIKÇA söyleriz.
    final String note = !route.viaSea
        ? t.routeDirectNote
        : (route.reachedGoal ? t.routeApproxNote : t.routeCoastNote);
    final RouteWindReport? w = wind;
    final int stopCount =
        waypoints.where((RouteWaypoint x) => x.isStop).length;
    final String metaTitle =
        '≈ ${_fmtNm(route.distanceNm)} ${t.nmUnit} · ~$eta';
    // Kayıtlı rota adıyla açıldıysa isim başa gelir: "Datça turu · ≈ 26 nm…"
    final String title =
        label == null ? metaTitle : '$label · $metaTitle';
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const DocklyIcon(
                  DocklyIcons.navigation,
                  size: 16,
                  color: DocklyColors.brandPrimary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    stopCount >= 2
                        ? '${L10n.fmt(t.routeStopsFmt, '$stopCount')} · $title'
                        : title,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // SEYİR ÖNCESİ KONTROL: liste çipten her an açılabilir.
                IconButton(
                  tooltip: t.checklistTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: const DocklyIcon(DocklyIcons.checkCircle, size: 17),
                  onPressed: () => showChecklistSheet(context),
                ),
                if (onSave != null)
                  IconButton(
                    icon: const DocklyIcon(DocklyIcons.bookmark, size: 17),
                    tooltip: t.routeSaveTitle,
                    visualDensity: VisualDensity.compact,
                    onPressed: onSave,
                  ),
                IconButton(
                  icon: const DocklyIcon(DocklyIcons.close, size: 18),
                  tooltip: t.routeClearTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                ),
              ],
            ),
            // BAŞLANGIÇ satırı (rota planlama 2026-08): A noktası + değiştir.
            if (origin != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        L10n.fmt(
                          t.routeOriginFmt,
                          origin!.name ??
                              (origin!.isDevice
                                  ? t.routeOriginDevice
                                  : t.routeOriginPicked),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (onChangeOrigin != null) ...<Widget>[
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onChangeOrigin,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          child: Text(
                            t.routeOriginChange,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: DocklyColors.brandPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // + NOKTA EKLE (kullanıcı isteği 2026-08): dokunarak
                    // ara nokta/durak ekleme modu — mobilde en kolay yol.
                    if (onAddPoint != null) ...<Widget>[
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onAddPoint,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const DocklyIcon(DocklyIcons.place,
                                  size: 12, color: DocklyColors.brandPrimary),
                              const SizedBox(width: 3),
                              Text(
                                t.routeAddPointBtn,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: DocklyColors.brandPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // DURAK LİSTESİ: 2+ durakta sıralı hap listesi; hedef dışındakiler
            // ✕ ile çıkarılabilir (mesafe/süre tüm bacakların toplamıdır).
            if (stopCount >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final (int wpIndex, int number, RouteWaypoint wp)
                        in _numberedStops())
                      _StopPill(
                        number: number,
                        name: wp.name ?? '',
                        isLast: wpIndex == waypoints.length - 1,
                        removeTooltip: t.routeStopRemoveTooltip,
                        onRemove: onRemoveStop == null ||
                                wpIndex == waypoints.length - 1
                            ? null
                            : () => onRemoveStop!(wpIndex),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                note,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            // RÜZGÂR SATIRI (Rota v2): rapor geldiyse — eşik renkleri rüzgâr
            // rozetiyle aynı (16 kn turuncu, 25 kn kırmızı).
            if (w != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  L10n.fmt2(
                        t.routeWindFmt,
                        w.worst.windKn.toStringAsFixed(0),
                        t.windExposedLabel(dir8Tr(w.worst.windDirDeg)),
                      ) +
                      (w.anyHeadwind ? ' · ${t.routeWindHeadwind}' : ''),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: w.warn ? FontWeight.w700 : FontWeight.w500,
                    color: w.strong
                        ? DocklyColors.error
                        : (w.warn
                            ? DocklyColors.warning
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            if (w != null && w.arrival != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  L10n.fmt2(
                    t.routeArrivalExposedFmt,
                    t.windExposedLabel(w.arrival!.dirTr),
                    w.arrival!.windKn.toStringAsFixed(0),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: w.arrival!.windKn >= kRouteWindStrongKn
                        ? DocklyColors.error
                        : DocklyColors.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Duraklar (isimli ara noktalar), rota sırasına göre numaralanmış:
  /// (durum dizini, sıra numarası, ara nokta).
  List<(int, int, RouteWaypoint)> _numberedStops() {
    final List<(int, int, RouteWaypoint)> out = <(int, int, RouteWaypoint)>[];
    int n = 0;
    for (int i = 0; i < waypoints.length; i++) {
      final RouteWaypoint w = waypoints[i];
      if (w.isStop) out.add((i, ++n, w));
    }
    return out;
  }
}

/// Çipteki durak hapı: sıra numarası + koy adı (+ hedef değilse ✕).
class _StopPill extends StatelessWidget {
  const _StopPill({
    required this.number,
    required this.name,
    required this.isLast,
    required this.removeTooltip,
    this.onRemove,
  });

  final int number;
  final String name;
  final bool isLast;
  final String removeTooltip;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color badge =
        isLast ? DocklyColors.accentTurquoise : DocklyColors.brandPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onRemove != null) ...<Widget>[
            const SizedBox(width: 3),
            Tooltip(
              message: removeTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: DocklyIcon(
                    DocklyIcons.close,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            DocklyButton(label: ref.watch(l10nProvider).retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
