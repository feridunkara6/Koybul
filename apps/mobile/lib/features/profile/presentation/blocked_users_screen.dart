import 'package:dockly_api/dockly_api.dart' show BlockedUser;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/block_controller.dart';
import 'captain_avatar.dart';

/// ENGELLEDİKLERİM (ENG-1, kurucu onayı 2026-11-03).
///
/// Profil → Uygulama altından açılır. Satırdaki düğme engeli kaldırır;
/// kişinin içerikleri yeniden görünür olur (düşen takip bağları geri
/// GELMEZ — bilinçli karar, onay sayfasında da yazar). Liste yalnız
/// sahibine iner; karşı taraf engellendiğini hiçbir yerden görmez.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<BlockedUser>> async = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.blockedListTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.actionFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(blockedUsersProvider),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (List<BlockedUser> list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  t.blockedListEmpty,
                  key: const ValueKey<String>('blocked-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (BuildContext context, int i) =>
                _BlockedRow(b: list[i], t: t),
          );
        },
      ),
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({required this.b, required this.t});

  final BlockedUser b;
  final L10n t;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  Future<void> _unblock() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(blockActionsProvider)
          .setBlocked(widget.b.id, blocked: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(widget.t.actionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = widget.t;
    final ThemeData theme = Theme.of(context);
    final DateTime d = widget.b.blockedAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
      ),
      child: Row(
        children: <Widget>[
          CaptainAvatar(
              name: widget.b.displayName, seed: widget.b.id, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.b.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  L10n.fmt(t.blockedAtFmt, '${d.day}.${d.month}.${d.year}'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: ValueKey<String>('blocked-undo-${widget.b.id}'),
            onPressed: _busy ? null : _unblock,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(t.unblockMenuItem),
          ),
        ],
      ),
    );
  }
}
