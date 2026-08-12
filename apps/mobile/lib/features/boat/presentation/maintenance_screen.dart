import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../application/maintenance_controller.dart';
import '../data/maintenance_catalog.dart';
import '../domain/maintenance.dart';
import 'maintenance_sheet.dart';

/// BAKIM TAKİBİ ekranı (Teknem Konsept A, kullanıcı onayı 2026-08).
///
/// Eskiden 10 kalem Teknem sekmesinde her açılışta tam boy duruyordu; kaptan
/// çoğu gün yalnız "ilgi bekleyen var mı?" diye bakar. Liste artık Teknem'deki
/// tek satırlık özetten açılan BU ekranda yaşar — içerik ve davranış birebir
/// taşındı (kalem satırları, "bugün yaptım" alt sayfası, dürüstlük notu).
/// 0-uydurma ilkesi aynen: kayıt girilmedikçe hiçbir kalem durum İDDİA etmez.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<MaintenanceTask> tasks =
        maintenanceCatalog(ref.watch(appLocaleProvider));
    // Kayıtlar izlenir: "bugün yaptım" sonrası durum rozetleri tazelenir.
    ref.watch(maintenanceProvider);
    final MaintenanceController ctrl = ref.read(maintenanceProvider.notifier);
    final DateTime now = DateTime.now();
    int needsAttention = 0;
    int logged = 0;
    for (final MaintenanceTask task in tasks) {
      final MaintenanceStatus s =
          maintenanceStatus(task, ctrl.recordFor(task.id), now: now);
      if (s == MaintenanceStatus.overdue || s == MaintenanceStatus.dueSoon) {
        needsAttention++;
      }
      if (s != MaintenanceStatus.notLogged) logged++;
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.maintTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Text(
            // Hiç kayıt yoksa ne yapılacağı anlatılır; hepsi güncelse övülür.
            needsAttention == 0 && logged > 0 ? t.maintAllGood : t.maintLead,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final MaintenanceTask task in tasks)
            _MaintenanceRow(
              task: task,
              record: ctrl.recordFor(task.id),
              now: now,
            ),
          const SizedBox(height: 8),
          Text(
            t.maintNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bakım kalemi satırı: ikon + ad + durum rozeti + kalan/gecikme.
/// (Teknem'den değişmeden taşındı — anahtarlar ve davranış aynı.)
class _MaintenanceRow extends ConsumerWidget {
  const _MaintenanceRow({
    required this.task,
    required this.record,
    required this.now,
  });

  final MaintenanceTask task;
  final MaintenanceRecord? record;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final MaintenanceStatus status =
        maintenanceStatus(task, record, now: now);
    final int? left = maintenanceDaysLeft(task, record, now: now);
    final (String label, Color color) = switch (status) {
      MaintenanceStatus.overdue => (t.maintStatusOverdue, DocklyColors.error),
      MaintenanceStatus.dueSoon => (t.maintStatusSoon, DocklyColors.warning),
      MaintenanceStatus.ok => (t.maintStatusOk, DocklyColors.success),
      MaintenanceStatus.notLogged =>
        (t.maintStatusNone, theme.colorScheme.onSurfaceVariant),
    };
    final String? detail = left == null
        ? null
        : (left < 0
            ? L10n.fmt(t.maintOverdueByFmt, '${-left}')
            : L10n.fmt(t.maintDueInFmt, '$left'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        key: ValueKey<String>('maint-${task.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => showMaintenanceSheet(context, task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: <Widget>[
              DocklyIcon(task.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
