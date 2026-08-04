import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../location/application/location_controller.dart';
import '../../map/application/map_controller.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/saved_routes_controller.dart';
import '../domain/saved_route.dart';
import '../domain/sea_route.dart' show etaHours;

/// KAYITLI ROTALAR (rota planlama 2026-08): cihazdaki rota kayıtları.
/// "Haritada aç" rotayı kayıtlı başlangıç + duraklardan AYNI motorla yeniden
/// hesaplar (dürüstlük: eski çizgi asla gösterilmez); çöp kutusu siler.
class SavedRoutesScreen extends ConsumerWidget {
  const SavedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<SavedRoute> routes = ref.watch(savedRoutesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.savedRoutesTitle)),
      body: routes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.savedEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: routes.length,
              itemBuilder: (BuildContext context, int i) =>
                  _SavedRouteCard(route: routes[i]),
            ),
    );
  }
}

class _SavedRouteCard extends ConsumerWidget {
  const _SavedRouteCard({required this.route});

  final SavedRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final double hours = etaHours(route.distanceNm);
    final int h = hours.floor();
    final int min = ((hours - h) * 60).round();
    final String eta = h > 0
        ? L10n.fmt2(t.etaHmFmt, '$h', '$min')
        : L10n.fmt(t.etaMFmt, '$min');
    String meta =
        '≈ ${route.distanceNm >= 10 ? route.distanceNm.round() : route.distanceNm.toStringAsFixed(1)} ${t.nmUnit} · ~$eta';
    if (route.stopCount >= 2) {
      meta = '${L10n.fmt(t.routeStopsFmt, '${route.stopCount}')} · $meta';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: DocklyIcon(DocklyIcons.navigation,
                  size: 18, color: DocklyColors.brandPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(route.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => _open(context, ref),
            child: Text(t.savedOpenBtn),
          ),
          IconButton(
            tooltip: t.savedDeleteTooltip,
            icon: DocklyIcon(DocklyIcons.deleteOutline,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () =>
                ref.read(savedRoutesProvider.notifier).remove(route.id),
          ),
        ],
      ),
    );
  }

  /// "Haritada aç": Konumum başlangıçlı kayıtta GPS şartı burada denetlenir;
  /// sonra Keşfet sekmesine dönülür ve rota yeniden hesaplanır.
  void _open(BuildContext context, WidgetRef ref) {
    final L10n t = ref.read(l10nProvider);
    if (route.origin.isDevice) {
      final GeoPoint? gps = ref.read(devicePositionProvider);
      if (gps == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(t.routeNeedOrigin),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: t.locateTooltip,
              onPressed: () =>
                  ref.read(locationControllerProvider.notifier).locateMe(),
            ),
          ));
        return;
      }
    }
    ref
        .read(mapControllerProvider.notifier)
        .openSavedRoute(route.origin, route.waypoints);
    ref.read(shellTabProvider.notifier).state = 0; // Keşfet'e dön
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
  }
}
