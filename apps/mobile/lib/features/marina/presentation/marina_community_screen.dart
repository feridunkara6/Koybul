import 'package:dockly_api/dockly_api.dart' show MarinaBoat, MarinaCommunity;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/marina_controller.dart';

/// MARİNA TOPLULUĞU ekranı (onaylı görsel konsept Ekran 12-13-16).
///
/// Sayılar HERKESE görünür ve "beyana dayalı" dürüstlük notu taşır. Liste,
/// sunucunun erişim kararına göre gelir (kendi marinan ücretsiz; gezinti
/// Premium; kilit sunucuda). Liste yalnız 'Marinada görün'ü açanları taşır;
/// kapatanlar "+N tekne gizli" satırında İSİMSİZ toplanır.
class MarinaCommunityScreen extends ConsumerWidget {
  const MarinaCommunityScreen({required this.marinaId, super.key});

  final String marinaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<MarinaCommunity> community =
        ref.watch(marinaCommunityProvider(marinaId));

    return Scaffold(
      appBar: AppBar(title: Text(t.marinamTitle)),
      body: community.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(e is AppFailure ? e.message : '$e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(marinaCommunityProvider(marinaId)),
                  child: Text(t.retryLabel),
                ),
              ],
            ),
          ),
        ),
        data: (MarinaCommunity c) => _Body(c: c, t: t),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.c, required this.t});

  final MarinaCommunity c;
  final L10n t;

  Future<void> _copyInvite(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: L10n.fmt(t.mcInviteTextFmt, c.marinaName)),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.mcInviteCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    // "Yalnız benim teknem var" da boş rıhtım sayılır (konsept Ekran 16).
    final bool empty = c.full && c.boats.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        // KAHRAMAN KARTI — Kaptan Kartı ailesinden degrade + sayı kutuları.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[DocklyColors.brandDeep, DocklyColors.brandPrimary],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(c.marinaName,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  _CountBox(value: '${c.total}', label: t.mcTotalCap),
                  const SizedBox(width: 10),
                  _CountBox(value: '${c.visibleCount}', label: t.mcVisibleCap),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // DÜRÜSTLÜK NOTU: beyana dayalı, canlı veri (uydurma kesinlik yok).
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('ℹ️ ${t.mcBeyanNote}',
              style: theme.textTheme.bodySmall?.copyWith(color: sub)),
        ),
        const SizedBox(height: 14),

        if (!c.full) ...<Widget>[
          // Liste kilitli: ya henüz katılmadı (kendi marinası olabilir) ya
          // başka marinayı geziyor (Premium). İki dürüst satır birden —
          // istemci sunucunun gerekçesini TAHMİN ETMEZ.
          Container(
            key: const ValueKey<String>('mc-locked'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.primary, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  DocklyIcon(DocklyIcons.lockOutline,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(t.mcVisibleBoatsCap,
                          style: theme.textTheme.titleSmall)),
                ]),
                const SizedBox(height: 8),
                Text(t.mcJoinPrompt,
                    style: theme.textTheme.bodySmall?.copyWith(color: sub)),
                const SizedBox(height: 6),
                Text(t.mcPremiumBody,
                    style: theme.textTheme.bodySmall?.copyWith(color: sub)),
              ],
            ),
          ),
        ] else if (empty) ...<Widget>[
          // BOŞ DURUM (Ekran 16): hata gibi değil, öncülük gibi hissettirir.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: <Widget>[
                const Text('🧭', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(t.mcEmptyTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  t.mcEmptyBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: sub),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey<String>('mc-invite'),
                  onPressed: () => _copyInvite(context),
                  child: Text(t.mcInviteCta),
                ),
              ],
            ),
          ),
        ] else ...<Widget>[
          Text(t.mcVisibleBoatsCap,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: sub, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final MarinaBoat b in c.boats) _BoatRow(b: b, t: t),
          if (c.hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: theme.dividerColor.withValues(alpha: .4)),
                ),
                child: Row(children: <Widget>[
                  const DocklyIcon(DocklyIcons.lockOutline,
                      size: 16, color: DocklyColors.text2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      L10n.fmt(t.mcHiddenFmt, '${c.hiddenCount}'),
                      style: theme.textTheme.bodySmall?.copyWith(color: sub),
                    ),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey<String>('mc-invite'),
            onPressed: () => _copyInvite(context),
            child: Text(t.mcInviteCta),
          ),
        ],
      ],
    );
  }
}

class _CountBox extends StatelessWidget {
  const _CountBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 9,
                    letterSpacing: .3,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _BoatRow extends StatelessWidget {
  const _BoatRow({required this.b, required this.t});

  final MarinaBoat b;
  final L10n t;

  static const Set<String> _sailTypes = <String>{'sailboat', 'catamaran', 'gulet'};

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    final List<String> specs = <String>[
      if (b.lengthM != null) '${_num(b.lengthM!)} m',
      if (b.brand != null && b.brand!.isNotEmpty) b.brand!,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_sailTypes.contains(b.boatTypeCode) ? '⛵' : '🛥️',
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(b.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(
                    <String>[
                      if (specs.isNotEmpty) specs.join(' · '),
                      L10n.fmt(t.mcCaptainFmt, b.captainName),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
