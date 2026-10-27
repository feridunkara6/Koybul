import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/shared_prefs_trip_store.dart';
import '../domain/sea_trip_log.dart';

/// Seyir deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<SeaTripLogStore> tripStoreProvider =
    Provider<SeaTripLogStore>((ref) => const SharedPrefsTripStore());

/// SEFER KAYITLARI beyni (v2.1 "Planla → Gerçekleşti", kurucu onayı 2026-08):
/// cihazda kalıcı liste, en yeni başta. YARIŞ KORUMASI günlük/rota
/// derslerinden aynen: ekleme/güncelleme yüklemeyi bekler; yükleme,
/// kullanıcı dokunduysa uygulanmaz.
///
/// HESAP KAPISI (saha hatası 2026-10-27, "çıkış yapınca defterde kayıtlı
/// rota kalıyor"): asıl kalan şey SEYİRLERDİ — planlanan rota kartları bu
/// listede yaşar ve kapı yalnız Rotalarım'dadır sanılıyordu. Artık Defter'in
/// üç rafı da (Seyirler/Rotalarım/Notlar) aynı kuralı izler:
/// - Misafir/çıkış yapılmış oturumda liste BOŞ — cihazdaki kayıtlar SİLİNMEZ,
///   aynı hesapla dönünce geri gelir.
/// - Sahipsiz eski kayıtlar ilk hesaplı açılışta o hesapça sahiplenilir.
/// - Başka hesabın kayıtları ne gösterilir ne silinir (gizli korunur).
///
/// GÖÇ: eski "Seyri başlat" akışından kalan bitmemiş 'süren seyir' varsa
/// ilk HESAPLI yüklemede PLANLANDI seferine çevrilir ve eski anahtar
/// temizlenir — hiçbir kaptanın kaydı çöpe gitmez, sahte "gerçekleşti" yok.
class TripLogController extends Notifier<List<SeaTripLog>> {
  bool _touched = false;
  Future<void>? _loading;

  /// Oturum döngüsü sayacı (kayıtlı rotalardaki desen): giriş/çıkışta build
  /// yeniden çalışır; eski döngünün geç biten yüklemesi yeni durumu ezemez.
  int _cycle = 0;

  /// Diskte duran ama BU hesaba ait olmayan kayıtlar — gösterilmez, kaydetme
  /// sırasında aynen geri yazılır (başkasının seferi asla silinmez).
  List<SeaTripLog> _hidden = const <SeaTripLog>[];

  @override
  List<SeaTripLog> build() {
    final String? uid = _uidOf(ref.watch(authControllerProvider));
    final int cycle = ++_cycle;
    _touched = false;
    _hidden = const <SeaTripLog>[];
    if (uid == null) {
      // Hesap yok → liste boş. Depoya DOKUNMA (çıkış veriyi silmez).
      _loading = Future<void>.value();
      return const <SeaTripLog>[];
    }
    final Future<void> f = _load(uid, cycle);
    _loading = f;
    unawaited(f);
    return const <SeaTripLog>[];
  }

  /// Geçerli oturumun sunucu kullanıcı kimliği; misafir hesap SAYILMAZ.
  static String? _uidOf(AuthState auth) {
    if (auth is Authenticated && !auth.isGuest) return auth.user.id;
    return null;
  }

  SeaTripLogStore get _store => ref.read(tripStoreProvider);

  Future<void> _load(String uid, int cycle) async {
    // Kopya: depo değiştirilemez liste döndürse bile göç ekleyebilmeli.
    final List<SeaTripLog> loaded = List<SeaTripLog>.of(await _store.load());
    // ESKİ SÜREN SEYİR GÖÇÜ (tek seferlik): niyet vardı, bitiş ölçümü yok →
    // dürüst durum PLANLANDI. Eski anahtar silinir ki göç tekrarlanmasın.
    final ActiveTrip? stale = await _store.loadActive();
    if (cycle != _cycle || _touched) return;
    bool dirty = false;
    if (stale != null) {
      loaded.add(SeaTripLog(
        id: 't${stale.startMs}p',
        name: stale.name,
        status: TripStatus.planned,
        dateMs: stale.startMs,
        distanceNm: stale.distanceNm,
        stops: stale.stops,
      ));
      await _store.saveActive(null);
      dirty = true;
    }
    if (loaded.isEmpty) return;
    final List<SeaTripLog> mine = <SeaTripLog>[];
    final List<SeaTripLog> hidden = <SeaTripLog>[];
    for (final SeaTripLog t in loaded) {
      if (t.ownerUid == uid) {
        mine.add(t);
      } else if (t.ownerUid == null) {
        // ESKİ KAYIT SAHİPLENME: kapıdan önce kaydedilmiş seferler ilk
        // hesaplı açılışta bu hesaba yazılır — kimsenin seyri uçmaz.
        mine.add(t.withOwner(uid));
        dirty = true;
      } else {
        hidden.add(t); // başka hesabın seferi — gösterme, ama koru
      }
    }
    _hidden = List<SeaTripLog>.unmodifiable(hidden);
    if (mine.isNotEmpty) {
      mine.sort((SeaTripLog a, SeaTripLog b) => b.dateMs - a.dateMs);
      state = List<SeaTripLog>.unmodifiable(mine);
    }
    if (dirty) await _store.save(<SeaTripLog>[...state, ..._hidden]);
  }

  Future<void> add(SeaTripLog trip) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbir kayıt kaybolmasın
    final String? uid = _uidOf(ref.read(authControllerProvider));
    if (uid == null) return; // kapı zaten engeller; emniyet kemeri
    _touched = true;
    state = List<SeaTripLog>.unmodifiable(
        <SeaTripLog>[trip.withOwner(uid), ...state]);
    await _store.save(<SeaTripLog>[...state, ..._hidden]);
  }

  /// PLANLANDI → GERÇEKLEŞTİ geçişi: kaptanın onayladığı tarih ve (isterse)
  /// denizde geçen süreyle kaydı günceller. İstatistikler ancak bu geçişten
  /// sonra bu kaydı sayar (veri dürüstlüğü ilkesi).
  Future<void> markDone(String id,
      {required int dateMs, int? durMin}) async {
    await _loading;
    _touched = true;
    state = List<SeaTripLog>.unmodifiable(<SeaTripLog>[
      for (final SeaTripLog e in state)
        if (e.id == id)
          e.copyWith(status: TripStatus.done, dateMs: dateMs, durMin: durMin)
        else
          e,
    ]);
    await _store.save(<SeaTripLog>[...state, ..._hidden]);
  }

  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<SeaTripLog>.unmodifiable(
      state.where((SeaTripLog e) => e.id != id),
    );
    await _store.save(<SeaTripLog>[...state, ..._hidden]);
  }
}

final NotifierProvider<TripLogController, List<SeaTripLog>> tripLogProvider =
    NotifierProvider<TripLogController, List<SeaTripLog>>(
        TripLogController.new);
