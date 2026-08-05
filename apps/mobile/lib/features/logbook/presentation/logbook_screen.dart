import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/logbook_controller.dart';
import '../domain/log_entry.dart';

/// KAPTANIN GÜNLÜĞÜ ekranı (kullanıcı onayı 2026-08): seyir notları — en yeni
/// başta. "+" yeni giriş açar; aktif rota varsa bağlam kendiliğinden gelir.
class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<LogEntry> entries = ref.watch(logbookProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.logbookTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('logbook-new'),
        onPressed: () => showLogEntryEditor(context, ref),
        icon: const DocklyIcon(DocklyIcons.edit, size: 18, color: Colors.white),
        label: Text(t.logbookNew),
        backgroundColor: DocklyColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.logbookEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: entries.length,
              itemBuilder: (BuildContext context, int i) =>
                  _LogEntryCard(entry: entries[i]),
            ),
    );
  }
}

/// Tek günlük girişi kartı: tarih + (varsa) başlık + bağlam satırı + not.
class _LogEntryCard extends ConsumerWidget {
  const _LogEntryCard({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(entry.dateMs);
    final String date = '${d.day}.${d.month}.${d.year}';
    final String? ctx = entry.ctxRoute == null
        ? null
        : entry.ctxNm == null
            ? entry.ctxRoute
            : '${entry.ctxRoute} · ≈ ${entry.ctxNm! >= 10 ? entry.ctxNm!.round() : entry.ctxNm!.toStringAsFixed(1)} ${t.nmUnit}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(date,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: DocklyColors.brandPrimary,
                        fontWeight: FontWeight.w800)),
                if (entry.title != null && entry.title!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(entry.title!,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
                if (ctx != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      const DocklyIcon(DocklyIcons.navigation,
                          size: 12, color: DocklyColors.accentTurquoise),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(ctx,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(entry.text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: t.logbookDeleteTooltip,
            icon: DocklyIcon(DocklyIcons.deleteOutline,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () =>
                ref.read(logbookProvider.notifier).remove(entry.id),
          ),
        ],
      ),
    );
  }
}

/// YENİ GİRİŞ düzenleyicisi (alt sayfa). [context] verilmezse o anki aktif
/// rotadan otomatik alınır; kaptan bağlamı ✕ ile kaldırabilir.
Future<void> showLogEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  LogContext? logContext,
}) async {
  final LogContext? ctx = logContext ?? ref.read(logContextProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _LogEntryEditor(initialContext: ctx),
    ),
  );
}

class _LogEntryEditor extends ConsumerStatefulWidget {
  const _LogEntryEditor({required this.initialContext});

  final LogContext? initialContext;

  @override
  ConsumerState<_LogEntryEditor> createState() => _LogEntryEditorState();
}

class _LogEntryEditorState extends ConsumerState<_LogEntryEditor> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _text = TextEditingController();
  late LogContext? _ctx = widget.initialContext;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String text = _text.text.trim();
    if (text.isEmpty || _saving) return; // boş giriş kaydedilmez
    setState(() => _saving = true);
    final int now = DateTime.now().millisecondsSinceEpoch;
    await ref.read(logbookProvider.notifier).add(LogEntry(
          id: 'l$now',
          dateMs: now,
          text: text,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          ctxRoute: _ctx?.routeName,
          ctxNm: _ctx?.distanceNm,
          ctxStops: _ctx?.stops,
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final LogContext? ctx = _ctx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(t.logbookNew,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (ctx != null) ...<Widget>[
            const SizedBox(height: 10),
            // Otomatik rota bağlamı — ✕ ile kaldırılabilir (onaylı tasarım).
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(
                color: DocklyColors.accentTurquoise.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const DocklyIcon(DocklyIcons.navigation,
                      size: 13, color: DocklyColors.accentTurquoise),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ctx.routeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('logbook-ctx-remove'),
                    visualDensity: VisualDensity.compact,
                    icon: const DocklyIcon(DocklyIcons.close, size: 14),
                    onPressed: () => setState(() => _ctx = null),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: t.logbookTitleHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: t.logbookTextHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('logbook-save'),
              onPressed: _saving ? null : _save,
              child: Text(t.saveLabel),
            ),
          ),
        ],
      ),
    );
  }
}
