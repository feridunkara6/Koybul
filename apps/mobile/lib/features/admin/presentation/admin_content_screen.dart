import 'package:dockly_api/dockly_api.dart' show AdminContentItem;
import 'package:dockly_core/dockly_core.dart' show AppFailure;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/admin_controller.dart';

/// İÇERİK YÖNETİMİ ekranı (kurucu talebi 2026-10-27): yönetici, uygulamadaki
/// yayında ya da bekleyen içerikleri TÜR TÜR listeler ve yayından indirir
/// (yumuşak silme — veri denetim için sunucuda durur).
///
/// DÜZENLEME BİLEREK YOK: içerik kullanıcının imzasını taşır; yöneticinin
/// metni değiştirmesi yanlış temsil olur. Yanlış içerik ya silinir ya
/// moderasyonda reddedilir — panel bu iki dürüst yolu sunar.
class AdminContentScreen extends ConsumerStatefulWidget {
  const AdminContentScreen({super.key});

  @override
  ConsumerState<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends ConsumerState<AdminContentScreen> {
  static const List<String> _types = <String>[
    'routes',
    'questions',
    'answers',
    'notes',
    'reviews',
    'boats',
  ];

  String _type = 'routes';
  bool _busy = false;

  String _typeLabel(L10n t, String type) => switch (type) {
        'routes' => t.admCtRoutes,
        'questions' => t.admCtQuestions,
        'answers' => t.admCtAnswers,
        'notes' => t.admCtNotes,
        'reviews' => t.admCtReviews,
        _ => t.admCtBoats,
      };

  String _statusLabel(L10n t, String? status) => switch (status) {
        'pending' => t.rtPendingChip,
        'rejected' => t.admCtRejected,
        'hidden' => t.admCtHidden,
        _ => '', // approved/visible: rozet basılmaz (gürültü olmasın)
      };

  Future<void> _delete(AdminContentItem item) async {
    final L10n t = ref.read(l10nProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(t.admCtDeleteTitle),
        content: Text(L10n.fmt(t.admCtDeleteBodyFmt, item.title)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancelLabel),
          ),
          FilledButton(
            key: const ValueKey<String>('admct-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.admCtDeleteBtn),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminGatewayProvider)
          .deleteContent(type: _type, id: item.id);
      ref.invalidate(adminContentProvider(_type));
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.admCtDeletedToast)));
    } catch (error) {
      final String text =
          error is AppFailure ? error.message : t.admCtDeleteFailed;
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<AdminContentItem>> items =
        ref.watch(adminContentProvider(_type));
    return Scaffold(
      appBar: AppBar(title: Text(t.admCtTitle)),
      body: Column(
        children: <Widget>[
          // Tür çipleri — yatay kaydırılır (arama filtre şeridi deseni).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: <Widget>[
                for (final String ty in _types)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey<String>('admct-type-$ty'),
                      label: Text(_typeLabel(t, ty)),
                      selected: _type == ty,
                      onSelected: (_) => setState(() => _type = ty),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        e is AppFailure ? e.message : t.admCtLoadFailed,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(adminContentProvider(_type)),
                        child: Text(t.retryLabel),
                      ),
                    ],
                  ),
                ),
              ),
              data: (List<AdminContentItem> rows) => rows.isEmpty
                  ? Center(
                      child: Text(
                        t.admCtEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                      itemCount: rows.length,
                      itemBuilder: (BuildContext context, int i) {
                        final AdminContentItem r = rows[i];
                        final String badge = _statusLabel(t, r.status);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding:
                              const EdgeInsets.fromLTRB(12, 10, 6, 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.dividerColor
                                    .withValues(alpha: .4)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(r.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      <String>[
                                        if (r.authorName != null)
                                          r.authorName!,
                                        if (badge.isNotEmpty) badge,
                                        '${r.createdAt.day.toString().padLeft(2, '0')}.'
                                            '${r.createdAt.month.toString().padLeft(2, '0')}.'
                                            '${r.createdAt.year}',
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: ValueKey<String>('admct-del-${r.id}'),
                                tooltip: t.admCtDeleteBtn,
                                onPressed:
                                    _busy ? null : () => _delete(r),
                                icon: DocklyIcon(DocklyIcons.deleteOutline,
                                    size: 18,
                                    color: theme
                                        .colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
