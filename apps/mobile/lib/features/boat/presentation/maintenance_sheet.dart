import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/maintenance_controller.dart';
import '../domain/maintenance.dart';

/// BAKIM KALEMİ alt sayfası (v2.0 "Teknem"): "bugün yaptım", başka tarih,
/// tekrar aralığı ve kaydı silme. Uygulama hiçbir şeyi kendiliğinden
/// "yapıldı" saymaz — her kayıt kaptanın beyanıdır.
Future<void> showMaintenanceSheet(BuildContext context, MaintenanceTask task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext _) => _MaintenanceSheet(task: task),
  );
}

/// Aralık seçenekleri (ay) — kaptan kendi teknesine göre seçer.
const List<int> _intervalMonths = <int>[3, 6, 12, 24];

class _MaintenanceSheet extends ConsumerWidget {
  const _MaintenanceSheet({required this.task});

  final MaintenanceTask task;

  static String _date(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}.${d.month}.${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    // Kayıtları izle: "bugün yaptım"dan sonra sayfa kendini tazeler.
    ref.watch(maintenanceProvider);
    final MaintenanceController ctrl =
        ref.read(maintenanceProvider.notifier);
    final MaintenanceRecord? rec = ctrl.recordFor(task.id);
    final int intervalDays = maintenanceIntervalDays(task, rec);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DocklyIcon(task.icon, size: 20, color: DocklyColors.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(task.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(task.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
          if (rec != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              L10n.fmt(t.maintLastDoneFmt, _date(rec.lastDoneMs)),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('maint-done-today'),
                onPressed: () {
                  ctrl.markDone(task.id);
                  Navigator.of(context).pop();
                },
                icon: const DocklyIcon(DocklyIcons.checkCircle,
                    size: 16, color: Colors.white),
                label: Text(t.maintDoneToday),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('maint-pick-date'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () async {
                  final DateTime now = DateTime.now();
                  final DateTime first = DateTime(now.year - 10);
                  final DateTime initial = rec == null
                      ? now
                      : DateTime.fromMillisecondsSinceEpoch(rec.lastDoneMs);
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    // 10 yıldan eski kayıtta takvim penceresinin DIŞINA
                    // düşmemek için kırpılır (aksi hâlde çerçeve assert atar).
                    initialDate: initial.isBefore(first) ? first : initial,
                    firstDate: first,
                    lastDate: now,
                  );
                  if (picked == null || !context.mounted) return;
                  await ctrl.markDone(task.id, when: picked);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const DocklyIcon(DocklyIcons.eventNoteOutlined, size: 16),
                label: Text(t.maintPickDate),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            t.maintIntervalTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int m in _intervalMonths)
                ChoiceChip(
                  key: ValueKey<String>('maint-every-$m'),
                  // Katalogda 365 gün (yıllık) gibi ay katı OLMAYAN aralıklar
                  // var: seçim, en yakın aya YUVARLANARAK eşlenir — yoksa
                  // yıllık kalemlerde hiçbir çip seçili görünmezdi.
                  selected: (intervalDays / 30).round() == m,
                  label: Text(L10n.fmt(t.maintIntervalFmt, '$m')),
                  // Aralık yalnız KAYIT VARSA değiştirilebilir: tarih
                  // bilinmeden "sonraki bakım" hesabı uydurma olurdu.
                  onSelected: rec == null
                      ? null
                      : (bool _) => ctrl.setInterval(task.id, m * 30),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.maintNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          if (rec != null) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey<String>('maint-clear'),
                style: TextButton.styleFrom(
                  foregroundColor: DocklyColors.error,
                ),
                onPressed: () {
                  ctrl.clear(task.id);
                  Navigator.of(context).pop();
                },
                icon: const DocklyIcon(DocklyIcons.deleteOutline,
                    size: 16, color: DocklyColors.error),
                label: Text(t.maintClearBtn),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
