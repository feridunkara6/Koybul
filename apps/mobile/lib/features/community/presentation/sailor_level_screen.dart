import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../application/reputation_controller.dart';
import 'badges_screen.dart';
import 'contribution_points_screen.dart';

/// Seviye eşikleri — SUNUCUDAKİ `LEVELS` ile birebir aynı olmalıdır.
/// Sunucu yalnız kodu gönderir; eşikleri burada göstermek "bir sonraki seviye
/// ne kadar uzakta" sorusunu ağ turu olmadan yanıtlar.
const List<({String code, int minPoints})> kSailorLevels = <({String code, int minPoints})>[
  (code: 'new', minPoints: 0),
  (code: 'coastal', minPoints: 150),
  (code: 'guide', minPoints: 600),
  (code: 'master', minPoints: 1500),
  (code: 'pilot', minPoints: 4000),
];

/// "Denizci Seviyem" ekranı — Teknem'deki Denizci Profilim kartından açılır.
///
/// Ekranın TEK işi beklentiyi doğru kurmak: seviye bir ETİKETTİR, ayrıcalık
/// değil. "Seviye ne işe yarar?" kutusu bu yüzden listeden ÖNCE gelir.
class SailorLevelScreen extends ConsumerWidget {
  const SailorLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<ReputationSummary> async = ref.watch(reputationSummaryProvider);
    final ReputationSummary s = async.valueOrNull ?? ReputationSummary.empty;
    final int? toNext = s.pointsToNext;
    final String nextCode = kSailorLevels
        .firstWhere(
          (({String code, int minPoints}) l) => l.minPoints > s.points,
          orElse: () => kSailorLevels.last,
        )
        .code;

    return Scaffold(
      appBar: AppBar(title: Text(t.levelScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          if (async.isLoading && s.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF0E8577), Color(0xFF071626)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const DocklyIcon(DocklyIcons.award, size: 22, color: Color(0xFF7FE3D9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.levelLabel(s.levelCode),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  L10n.fmt(t.levelPointsFmt, '${s.points}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFEAF6FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  toNext == null
                      ? t.levelTopReached
                      : L10n.fmt2(t.levelToNextFmt, t.levelLabel(nextCode), '$toNext'),
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFD7E6F5)),
                ),
              ],
            ),
          ),
          SectionCard(
            icon: DocklyIcons.infoOutline,
            title: t.levelWhatTitle,
            child: Text(
              t.levelWhatBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          for (final ({String code, int minPoints}) l in kSailorLevels)
            _LevelRow(
              label: t.levelLabel(l.code),
              // Bulunduğu seviyede eşik yerine "şu an" yazar: kaptan kendini
              // listede bir bakışta bulur.
              trailing: l.code == s.levelCode ? t.levelCurrentLabel : '${l.minPoints}',
              current: l.code == s.levelCode,
              reached: s.points >= l.minPoints,
            ),
          const SizedBox(height: 16),
          _NavRow(
            icon: DocklyIcons.award,
            label: t.badgesTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BadgesScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _NavRow(
            icon: DocklyIcons.star,
            label: t.pointsTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContributionPointsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.trailing,
    required this.current,
    required this.reached,
  });

  final String label;
  final String trailing;
  final bool current;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = current
        ? DocklyColors.accentTurquoise
        : (reached ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: current
            ? DocklyColors.accentTurquoise.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current
              ? DocklyColors.accentTurquoise.withValues(alpha: 0.45)
              : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        children: <Widget>[
          DocklyIcon(DocklyIcons.award, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: current ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            trailing,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: tint, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Profil'deki gezinme satırıyla aynı görsel dil (ikon + etiket + ok).
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final DocklyIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
