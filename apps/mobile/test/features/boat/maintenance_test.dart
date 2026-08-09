import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/features/boat/data/maintenance_catalog.dart';
import 'package:dockly_mobile/features/boat/domain/maintenance.dart';
import 'package:flutter_test/flutter_test.dart';

/// BAKIM TAKİBİ birim testleri (v2.0 "Teknem"): saf durum hesabı + katalog
/// bütünlüğü. İlke: kayıt yoksa uygulama HİÇBİR ŞEY iddia etmez.
void main() {
  final DateTime now = DateTime(2026, 8, 9);
  final MaintenanceTask oil = maintenanceCatalog(AppLocale.tr)
      .firstWhere((MaintenanceTask t) => t.id == 'engine_oil');

  MaintenanceRecord doneDaysAgo(int days, {int? every}) => MaintenanceRecord(
        taskId: 'engine_oil',
        lastDoneMs: now.subtract(Duration(days: days)).millisecondsSinceEpoch,
        intervalDays: every,
      );

  group('durum hesabı', () {
    test('kayıt yoksa "kayıt yok" — güncel SAYILMAZ, kalan gün bilinmez', () {
      expect(maintenanceStatus(oil, null, now: now),
          MaintenanceStatus.notLogged);
      expect(maintenanceDaysLeft(oil, null, now: now), isNull);
    });

    test('yeni yapılmışsa güncel; kalan gün doğru sayılır', () {
      final MaintenanceRecord r = doneDaysAgo(30); // 365 günlük aralık
      expect(maintenanceStatus(oil, r, now: now), MaintenanceStatus.ok);
      expect(maintenanceDaysLeft(oil, r, now: now), 335);
    });

    test('son ${kMaintenanceSoonDays} günde "yaklaşıyor"', () {
      final MaintenanceRecord r = doneDaysAgo(365 - kMaintenanceSoonDays);
      expect(maintenanceStatus(oil, r, now: now), MaintenanceStatus.dueSoon);
      expect(maintenanceDaysLeft(oil, r, now: now), kMaintenanceSoonDays);
    });

    test('süre dolduysa "zamanı geçti" ve gecikme negatif gün olarak gelir',
        () {
      final MaintenanceRecord r = doneDaysAgo(400);
      expect(maintenanceStatus(oil, r, now: now), MaintenanceStatus.overdue);
      expect(maintenanceDaysLeft(oil, r, now: now), -35);
    });

    test('kaptanın kendi aralığı katalog önerisini EZER', () {
      final MaintenanceRecord r = doneDaysAgo(100, every: 90);
      expect(maintenanceIntervalDays(oil, r), 90);
      expect(maintenanceStatus(oil, r, now: now), MaintenanceStatus.overdue);
      // Aralık girilmemişse katalog önerisi kullanılır.
      expect(maintenanceIntervalDays(oil, doneDaysAgo(100)), 365);
    });
  });

  group('katalog', () {
    test('her dilde aynı 10 kalem, aynı sırada; boş metin yok', () {
      final List<String> trIds = maintenanceCatalog(AppLocale.tr)
          .map((MaintenanceTask t) => t.id)
          .toList();
      expect(trIds, hasLength(kMaintenanceTaskCount));
      expect(trIds.toSet(), hasLength(kMaintenanceTaskCount));
      for (final AppLocale l in AppLocale.values) {
        final List<MaintenanceTask> tasks = maintenanceCatalog(l);
        expect(tasks.map((MaintenanceTask t) => t.id).toList(), trIds,
            reason: '$l');
        for (final MaintenanceTask task in tasks) {
          expect(task.title.trim(), isNotEmpty, reason: '$l ${task.id}');
          expect(task.hint.trim(), isNotEmpty, reason: '$l ${task.id}');
          expect(task.intervalDays, greaterThan(0), reason: '$l ${task.id}');
        }
      }
    });

    test('diller birbirinden farklı (çeviri unutulmamış)', () {
      for (final MaintenanceTask tr in maintenanceCatalog(AppLocale.tr)) {
        final Set<String> titles = <String>{
          tr.title,
          for (final AppLocale l in <AppLocale>[
            AppLocale.en,
            AppLocale.es,
            AppLocale.ru,
          ])
            maintenanceCatalog(l)
                .firstWhere((MaintenanceTask t) => t.id == tr.id)
                .title,
        };
        expect(titles, hasLength(4), reason: tr.id);
      }
    });
  });

  group('kayıt JSON', () {
    test('gidiş-dönüş bozulmaz; bozuk satır null döner', () {
      const MaintenanceRecord r = MaintenanceRecord(
        taskId: 'anodes',
        lastDoneMs: 1700000000000,
        intervalDays: 180,
      );
      final MaintenanceRecord? back = MaintenanceRecord.fromJson(r.toJson());
      expect(back, isNotNull);
      expect(back!.taskId, 'anodes');
      expect(back.lastDoneMs, 1700000000000);
      expect(back.intervalDays, 180);
      expect(MaintenanceRecord.fromJson(<String, dynamic>{'id': 'x'}), isNull);
      expect(MaintenanceRecord.fromJson('bozuk'), isNull);
    });
  });
}
