import 'package:dockly_mobile/features/notifications/application/maintenance_reminder.dart';
import 'package:dockly_mobile/features/boat/domain/maintenance.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// BAKIM HATIRLATMASI saf hesabı (kurucu talebi 2026-10-27): "1 aydan az
/// kaldıysa bir kez bildir". Veri yoksa iddia yok; tekrar koruması
/// kalem + 'yapıldı' tarihi anahtarıyladır.
void main() {
  const MaintenanceTask oil = MaintenanceTask(
    id: 'engine_oil',
    icon: DocklyIcons.amTool,
    intervalDays: 365,
    title: 'Motor yağı',
    hint: '',
  );
  const MaintenanceTask anodes = MaintenanceTask(
    id: 'anodes',
    icon: DocklyIcons.amElectricity,
    intervalDays: 180,
    title: 'Anotlar',
    hint: '',
  );
  final DateTime now = DateTime(2026, 10, 27);

  MaintenanceRecord rec(String id, DateTime lastDone, {int? every}) =>
      MaintenanceRecord(
        taskId: id,
        lastDoneMs: lastDone.millisecondsSinceEpoch,
        intervalDays: every,
      );

  test('eşiğin içinde (≤30 gün) hatırlatılır, dışında hatırlatılmaz', () {
    final List<MaintenanceDue> due = maintenanceDueReminders(
      tasks: const <MaintenanceTask>[oil, anodes],
      records: <MaintenanceRecord>[
        // 365 günlük aralık, 340 gün önce yapıldı → 25 gün kaldı: HATIRLAT.
        rec('engine_oil', now.subtract(const Duration(days: 340))),
        // 180 günlük aralık, 100 gün önce → 80 gün kaldı: erken, SUSTUR.
        rec('anodes', now.subtract(const Duration(days: 100))),
      ],
      alreadyNotified: const <String>{},
      now: now,
    );
    expect(due, hasLength(1));
    expect(due.single.task.id, 'engine_oil');
    expect(due.single.daysLeft, 25);
  });

  test('gecikmiş kalem de hatırlatılır (negatif gün)', () {
    final List<MaintenanceDue> due = maintenanceDueReminders(
      tasks: const <MaintenanceTask>[oil],
      records: <MaintenanceRecord>[
        rec('engine_oil', now.subtract(const Duration(days: 400))),
      ],
      alreadyNotified: const <String>{},
      now: now,
    );
    expect(due, hasLength(1));
    expect(due.single.daysLeft, lessThan(0));
  });

  test('kayıt yoksa İDDİA YOK — hatırlatma üretilmez', () {
    final List<MaintenanceDue> due = maintenanceDueReminders(
      tasks: const <MaintenanceTask>[oil, anodes],
      records: const <MaintenanceRecord>[],
      alreadyNotified: const <String>{},
      now: now,
    );
    expect(due, isEmpty);
  });

  test('aynı dönem İKİNCİ kez bildirmez; bakım yapılınca dönem yenilenir', () {
    final MaintenanceRecord first =
        rec('engine_oil', now.subtract(const Duration(days: 340)));
    // İlk bildirimden sonra anahtar "görüldü" listesine girdi.
    final Set<String> seen = <String>{maintenanceDedupKey(first)};
    expect(
      maintenanceDueReminders(
        tasks: const <MaintenanceTask>[oil],
        records: <MaintenanceRecord>[first],
        alreadyNotified: seen,
        now: now,
      ),
      isEmpty,
    );
    // Kaptan bakımı yaptı, yeni tarih girdi → yeni anahtar; BİR SONRAKİ
    // dönemde (335 gün sonra) yeniden hatırlatılabilir.
    final MaintenanceRecord renewed = rec('engine_oil', now);
    expect(maintenanceDedupKey(renewed), isNot(maintenanceDedupKey(first)));
    final List<MaintenanceDue> later = maintenanceDueReminders(
      tasks: const <MaintenanceTask>[oil],
      records: <MaintenanceRecord>[renewed],
      alreadyNotified: seen,
      now: now.add(const Duration(days: 340)),
    );
    expect(later, hasLength(1));
  });

  test('kaptanın kendi aralığı önerinin önüne geçer', () {
    // Katalog 365 der ama kaptan 60 günde bir yağ bakar: 40 gün önce yapıldı
    // → 20 gün kaldı, hatırlatılır (katalogla bakılsa 325 gün kalırdı).
    final List<MaintenanceDue> due = maintenanceDueReminders(
      tasks: const <MaintenanceTask>[oil],
      records: <MaintenanceRecord>[
        rec('engine_oil', now.subtract(const Duration(days: 40)), every: 60),
      ],
      alreadyNotified: const <String>{},
      now: now,
    );
    expect(due, hasLength(1));
    expect(due.single.daysLeft, 20);
  });
}
