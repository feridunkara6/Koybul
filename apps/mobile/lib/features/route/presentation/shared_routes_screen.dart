import 'package:dockly_api/dockly_api.dart' show SharedRouteSummary;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../community/presentation/reputation_shell.dart'
    show formatCount, formatNm;
import '../application/shared_routes_controller.dart';
import 'shared_route_detail_screen.dart';

/// ROTA KEŞFİ (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24) — topluluğun
/// paylaştığı onaylı rotalar. Demodaki "Rota Keşfi" ekranının gerçeği:
/// Yeni/Popüler sıralaması + rota kartları. Okuma herkese açıktır.
class SharedRoutesScreen extends ConsumerWidget {
  const SharedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final String sort = ref.watch(sharedRoutesSortProvider);
    final AsyncValue<List<SharedRouteSummary>> async =
        ref.watch(sharedRoutesFeedProvider(sort));

    return Scaffold(
      appBar: AppBar(title: Text(t.rtDiscoverTitle)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: <Widget>[
                _SortChip(label: t.rtSortNew, value: 'new', current: sort),
                const SizedBox(width: 8),
                _SortChip(label: t.rtSortPopular, value: 'popular', current: sort),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(t.rtLoadFailed, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(sharedRoutesFeedProvider(sort)),
                      child: Text(t.retryLabel),
                    ),
                  ],
                ),
              ),
              data: (List<SharedRouteSummary> routes) => routes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          t.rtEmpty,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: routes.length,
                      itemBuilder: (BuildContext context, int i) =>
                          _RouteCard(r: routes[i], t: t),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends ConsumerWidget {
  const _SortChip({required this.label, required this.value, required this.current});

  final String label;
  final String value;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool on = current == value;
    return ChoiceChip(
      key: ValueKey<String>('rt-sort-$value'),
      label: Text(label),
      selected: on,
      onSelected: (_) =>
          ref.read(sharedRoutesSortProvider.notifier).state = value,
    );
  }
}

/// Rota kartı — demodaki kartın gerçeği: ad, güzergâh özeti, sayılar.
class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.r, required this.t});

  final SharedRouteSummary r;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey<String>('rt-card-${r.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => SharedRouteDetailScreen(routeId: r.id)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: .4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const DocklyIcon(DocklyIcons.navigation,
                        size: 16, color: DocklyColors.brandPrimary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.startName} → ${r.endName} · '
                  '${L10n.fmt(t.rtStopCountFmt, formatCount(t, r.stopCount))} · '
                  '${formatNm(t, r.distanceNm)} nm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: sub),
                ),
                const SizedBox(height: 3),
                Text(
                  <String>[
                    r.authorName,
                    if (r.season != null)
                      L10n.fmt(t.rtSeasonFmt, r.season!),
                    '💾 ${formatCount(t, r.saveCount)}',
                    '✓ ${formatCount(t, r.doneCount)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
