import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/reputation_controller.dart';

/// Rozet koduna karşılık gelen ikon. Bilinmeyen kod (sunucu yeni rozet
/// eklerse) genel rozet ikonuna düşer — ekran çökmez.
DocklyIconData badgeIcon(String code) => switch (code) {
      'area_expert' => DocklyIcons.place,
      'lighthouse' => DocklyIcons.thumbUp,
      'safety_watch' => DocklyIcons.shield,
      'winter_sailor' => DocklyIcons.snowflake,
      'region_traveler' => DocklyIcons.compass,
      'first_explorer' => DocklyIcons.mapOutlined,
      'reliable_reporter' => DocklyIcons.checkCircle,
      'verified_boat' => DocklyIcons.sailing,
      _ => DocklyIcons.award,
    };

/// "Rozetlerim" ekranı — Denizci Seviyem'den açılır.
///
/// Kazanılmayan rozetler GİZLENMEZ: nasıl kazanıldığı ve nerede kalındığı
/// yazar. Altyapısı henüz olmayan rozetler "yakında" etiketiyle dürüstçe
/// işaretlenir — sessizce çıkarmak, kaptanı boşuna uğraştırmak olurdu.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<ReputationSummary> async = ref.watch(reputationSummaryProvider);
    final ReputationSummary s = async.valueOrNull ?? ReputationSummary.empty;
    final List<BadgeProgress> earned = s.earnedBadges;
    final List<BadgeProgress> locked = s.lockedBadges;

    return Scaffold(
      appBar: AppBar(title: Text(t.badgesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          if (async.isLoading && s.badges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (earned.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t.badgesEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          for (final BadgeProgress b in earned) BadgeRow(badge: b),
          if (locked.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              t.badgesLockedTitle,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final BadgeProgress b in locked) BadgeRow(badge: b),
          ],
        ],
      ),
    );
  }
}

/// Tek rozet satırı: ikon + ad + koşul + (kazanılmadıysa) ilerleme çubuğu.
/// Testlerde doğrudan bulunabilsin diye public.
class BadgeRow extends ConsumerWidget {
  const BadgeRow({required this.badge, super.key});

  final BadgeProgress badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final Color tint = badge.earned
        ? DocklyColors.accentTurquoise
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      key: ValueKey<String>('badge-${badge.code}-${badge.scopeId ?? 'global'}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: badge.earned
            ? DocklyColors.accentTurquoise.withValues(alpha: 0.07)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.earned
              ? DocklyColors.accentTurquoise.withValues(alpha: 0.40)
              : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DocklyIcon(badgeIcon(badge.code), size: 20, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        t.badgeName(badge.code, scopeName: badge.scopeName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    // Altyapısı olmayan rozet: "yakında". Kaptan boşuna
                    // uğraşmasın diye SÖYLENİR, gizlenmez.
                    if (!badge.automatic) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: DocklyColors.warning.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.badgeSoon,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF92400E),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t.badgeDesc(badge.code, badge.target),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                ),
                // İlerleme YALNIZ otomatik verilebilen ve kazanılmamış
                // rozetlerde çizilir: "0/1" hiçbir şey anlatmaz.
                if (!badge.earned && badge.automatic) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: badge.ratio,
                            minHeight: 5,
                            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${badge.current}/${badge.target}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
