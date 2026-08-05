import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/checklist_controller.dart';

/// SEYİR ÖNCESİ KONTROL LİSTESİ alt sayfası (kullanıcı onayı 2026-08).
/// İşaretler o güne aittir; gün değişince sıfır başlar. Dürüstlük notu:
/// bu liste hatırlatıcıdır, resmî güvenlik gereklerinin yerine geçmez.
Future<void> showChecklistSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const _ChecklistBody(),
  );
}

class _ChecklistBody extends ConsumerWidget {
  const _ChecklistBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final ChecklistState s = ref.watch(checklistProvider);
    final int mask =
        ref.read(checklistProvider.notifier).maskFor(DateTime.now());
    int checked = 0;
    for (int i = 0; i < kChecklistItemCount; i++) {
      if ((mask >> i) & 1 == 1) checked++;
    }
    // s.ready izlenir ki depo yüklenince işaretler ekrana gelsin.
    final bool allDone = s.ready && checked == kChecklistItemCount;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(t.checklistTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text(
                '$checked/$kChecklistItemCount',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: allDone
                      ? DocklyColors.success
                      : DocklyColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(t.checklistNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          for (int i = 0; i < kChecklistItemCount; i++)
            CheckboxListTile(
              key: ValueKey<String>('checklist-$i'),
              value: (mask >> i) & 1 == 1,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: DocklyColors.success,
              title: Text(t.checklistItems[i],
                  style: theme.textTheme.bodyMedium),
              onChanged: (bool? _) =>
                  ref.read(checklistProvider.notifier).toggle(i),
            ),
          const SizedBox(height: 8),
          if (allDone)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: DocklyColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t.checklistAllDone,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: DocklyColors.success, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
