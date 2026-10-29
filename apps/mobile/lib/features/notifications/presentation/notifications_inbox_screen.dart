import 'dart:async' show unawaited;

import 'package:dockly_api/dockly_api.dart' show InboxItem;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/inbox_controller.dart';
import '../application/push_tap_router.dart';

/// BİLDİRİM KUTUSU (SP-2 Döngü, kurucu onayı 2026-10-31).
///
/// Telefona giden her kullanıcı bildirimi burada da durur — push kaçsa bile
/// olay kaybolmaz. Metin SUNUCUDAN GELMEZ: tür + data gelir, satır metni
/// kullanıcının kendi dilinde burada üretilir. Satıra dokununca push
/// dokunuşuyla AYNI yönlendirici çalışır (tek kapı: push_tap_router).
class NotificationsInboxScreen extends ConsumerStatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  ConsumerState<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState
    extends ConsumerState<NotificationsInboxScreen> {
  @override
  void initState() {
    super.initState();
    // Kutu açıldı → tümü okundu (en iyi çaba; rozet bir sonraki listede söner).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(markInboxRead(ref));
    });
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<InboxItem>> async = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.ntfInboxTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.peLoadFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(inboxProvider),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (List<InboxItem> items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.ntfInboxEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
            itemCount: items.length,
            itemBuilder: (BuildContext c, int i) => _InboxRowTile(
              item: items[i],
              t: t,
            ),
          );
        },
      ),
    );
  }
}

class _InboxRowTile extends ConsumerWidget {
  const _InboxRowTile({required this.item, required this.t});

  final InboxItem item;
  final L10n t;

  /// Tür + data → kullanıcı dilinde tek satır. Bilinmeyen tür dürüstçe
  /// genel metne düşer (eski sürüm, yeni tür — çökme yok, boş satır yok).
  String _line() {
    final String kind = item.data['kind'] ?? item.type;
    final String title = item.data['title'] ?? item.data['name'] ?? '';
    switch (kind) {
      case 'qa_answer':
        return L10n.fmt(t.ntfInQaFmt, title);
      case 'route_approved':
        return L10n.fmt(t.ntfInRouteOkFmt, title);
      case 'route_rejected':
        return L10n.fmt(t.ntfInRouteNoFmt, title);
      case 'event_cancelled':
        return L10n.fmt(t.ntfInEventCancelFmt, title);
      case 'event_reminder':
        return L10n.fmt(t.ntfInEventSoonFmt, title);
      case 'helpful_received':
        return L10n.fmt2(t.ntfInHelpfulFmt, title, item.data['count'] ?? '');
      case 'level_up':
        return L10n.fmt(
            t.ntfInLevelFmt, t.levelLabel(item.data['level'] ?? 'new'));
      default:
        return t.ntfInboxGeneric;
    }
  }

  DocklyIconData _icon() {
    final String kind = item.data['kind'] ?? item.type;
    return switch (kind) {
      'qa_answer' => DocklyIcons.chat,
      'route_approved' || 'route_rejected' => DocklyIcons.navigation,
      'event_cancelled' || 'event_reminder' => DocklyIcons.eventNoteOutlined,
      'helpful_received' => DocklyIcons.thumbUp,
      'level_up' => DocklyIcons.award,
      _ => DocklyIcons.infoOutline,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool unread = item.readAt == null;
    final String day =
        item.createdAt.length >= 10 ? item.createdAt.substring(0, 10) : '';
    return Container(
      key: ValueKey<String>('inbox-${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: unread
            ? DocklyColors.brandPrimary.withValues(alpha: 0.06)
            : theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Satır = push dokunuşuyla AYNI kapı (tek yönlendirici).
        onTap: () => ref.read(pushTapRouterProvider).route(item.data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: <Widget>[
              DocklyIcon(_icon(),
                  size: 18, color: DocklyColors.brandPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _line(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(day,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
