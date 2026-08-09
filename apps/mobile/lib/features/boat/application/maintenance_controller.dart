import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_maintenance_store.dart';
import '../domain/maintenance.dart';

/// Bakım deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<MaintenanceStore> maintenanceStoreProvider =
    Provider<MaintenanceStore>((ref) => const SharedPrefsMaintenanceStore());

/// BAKIM KAYITLARI beyni (v2.0 "Teknem", kurucu onayı 2026-08): cihazda
/// kalıcı kayıtlar. YARIŞ KORUMASI günlük/seyir derslerinden aynen:
/// yazma yüklemeyi bekler; yükleme, kullanıcı dokunduysa uygulanmaz.
class MaintenanceController extends Notifier<List<MaintenanceRecord>> {
  bool _touched = false;
  Future<void>? _loading;

  @override
  List<MaintenanceRecord> build() {
    _loading = _load();
    unawaited(_loading);
    return const <MaintenanceRecord>[];
  }

  MaintenanceStore get _store => ref.read(maintenanceStoreProvider);

  Future<void> _load() async {
    final List<MaintenanceRecord> loaded = await _store.load();
    if (_touched || loaded.isEmpty) return;
    state = List<MaintenanceRecord>.unmodifiable(loaded);
  }

  /// Kalemin kaydını getirir (yoksa null → "kayıt yok" durumu).
  MaintenanceRecord? recordFor(String taskId) {
    for (final MaintenanceRecord r in state) {
      if (r.taskId == taskId) return r;
    }
    return null;
  }

  /// "Yapıldı" işaretler ([when] verilmezse bugün). Aralık verilirse
  /// kaptanın kendi aralığı olarak saklanır.
  ///
  /// YÜKLEMEYİ BEKLER (inceleme dersi 2026-08): açılışta disk daha gelmeden
  /// dokunulursa, kaptanın DAHA ÖNCE girdiği özel aralık okunamaz ve sessizce
  /// silinirdi. Önce yükleme beklenir, sonra mevcut kayıtla birleştirilir.
  Future<void> markDone(
    String taskId, {
    DateTime? when,
    int? intervalDays,
  }) async {
    await _loading;
    final DateTime d = when ?? DateTime.now();
    await _upsert(MaintenanceRecord(
      taskId: taskId,
      lastDoneMs: DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
      intervalDays: intervalDays ?? recordFor(taskId)?.intervalDays,
    ));
  }

  /// Yalnız aralığı değiştirir (kayıt yoksa hiçbir şey yapılmaz — tarih
  /// uydurulmaz; önce "yapıldı" girilmelidir).
  Future<void> setInterval(String taskId, int intervalDays) async {
    await _loading; // aynı ders: mevcut kayıt diskten gelmeden okunmaz
    final MaintenanceRecord? cur = recordFor(taskId);
    if (cur == null || intervalDays <= 0) return;
    await _upsert(cur.copyWith(intervalDays: intervalDays));
  }

  /// Kaydı siler — kalem "kayıt yok" durumuna döner.
  Future<void> clear(String taskId) async {
    await _loading;
    _touched = true;
    state = List<MaintenanceRecord>.unmodifiable(
      state.where((MaintenanceRecord r) => r.taskId != taskId),
    );
    await _store.save(state);
  }

  Future<void> _upsert(MaintenanceRecord record) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbiri kaybolmasın
    _touched = true;
    state = List<MaintenanceRecord>.unmodifiable(<MaintenanceRecord>[
      for (final MaintenanceRecord r in state)
        if (r.taskId != record.taskId) r,
      record,
    ]);
    await _store.save(state);
  }
}

final NotifierProvider<MaintenanceController, List<MaintenanceRecord>>
    maintenanceProvider =
    NotifierProvider<MaintenanceController, List<MaintenanceRecord>>(
        MaintenanceController.new);
