import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
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

/// Bakım bildirim kimlik tabanı — kalem kimliği = taban + katalog sırası.
const int kMaintenanceNotifyIdBase = 7000;

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

/// SAF hesap (teste açık): hangi kalemler ŞU AN bildirimi hak ediyor?
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

/// SAF hesap (teste açık): eşiğe HENÜZ uzak kalemin bildirim kurulacağı an
/// (epoch ms) — eşiğin geçileceği gün yerel saat 10:00. Eşik zaten
/// geçildiyse ya da kayıt yoksa null (o kalem ya hemen gösterilir ya hiç).
int? maintenanceScheduleAtMs(
  MaintenanceTask task,
  MaintenanceRecord? record, {
  required DateTime now,
}) {
  if (record == null) return null;
  final int? left = maintenanceDaysLeft(task, record, now: now);
  if (left == null || left <= kMaintenanceNotifyDays) return null;
  final DateTime last = DateTime.fromMillisecondsSinceEpoch(record.lastDoneMs);
  final DateTime due = DateTime(last.year, last.month, last.day)
      .add(Duration(days: maintenanceIntervalDays(task, record)));
  final DateTime at = DateTime(due.year, due.month, due.day, 10)
      .subtract(const Duration(days: kMaintenanceNotifyDays));
  return at.millisecondsSinceEpoch;
}

/// Bakım hatırlatma beyni (v2 — kurucu talebi 2026-10-27, "uygulama
/// kapalıyken de gelsin"): her çalıştırmada
///  1. hesap yoksa TÜM bakım bildirimleri iptal edilir (hesap kapısı),
///  2. eşiği GEÇMİŞ kalemler hemen gösterilir (tekrar korumalı),
///  3. eşiğe uzak kalemler için bildirim TELEFONA KURULUR — uygulama hiç
///     açılmasa da eşik günü çalar; "yapıldı" girilince kurulum tazelenir.
/// Her adım en-iyi-çaba; çağrılar: açılış, oturum değişimi, bakım değişimi.
class MaintenanceReminderRunner {
  MaintenanceReminderRunner(this._ref);

  static const String _seenKey = 'ntf.maint.seen';

  final Ref _ref;

  Future<void> run({DateTime? now}) async {
    try {
      final AppLocale locale = _ref.read(appLocaleProvider);
      final List<MaintenanceTask> tasks = maintenanceCatalog(locale);
      final LocalNotifier notifier = _ref.read(localNotifierProvider);

      // HESAP KAPISI / anahtar kapalı: kurulu ne varsa sökülür — çıkış yapan
      // (ya da kapatma isteyen) kaptana eski hesabın hatırlatması çalmaz.
      final AuthState auth = _ref.read(authControllerProvider);
      final String? uid =
          auth is Authenticated && !auth.isGuest ? auth.user.id : null;
      if (uid == null || !_ref.read(maintReminderEnabledProvider)) {
        for (int i = 0; i < tasks.length; i++) {
          await notifier.cancel(kMaintenanceNotifyIdBase + i);
        }
        return;
      }

      // Yalnız BU hesabın (ve henüz sahiplenilmemiş eski) kayıtları.
      final List<MaintenanceRecord> records = <MaintenanceRecord>[
        for (final MaintenanceRecord r
            in await _ref.read(maintenanceStoreProvider).load())
          if (r.ownerUid == uid || r.ownerUid == null) r,
      ];

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Set<String> seen =
          (prefs.getStringList(_seenKey) ?? const <String>[]).toSet();
      final DateTime t0 = now ?? DateTime.now();

      final Map<String, MaintenanceRecord> byId = <String, MaintenanceRecord>{
        for (final MaintenanceRecord r in records) r.taskId: r,
      };
      final List<MaintenanceDue> due = maintenanceDueReminders(
        tasks: tasks,
        records: records,
        alreadyNotified: seen,
        now: t0,
      );
      final Set<String> dueIds = <String>{for (final MaintenanceDue d in due) d.task.id};

      final L10n t = _ref.read(l10nProvider);
      for (int i = 0; i < tasks.length; i++) {
        final MaintenanceTask task = tasks[i];
        final int id = kMaintenanceNotifyIdBase + i;
        final MaintenanceRecord? record = byId[task.id];
        if (dueIds.contains(task.id)) {
          // Eşik geçildi → HEMEN göster (bir kez; anahtar diske yazılır).
          await notifier.show(
            id: id,
            title: t.ntfMaintDueTitle,
            body: L10n.fmt(t.ntfMaintDueFmt, task.title),
          );
          seen.add(maintenanceDedupKey(record!));
          continue;
        }
        if (record == null) {
          // Kayıt silindi → kurulu bir şey kalmasın (hayalet bildirim olmasın).
          await notifier.cancel(id);
          continue;
        }
        final int? atMs = maintenanceScheduleAtMs(task, record, now: t0);
        if (atMs != null) {
          // Eşik ileride → bildirim TELEFONA KURULUR (aynı id eskisini
          // değiştirir) ve bu dönem "bildirildi" sayılır: kurulan bildirim
          // uygulama kapalıyken çalar; açılışta İKİNCİ kez gösterilmez.
          await notifier.schedule(
            id: id,
            title: t.ntfMaintDueTitle,
            body: L10n.fmt(t.ntfMaintDueFmt, task.title),
            atMs: atMs,
          );
          seen.add(maintenanceDedupKey(record));
        }
        // atMs null + kayıt var = bu dönem zaten bildirildi → DOKUNMA:
        // bildirim merkezindeki teslim edilmiş bildirim silinmesin.
      }

      // Liste sınırsız büyümesin: en son 100 anahtar yeter.
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
