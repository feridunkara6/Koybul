import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../notifications/application/maintenance_reminder.dart';
import '../data/shared_prefs_maintenance_store.dart';
import '../domain/maintenance.dart';

/// Bakım deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<MaintenanceStore> maintenanceStoreProvider =
    Provider<MaintenanceStore>((ref) => const SharedPrefsMaintenanceStore());

/// BAKIM KAYITLARI beyni (v2.0 "Teknem", kurucu onayı 2026-08): cihazda
/// kalıcı kayıtlar. YARIŞ KORUMASI günlük/seyir derslerinden aynen:
/// yazma yüklemeyi bekler; yükleme, kullanıcı dokunduysa uygulanmaz.
///
/// HESAP KAPISI (kurucu kararı 2026-10-27): bakım takibi de tekne gibi
/// hesapla gezer — çıkışta görünmez olur, aynı hesapla dönünce geri gelir.
/// Cihazdaki kayıtlar SİLİNMEZ; sahipsiz eski kayıtlar ilk hesaplı açılışta
/// sahiplenilir; başka hesabın kayıtları gösterilmez ama diske aynen geri
/// yazılır (kayıtlı rota/tekne deseninin aynısı).
class MaintenanceController extends Notifier<List<MaintenanceRecord>> {
  bool _touched = false;
  Future<void>? _loading;

  /// Oturum döngüsü sayacı (kayıtlı rotalardaki desen): giriş/çıkışta build
  /// yeniden çalışır; eski döngünün geç biten yüklemesi yeni durumu ezemez.
  int _cycle = 0;

  /// Diskte duran ama BU hesaba ait olmayan kayıtlar — korunur, gösterilmez.
  List<MaintenanceRecord> _hidden = const <MaintenanceRecord>[];

  @override
  List<MaintenanceRecord> build() {
    final String? uid = _uidOf(ref.watch(authControllerProvider));
    final int cycle = ++_cycle;
    _touched = false;
    _hidden = const <MaintenanceRecord>[];
    if (uid == null) {
      // Hesap yok → liste boş. Depoya DOKUNMA (çıkış veriyi silmez).
      _loading = Future<void>.value();
      return const <MaintenanceRecord>[];
    }
    final Future<void> f = _load(uid, cycle);
    _loading = f;
    unawaited(f);
    return const <MaintenanceRecord>[];
  }

  /// Geçerli oturumun sunucu kullanıcı kimliği; misafir hesap SAYILMAZ.
  static String? _uidOf(AuthState auth) {
    if (auth is Authenticated && !auth.isGuest) return auth.user.id;
    return null;
  }

  MaintenanceStore get _store => ref.read(maintenanceStoreProvider);

  Future<void> _load(String uid, int cycle) async {
    final List<MaintenanceRecord> loaded = await _store.load();
    if (cycle != _cycle || _touched || loaded.isEmpty) return;
    final List<MaintenanceRecord> mine = <MaintenanceRecord>[];
    final List<MaintenanceRecord> hidden = <MaintenanceRecord>[];
    bool adopted = false;
    for (final MaintenanceRecord r in loaded) {
      if (r.ownerUid == uid) {
        mine.add(r);
      } else if (r.ownerUid == null) {
        // ESKİ KAYIT SAHİPLENME: kapıdan önce girilmiş bakımlar ilk hesaplı
        // açılışta bu hesaba yazılır — kimsenin bakım geçmişi uçmaz.
        mine.add(r.withOwner(uid));
        adopted = true;
      } else {
        hidden.add(r); // başka hesabın kaydı — gösterme, ama koru
      }
    }
    _hidden = List<MaintenanceRecord>.unmodifiable(hidden);
    if (mine.isEmpty) return; // durum zaten boş liste
    state = List<MaintenanceRecord>.unmodifiable(mine);
    if (adopted) {
      unawaited(_store.save(<MaintenanceRecord>[...state, ..._hidden]));
    }
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
    final String? uid = _uidOf(ref.read(authControllerProvider));
    if (uid == null) return; // kapı zaten engeller; emniyet kemeri
    final DateTime d = when ?? DateTime.now();
    await _upsert(MaintenanceRecord(
      taskId: taskId,
      lastDoneMs: DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
      intervalDays: intervalDays ?? recordFor(taskId)?.intervalDays,
      ownerUid: uid,
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
    await _store.save(<MaintenanceRecord>[...state, ..._hidden]);
    _refreshReminders();
  }

  Future<void> _upsert(MaintenanceRecord record) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbiri kaybolmasın
    _touched = true;
    state = List<MaintenanceRecord>.unmodifiable(<MaintenanceRecord>[
      for (final MaintenanceRecord r in state)
        if (r.taskId != record.taskId) r,
      record,
    ]);
    await _store.save(<MaintenanceRecord>[...state, ..._hidden]);
    _refreshReminders();
  }

  /// Her değişiklikten sonra zamanlanmış bakım bildirimleri tazelenir
  /// ("yapıldı" denilen kalemin eski hatırlatması çalmasın). En iyi çaba.
  void _refreshReminders() {
    unawaited(ref.read(maintenanceReminderProvider).run());
  }
}

final NotifierProvider<MaintenanceController, List<MaintenanceRecord>>
    maintenanceProvider =
    NotifierProvider<MaintenanceController, List<MaintenanceRecord>>(
        MaintenanceController.new);
