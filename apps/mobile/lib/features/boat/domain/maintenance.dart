/// TEKNE BAKIM TAKİBİ — alan modeli (v2.0 "Teknem", kurucu onayı 2026-08).
///
/// İLKE: uygulama teknenin durumunu BİLMEZ. Yalnız kaptanın girdiği "en son
/// ne zaman yapıldı" bilgisini ve önerilen aralığı kullanarak hatırlatır.
/// Kayıt yoksa "yapıldı" varsayılmaz — dürüst "kayıt yok" durumu gösterilir.
/// Aralıklar ÖNERİDİR; üretici kılavuzu ve kullanım yoğunluğu esastır.
library;

import 'package:dockly_ui/dockly_ui.dart' show DocklyIconData;

/// Bakım kaleminin durumu (saf hesap — [maintenanceStatus]).
enum MaintenanceStatus {
  /// Hiç kayıt girilmemiş — uygulama bir şey İDDİA ETMEZ.
  notLogged,

  /// Süre dolmuş (geçmiş tarihli).
  overdue,

  /// Yaklaşıyor (son [kMaintenanceSoonDays] gün içinde).
  dueSoon,

  /// Güncel.
  ok,
}

/// "Yaklaşıyor" penceresi — bu kadar gün kala kaptan uyarılır.
const int kMaintenanceSoonDays = 21;

/// Katalog kalemi (kimlik + ikon + önerilen aralık + yerelleşmiş metin).
class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.icon,
    required this.intervalDays,
    required this.title,
    required this.hint,
  });

  /// Kalıcı kimlik (dilden bağımsız) — kayıtlar bununla eşlenir.
  final String id;

  final DocklyIconData icon;

  /// ÖNERİLEN aralık (gün). Kaptan kendi aralığını girerse o kullanılır.
  final int intervalDays;

  final String title;

  /// Tek cümlelik "neden/nasıl" ipucu.
  final String hint;
}

/// Kaptanın girdiği kayıt: en son ne zaman yapıldı (+ kendi aralığı).
class MaintenanceRecord {
  const MaintenanceRecord({
    required this.taskId,
    required this.lastDoneMs,
    this.intervalDays,
  });

  final String taskId;
  final int lastDoneMs;

  /// Kaptanın kendi aralığı (gün). null → katalogdaki öneri kullanılır.
  final int? intervalDays;

  MaintenanceRecord copyWith({int? lastDoneMs, int? intervalDays}) =>
      MaintenanceRecord(
        taskId: taskId,
        lastDoneMs: lastDoneMs ?? this.lastDoneMs,
        intervalDays: intervalDays ?? this.intervalDays,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': taskId,
        'done': lastDoneMs,
        if (intervalDays != null) 'every': intervalDays,
      };

  /// Bozuk kayıt → null (çökme yok; satır sessizce atlanır).
  static MaintenanceRecord? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? id = raw['id'] as String?;
    final int? done = raw['done'] as int?;
    if (id == null || done == null) return null;
    final int? every = raw['every'] as int?;
    return MaintenanceRecord(
      taskId: id,
      lastDoneMs: done,
      intervalDays: (every != null && every > 0) ? every : null,
    );
  }
}

/// Bir kalemin geçerli aralığı: kaptanın girdiği varsa o, yoksa öneri.
int maintenanceIntervalDays(MaintenanceTask task, MaintenanceRecord? record) =>
    record?.intervalDays ?? task.intervalDays;

/// Sonraki bakıma kalan gün. Kayıt yoksa null (bilinmiyor — uydurulmaz).
/// Negatif değer gecikmeyi gösterir.
int? maintenanceDaysLeft(
  MaintenanceTask task,
  MaintenanceRecord? record, {
  required DateTime now,
}) {
  if (record == null) return null;
  final DateTime last =
      DateTime.fromMillisecondsSinceEpoch(record.lastDoneMs);
  // GÜN SAYIMI UTC ÜZERİNDEN: yaz saati uygulayan ülkelerde yerel saatle
  // yapılan çıkarma 23/25 saatlik günler yüzünden bir gün şaşabilir.
  // Tarihler zaten "gün" hassasiyetinde tutulur; UTC'de sayım kesindir.
  final DateTime due = DateTime.utc(last.year, last.month, last.day)
      .add(Duration(days: maintenanceIntervalDays(task, record)));
  final DateTime today = DateTime.utc(now.year, now.month, now.day);
  return due.difference(today).inDays;
}

/// Kalemin durumu — SAF hesap (teste açık).
MaintenanceStatus maintenanceStatus(
  MaintenanceTask task,
  MaintenanceRecord? record, {
  required DateTime now,
}) {
  final int? left = maintenanceDaysLeft(task, record, now: now);
  if (left == null) return MaintenanceStatus.notLogged;
  if (left < 0) return MaintenanceStatus.overdue;
  if (left <= kMaintenanceSoonDays) return MaintenanceStatus.dueSoon;
  return MaintenanceStatus.ok;
}

/// Bakım deposu — testte sahtesiyle değiştirilir (en iyi çaba: fırlatmaz).
abstract interface class MaintenanceStore {
  Future<List<MaintenanceRecord>> load();
  Future<void> save(List<MaintenanceRecord> records);
}
