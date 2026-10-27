import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../boat/application/maintenance_controller.dart';
import '../../boat/data/maintenance_catalog.dart';
import '../../boat/domain/maintenance.dart';
import '../domain/local_notifier.dart';
import 'push_controller.dart';

/// BAKIM HATIRLATMA EŞİĞİ (kurucu talebi 2026-10-27): kaleme "1 aydan az"
/// kaldığında telefon bildirimi. Uygulama içi şeritteki 21 günlük
/// "yaklaşıyor" penceresinden BİLİNÇLİ geniş: bildirim erken haber verir,
/// şerit son düzlüğü gösterir.
const int kMaintenanceNotifyDays = 30;

/// Hatırlatılacak kalem: hangi kalem, kaç gün kaldı (negatif = gecikmiş).
class MaintenanceDue {
  const MaintenanceDue({required this.task, required this.daysLeft});

  final MaintenanceTask task;
  final int daysLeft;
}

/// Tekrar koruması anahtarı: kalem + "yapıldı" tarihi. Kaptan bakımı yapıp
/// yeni tarih girince anahtar değişir → sonraki dönemde yeniden hatırlatılır;
/// aynı dönem içinde her açılışta tekrar bildirim ÜRETMEZ.
String maintenanceDedupKey(MaintenanceRecord record) =>
    '${record.taskId}|${record.lastDoneMs}';

/// SAF hesap (teste açık): hangi kalemler bildirimi hak ediyor?
/// Kayıtsız kalem hatırlatılmaz ("veri yoksa kart kendini çizmez" ilkesi —
/// hiç kayıt girilmemiş kalem için tarih İDDİA EDİLEMEZ).
List<MaintenanceDue> maintenanceDueReminders({
  required List<MaintenanceTask> tasks,
  required List<MaintenanceRecord> records,
  required Set<String> alreadyNotified,
  required DateTime now,
}) {
  final Map<String, MaintenanceRecord> byId = <String, MaintenanceRecord>{
    for (final MaintenanceRecord r in records) r.taskId: r,
  };
  final List<MaintenanceDue> due = <MaintenanceDue>[];
  for (final MaintenanceTask task in tasks) {
    final MaintenanceRecord? record = byId[task.id];
    if (record == null) continue;
    if (alreadyNotified.contains(maintenanceDedupKey(record))) continue;
    final int? left = maintenanceDaysLeft(task, record, now: now);
    if (left == null || left > kMaintenanceNotifyDays) continue;
    due.add(MaintenanceDue(task: task, daysLeft: left));
  }
  return due;
}

/// Açılış kontrolü: kayıtları okur, eşiği geçen kalemler için YEREL bildirim
/// gösterir ve tekrar korumasını cihaza yazar. Her adım en-iyi-çaba.
class MaintenanceReminderRunner {
  MaintenanceReminderRunner(this._ref);

  static const String _seenKey = 'ntf.maint.seen';

  final Ref _ref;

  Future<void> run({DateTime? now}) async {
    try {
      if (!_ref.read(maintReminderEnabledProvider)) return;
      final List<MaintenanceRecord> records =
          await _ref.read(maintenanceStoreProvider).load();
      if (records.isEmpty) return;

      final AppLocale locale = _ref.read(appLocaleProvider);
      final List<MaintenanceTask> tasks = maintenanceCatalog(locale);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Set<String> seen =
          (prefs.getStringList(_seenKey) ?? const <String>[]).toSet();

      final List<MaintenanceDue> due = maintenanceDueReminders(
        tasks: tasks,
        records: records,
        alreadyNotified: seen,
        now: now ?? DateTime.now(),
      );
      if (due.isEmpty) return;

      final L10n t = _ref.read(l10nProvider);
      final LocalNotifier notifier = _ref.read(localNotifierProvider);
      final Map<String, MaintenanceRecord> byId = <String, MaintenanceRecord>{
        for (final MaintenanceRecord r in records) r.taskId: r,
      };
      for (final MaintenanceDue d in due) {
        // Kararlı bildirim kimliği: katalog sırası (aynı kalem üst üste
        // bildirim biriktirmez, mevcut olan güncellenir).
        await notifier.show(
          id: 7000 + tasks.indexOf(d.task),
          title: t.ntfMaintDueTitle,
          body: L10n.fmt(t.ntfMaintDueFmt, d.task.title),
        );
        seen.add(maintenanceDedupKey(byId[d.task.id]!));
      }
      // Liste sınırsız büyümesin: en son 100 anahtar yeter (10 kalem × eski
      // dönemler; eski anahtarların tekrar tetiklenme ihtimali zaten yok).
      final List<String> trimmed = seen.toList();
      if (trimmed.length > 100) {
        trimmed.removeRange(0, trimmed.length - 100);
      }
      await prefs.setStringList(_seenKey, trimmed);
    } catch (_) {/* bakım şeridi uygulama içinde zaten uyarır */}
  }
}

final Provider<MaintenanceReminderRunner> maintenanceReminderProvider =
    Provider<MaintenanceReminderRunner>(MaintenanceReminderRunner.new);
