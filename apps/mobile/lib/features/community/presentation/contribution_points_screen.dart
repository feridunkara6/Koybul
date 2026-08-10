import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/reputation_controller.dart';
import 'reputation_shell.dart';

/// "Katkı puanı" dökümü — hangi davranış kaç puan getirdi.
///
/// Bu ekran bir OYUN TABLOSU DEĞİLDİR: liderlik sıralaması, seri göstergesi
/// ya da hedef yoktur. Amacı tek: puanın nereden geldiğini şeffaf göstermek,
/// böylece sistem keyfî görünmesin.
class ContributionPointsScreen extends ConsumerWidget {
  const ContributionPointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ContributionItem>> async = ref.watch(contributionsProvider);
    final AsyncValue<ReputationSummary> summary = ref.watch(reputationSummaryProvider);
    final List<ContributionItem> items = async.valueOrNull ?? const <ContributionItem>[];
    final ReputationSummary s = summary.valueOrNull ?? ReputationSummary.empty;
    // Her sayı KENDİ kaynağının durumuna bakar: döküm düşse bile özet
    // geldiyse puan gösterilir, tersi de doğrudur. İkisini tek bayrağa
    // bağlamak sağlam veriyi de gizliyordu (inceleme bulgusu 2026-08).
    final bool summaryFailed = summary.valueOrNull == null && summary.hasError;
    final bool listFailed = async.valueOrNull == null && async.hasError;

    return Scaffold(
      appBar: AppBar(title: Text(t.pointsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          if (summaryFailed || listFailed) ...<Widget>[
            ReputationErrorBox(
              isRetrying: summary.isLoading || async.isLoading,
              // Düşen İSTEK tazelenir; yalnız özeti yenilemek düğmeyi
              // çalışmıyormuş gibi gösterirdi.
              onRetry: () {
                if (summaryFailed) ref.invalidate(reputationSummaryProvider);
                if (listFailed) ref.invalidate(contributionsProvider);
              },
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                summaryFailed ? '—' : formatCount(t, s.points),
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  t.sailorPointsCap,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            L10n.fmt(t.pointsTrustFmt, summaryFailed ? '—' : s.trustScore.toStringAsFixed(2)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (async.isLoading && items.isEmpty)
            const ReputationLoadingBox()
          else if (items.isEmpty && !listFailed)
            Text(
              t.pointsEmpty,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            for (final ContributionItem c in items) _PointRow(item: c),
          const SizedBox(height: 14),
          Text(
            t.pointsCapNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointRow extends ConsumerWidget {
  const _PointRow({required this.item});

  final ContributionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final bool penalty = item.points < 0;
    final Color tint = penalty ? DocklyColors.error : DocklyColors.success;
    return Container(
      key: ValueKey<String>('point-${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  t.contributionLabel(item.type),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _shortDate(item.createdAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            // 0 puanlı olay da listelenir (tavan dolduysa). "+0" yerine düz 0
            // yazılır: kaptan katkısının kaydedildiğini görsün.
            item.points > 0
                ? '+${formatCount(t, item.points)}'
                : formatCount(t, item.points),
            style: theme.textTheme.titleSmall?.copyWith(
              color: item.points == 0 ? theme.colorScheme.onSurfaceVariant : tint,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// ISO tarihi "8.8.2026" biçimine indirger. Ayrıştırılamazsa ham ilk 10
  /// karakter gösterilir — ekran hiçbir koşulda çökmez.
  static String _shortDate(String iso) {
    final DateTime? d = DateTime.tryParse(iso);
    if (d == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
    final DateTime l = d.toLocal();
    return '${l.day}.${l.month}.${l.year}';
  }
}
