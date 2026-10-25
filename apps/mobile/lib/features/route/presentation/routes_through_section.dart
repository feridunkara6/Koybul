import 'package:dockly_api/dockly_api.dart' show SharedRouteSummary;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../community/presentation/reputation_shell.dart' show formatNm;
import '../application/shared_routes_controller.dart';
import 'shared_route_detail_screen.dart';

/// "BURADAN GEÇEN ROTALAR" (Sosyalleşme Hafta 4, kurucu onayı 2026-10-24) —
/// koy detayında, bu durağı içeren onaylı topluluk rotaları.
///
/// Dürüstlük kuralları Bugün kartlarıyla aynı: veri yok/yükleniyor/hata →
/// bölüm KENDİNİ HİÇ ÇİZMEZ (koy sayfası dönen çember ya da boş iskeletle
/// dolmaz). En fazla 3 rota gösterilir; dokunuş rota kartını açar.
class RoutesThroughSection extends ConsumerWidget {
  const RoutesThroughSection({required this.locationId, super.key});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<SharedRouteSummary>? routes =
        ref.watch(routesThroughLocationProvider(locationId)).valueOrNull;
    if (routes == null || routes.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        icon: DocklyIcons.navigation,
        title: t.rtThroughTitle,
        child: Column(
          children: <Widget>[
            for (final SharedRouteSummary r in routes.take(3))
              InkWell(
                key: ValueKey<String>('rt-through-${r.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => SharedRouteDetailScreen(routeId: r.id)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: <Widget>[
                      const Text('🧭', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              '${r.startName} → ${r.endName} · '
                              '${formatNm(t, r.distanceNm)} nm',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: sub),
                            ),
                          ],
                        ),
                      ),
                      DocklyIcon(DocklyIcons.arrowForward, size: 14, color: sub),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
