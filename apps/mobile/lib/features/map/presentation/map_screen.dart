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
import '../../route/domain/sea_route.dart';
import '../../route/domain/sea_router.dart';
import '../../search/presentation/search_screen.dart';
import '../application/map_controller.dart';
import '../domain/map_state.dart';
import 'location_bottom_card.dart';
import 'map_surface.dart';

/// Harita ekranı (S-06). Somut harita yüzeyi üstüne durum katmanları:
/// yükleme, boş, hata+retry, "çok fazla sonuç" ipucu (docs/26 §4, docs/23 §9.5).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapState state = ref.watch(mapControllerProvider);
    final MapController controller = ref.read(mapControllerProvider.notifier);
    final MapSurfaceBuilder surfaceBuilder = ref.watch(mapSurfaceBuilderProvider);
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
                    ),
                    MapSurfaceCallbacks(
                      onViewportChanged: controller.onViewportChanged,
                      onPinTap: controller.selectPin,
                      onClusterTap: (_) => controller.clearSelection(),
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
                          onClear: controller.clearRoute,
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
              child: LocationBottomCard(
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
                onRoute: () {
                  final bool hasOrigin = ref.read(devicePositionProvider) != null ||
                      ref.read(originProvider) != null;
                  if (!hasOrigin) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(ref.read(l10nProvider).routeNeedOrigin),
                      ));
                    return;
                  }
                  controller.routeToPin(selectedPin);
                },
              ),
            ),
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

/// Deniz rotası bilgi çipi: mesafe + kaba süre + dürüst uyarı notu.
/// Kapat düğmesi rotayı haritadan kaldırır.
class _RouteChip extends ConsumerWidget {
  const _RouteChip({required this.route, required this.onClear});

  final SeaRoutePlan route;
  final VoidCallback onClear;

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
                    '≈ ${_fmtNm(route.distanceNm)} ${t.nmUnit} · ~$eta',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const DocklyIcon(DocklyIcons.close, size: 18),
                  tooltip: t.routeClearTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                note,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
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
