import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// GÖÇ: eski "Seyri başlat" akışından kalan bitmemiş 'süren seyir' varsa
/// ilk yüklemede PLANLANDI seferine çevrilir ve eski anahtar temizlenir —
/// hiçbir kaptanın kaydı çöpe gitmez, hiçbir sahte "gerçekleşti" üretilmez.
class TripLogController extends Notifier<List<SeaTripLog>> {
  bool _touched = false;
  Future<void>? _loading;

  @override
  List<SeaTripLog> build() {
    _loading = _load();
    unawaited(_loading);
    return const <SeaTripLog>[];
  }

  SeaTripLogStore get _store => ref.read(tripStoreProvider);

  Future<void> _load() async {
    // Kopya: depo değiştirilemez liste döndürse bile göç ekleyebilmeli.
    final List<SeaTripLog> loaded = List<SeaTripLog>.of(await _store.load());
    // ESKİ SÜREN SEYİR GÖÇÜ (tek seferlik): niyet vardı, bitiş ölçümü yok →
    // dürüst durum PLANLANDI. Eski anahtar silinir ki göç tekrarlanmasın.
    final ActiveTrip? stale = await _store.loadActive();
    bool migrated = false;
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
      migrated = true;
    }
    if (_touched || loaded.isEmpty) return;
    state = List<SeaTripLog>.unmodifiable(
      loaded..sort((SeaTripLog a, SeaTripLog b) => b.dateMs - a.dateMs),
    );
    if (migrated) await _store.save(state);
  }

  Future<void> add(SeaTripLog trip) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbir kayıt kaybolmasın
    _touched = true;
    state = List<SeaTripLog>.unmodifiable(<SeaTripLog>[trip, ...state]);
    await _store.save(state);
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
    await _store.save(state);
  }

  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<SeaTripLog>.unmodifiable(
      state.where((SeaTripLog e) => e.id != id),
    );
    await _store.save(state);
  }
}

final NotifierProvider<TripLogController, List<SeaTripLog>> tripLogProvider =
    NotifierProvider<TripLogController, List<SeaTripLog>>(
        TripLogController.new);
