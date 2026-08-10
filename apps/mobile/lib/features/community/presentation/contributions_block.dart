import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/reputation_controller.dart';
import 'moderation_screen.dart';
import 'my_contributions_screen.dart';

/// PROFİL ekranındaki katkı sayaç bloğu: Yayında · İncelemede · Reddedilen.
///
/// Hesap kartının hemen altına girer; Acil Durum kartı, tekne bölümü, dil
/// satırı ve 6 kısayol AYNEN kalır. HESAP YOKSA HİÇ ÇİZİLMEZ.
class ContributionsBlock extends ConsumerWidget {
  const ContributionsBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasRealAccountProvider)) return const SizedBox.shrink();

    final L10n t = ref.watch(l10nProvider);
    final ReputationSummary s =
        ref.watch(reputationSummaryProvider).valueOrNull ?? ReputationSummary.empty;

    return Padding(
      key: const ValueKey<String>('contributions-block'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: <Widget>[
          _CountRow(
            icon: DocklyIcons.checkCircle,
            color: DocklyColors.success,
            label: t.contribTabPublished,
            count: s.approvedCount,
            status: 'approved',
          ),
          const SizedBox(height: 8),
          _CountRow(
            icon: DocklyIcons.amClock,
            color: DocklyColors.warning,
            label: t.contribTabPending,
            count: s.pendingCount,
            status: 'pending',
          ),
          const SizedBox(height: 8),
          _CountRow(
            icon: DocklyIcons.clear,
            color: DocklyColors.error,
            label: t.contribTabRejected,
            count: s.rejectedCount,
            status: 'rejected',
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.status,
  });

  final DocklyIconData icon;
  final Color color;
  final String label;
  final int count;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('contrib-$status'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyContributionsScreen(initialStatus: status),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                '$count',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profil'deki MODERASYON satırı — yalnız `moderator` (ve üstü) rolüne
/// görünür. Sunucu ayrıca `@MinRole('moderator')` ile korur.
class ModerationRow extends ConsumerWidget {
  const ModerationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isModeratorProvider)) return const SizedBox.shrink();

    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final int pending = (ref.watch(moderationCountsProvider).valueOrNull ??
            const <String, int>{})
        .values
        .fold<int>(0, (int a, int b) => a + b);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey<String>('profile-moderation'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ModerationScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: <Widget>[
                DocklyIcon(DocklyIcons.flag, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(t.navModeration, style: theme.textTheme.bodyMedium)),
                if (pending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DocklyColors.warning.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$pending',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                DocklyIcon(DocklyIcons.arrowForward,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
