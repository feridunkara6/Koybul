import 'package:dockly_api/dockly_api.dart' show AdminPremiumGrant, AdminStats;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../community/presentation/moderation_screen.dart';
import '../application/admin_controller.dart';

/// YÖNETİM PANELİ ekranı (Konsept onayı 2026-09-25): sayı kartları + elle
/// premium tanımlama + moderasyon kısayolu. Telefonda ve web'de aynı ekran.
/// Görünürlük Profil'deki satırda `isAdminProvider` ile; YETKİ sunucuda.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<AdminStats> stats = ref.watch(adminStatsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.admTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminStatsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Text(
              t.admLead,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => _ErrorCard(
                message: e is AppFailure ? e.message : '$e',
                onRetry: () => ref.invalidate(adminStatsProvider),
              ),
              data: (AdminStats s) => _StatsGrid(stats: s, t: t),
            ),
            const SizedBox(height: 20),
            const _GrantCard(),
            const SizedBox(height: 14),
            // Moderasyon kısayolu — bekleyen sayısı kartlarda zaten görünür.
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const ValueKey<String>('admin-moderation'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ModerationScreen()),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const DocklyIcon(DocklyIcons.checkCircle,
                          size: 20, color: DocklyColors.brandPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t.navModeration,
                            style: theme.textTheme.bodyMedium),
                      ),
                      DocklyIcon(DocklyIcons.arrowForward,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // DÜRÜSTLÜK NOTU: indirme sayısı bizim sunucuda yoktur.
            Text(
              t.admDownloadsNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.t});

  final AdminStats stats;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final List<(String, int, Color)> items = <(String, int, Color)>[
      (t.admUsers, stats.totalUsers, DocklyColors.brandPrimary),
      (t.admNew7d, stats.newUsers7d, DocklyColors.accentTurquoise),
      (t.admPremium, stats.premiumActive, DocklyColors.warning),
      (t.admPending, stats.pendingModeration, DocklyColors.error),
      (t.admGuests, stats.guestUsers, DocklyColors.text2),
      (t.admReviews, stats.totalReviews, DocklyColors.brandDeep),
      (t.admNotes, stats.totalNotes, DocklyColors.success),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final (String label, int value, Color color) in items)
          _StatCard(label: label, value: value, color: color),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Elle premium tanımlama kartı: e-posta + süre + tanımla.
class _GrantCard extends ConsumerStatefulWidget {
  const _GrantCard();

  @override
  ConsumerState<_GrantCard> createState() => _GrantCardState();
}

class _GrantCardState extends ConsumerState<_GrantCard> {
  final TextEditingController _email = TextEditingController();
  int _months = 12;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    final L10n t = ref.read(l10nProvider);
    final String email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    setState(() => _busy = true);
    try {
      final AdminPremiumGrant r = await ref
          .read(adminGatewayProvider)
          .grantPremium(email: email, months: _months);
      if (!mounted) return;
      final String until =
          '${r.premiumUntil.day}.${r.premiumUntil.month}.${r.premiumUntil.year}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(L10n.fmt2(t.admGrantDoneFmt, r.email, until))));
      _email.clear();
      ref.invalidate(adminStatsProvider); // premium sayısı anında tazelensin
    } on AppFailure catch (f) {
      if (!mounted) return;
      final String msg =
          f is NotFoundFailure ? t.admNotFound : f.message;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DocklyColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DocklyColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(t.admGrantTitle,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(t.admGrantHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('admin-grant-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: t.admEmailLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SegmentedButton<int>(
                  segments: <ButtonSegment<int>>[
                    for (final int m in const <int>[1, 3, 12])
                      ButtonSegment<int>(
                        value: m,
                        label: Text(L10n.fmt(t.admMonthsFmt, '$m'),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  selected: <int>{_months},
                  onSelectionChanged: (Set<int> v) =>
                      setState(() => _months = v.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('admin-grant-btn'),
              onPressed: _busy ? null : _grant,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.admGrantBtn),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(message,
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('↻')),
      ],
    );
  }
}
