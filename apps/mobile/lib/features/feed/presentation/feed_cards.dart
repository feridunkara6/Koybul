import 'package:dockly_api/dockly_api.dart' show FeedItem;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../profile/presentation/captain_avatar.dart';
import '../../profile/presentation/captain_profile_screen.dart';
import '../../route/presentation/shared_route_detail_screen.dart';
import '../application/feed_controller.dart';

/// TAKİP AKIŞI kartları (SP-3b, kurucu onayı 2026-10-31).
///
/// Üç tür: seyir (⚓ Pruvan neta tepkili), not, rota. Yazar satırına
/// dokununca kaptan kartı açılır (SP-1 köprüsü); rota kartı rota detayına
/// gider. Kart yalnız SUNUCUDAN geleni gösterir (0-uydurma).

/// Mesafe metni — '42.0' değil '42' (Defter'deki biçimle aynı dürüst sadelik).
String _fmtNm(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// 'YYYY-MM-DD' → 'G.A.YYYY' (karttaki kısa tarih).
String _fmtDay(String iso) {
  if (iso.length < 10) return iso;
  final int? y = int.tryParse(iso.substring(0, 4));
  final int? m = int.tryParse(iso.substring(5, 7));
  final int? d = int.tryParse(iso.substring(8, 10));
  if (y == null || m == null || d == null) return iso;
  return '$d.$m.$y';
}

class FeedItemCard extends ConsumerWidget {
  const FeedItemCard({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    // Eylem metni ad'dan SONRA gelir — dört dilde de doğal sıra.
    final String action = switch (item.kind) {
      'trip' => t.fdTripAct,
      'note' => t.fdNoteAct,
      _ => t.fdRouteAct,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // YAZAR SATIRI — kaptan kartına köprü (SP-1 kimlik zinciri).
          InkWell(
            key: ValueKey<String>('feed-author-${item.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CaptainProfileScreen(userId: item.authorId),
              ),
            ),
            child: Row(
              children: <Widget>[
                CaptainAvatar(
                    name: item.authorName, seed: item.authorId, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: item.authorName,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: ' $action',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtDay(item.createdAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          switch (item.kind) {
            'trip' => _TripBody(item: item, t: t),
            'note' => _NoteBody(item: item, t: t),
            _ => _RouteBody(item: item, t: t),
          },
        ],
      ),
    );
  }
}

/// SEYİR gövdesi: rota satırı + yapısal sayılar + ⚓ Pruvan neta.
class _TripBody extends StatelessWidget {
  const _TripBody({required this.item, required this.t});

  final FeedItem item;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Başlangıç paylaşılmamışsa (Konumum) yalnız varış gösterilir — dürüst.
    final String route = <String>[
      if (item.startName != null) item.startName!,
      if (item.endName != null) item.endName!,
    ].join(' → ');
    final String stats = <String>[
      if ((item.distanceNm ?? 0) > 0) '≈ ${_fmtNm(item.distanceNm!)} ${t.nmUnit}',
      if (item.durationMin != null && item.durationMin! >= 60)
        L10n.fmt(t.hoursShortFmt, '${(item.durationMin! / 60).round()}'),
      if ((item.stopCount ?? 0) > 0) '${t.routeStatStops}: ${item.stopCount}',
      if (item.sailedOn != null) _fmtDay(item.sailedOn!),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const DocklyIcon(DocklyIcons.sailing,
                size: 16, color: DocklyColors.brandPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                route.isEmpty ? t.fdTripTag : route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (stats.isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Text(stats,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 8),
        _PruvaButton(item: item),
      ],
    );
  }
}

/// NOT gövdesi: koy adı + tür etiketi + kırpılmış metin.
class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.item, required this.t});

  final FeedItem item;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String header = <String>[
      if (item.noteKind != null) t.noteKindLabel(item.noteKind!),
      if (item.locationName != null) item.locationName!,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (header.isNotEmpty)
          Row(
            children: <Widget>[
              const DocklyIcon(DocklyIcons.eventNoteOutlined,
                  size: 16, color: DocklyColors.accentTurquoise),
              const SizedBox(width: 8),
              Expanded(
                child: Text(header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        if (item.body != null && item.body!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(item.body!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
        ],
      ],
    );
  }
}

/// ROTA gövdesi: ad + kaydetme sayısı; dokununca rota detayı.
class _RouteBody extends StatelessWidget {
  const _RouteBody({required this.item, required this.t});

  final FeedItem item;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String stats = <String>[
      if ((item.stopCount ?? 0) > 0) '${t.routeStatStops}: ${item.stopCount}',
      if ((item.saveCount ?? 0) > 0) '${t.rtSaveBtn}: ${item.saveCount}',
    ].join(' · ');
    return InkWell(
      key: ValueKey<String>('feed-route-${item.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SharedRouteDetailScreen(routeId: item.id),
        ),
      ),
      child: Row(
        children: <Widget>[
          const DocklyIcon(DocklyIcons.compass,
              size: 16, color: DocklyColors.brandPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.routeName ?? t.cpRouteTag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (stats.isNotEmpty)
                  Text(stats,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          DocklyIcon(DocklyIcons.arrowForward,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// "⚓ Pruvan neta" düğmesi — sunucu sayacıyla yerinde güncellenir; eylem
/// sürerken kilitlenir. Akış hesaba kapalı yüzeydedir, kapı gerekmez.
class _PruvaButton extends ConsumerStatefulWidget {
  const _PruvaButton({required this.item});

  final FeedItem item;

  @override
  ConsumerState<_PruvaButton> createState() => _PruvaButtonState();
}

class _PruvaButtonState extends ConsumerState<_PruvaButton> {
  bool _busy = false;

  /// Yerel geçersiz kılma — toggle sonrası sunucu değerleri (akış kartı
  /// zıplamadan güncellensin; doğruluk kaynağı yine sunucu yanıtı).
  bool? _reacted;
  int? _count;

  Future<void> _toggle() async {
    final L10n t = ref.read(l10nProvider);
    setState(() => _busy = true);
    try {
      final ({bool reacted, int pruvaCount}) res =
          await ref.read(feedActionsProvider).togglePruva(widget.item.id);
      if (mounted) {
        setState(() {
          _reacted = res.reacted;
          _count = res.pruvaCount;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(t.actionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final bool on = _reacted ?? (widget.item.myPruva ?? false);
    final int count = _count ?? (widget.item.pruvaCount ?? 0);
    final Color fg =
        on ? DocklyColors.brandPrimary : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      key: ValueKey<String>('feed-pruva-${widget.item.id}'),
      borderRadius: BorderRadius.circular(999),
      onTap: _busy ? null : _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on
              ? DocklyColors.brandPrimary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on
                ? DocklyColors.brandPrimary
                : theme.colorScheme.outline.withValues(alpha: .6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('⚓', style: TextStyle(fontSize: 13, color: fg)),
            const SizedBox(width: 6),
            Text(
              count > 0 ? '${t.fdPruva} · $count' : t.fdPruva,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
