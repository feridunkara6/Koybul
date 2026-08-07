import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../logbook/application/logbook_controller.dart'
    show logContextProvider;
import '../../logbook/domain/log_entry.dart' show LogContext;
import '../data/shared_prefs_trip_store.dart';
import '../domain/sea_trip_log.dart';

/// Seyir deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<SeaTripLogStore> tripStoreProvider =
    Provider<SeaTripLogStore>((ref) => const SharedPrefsTripStore());

/// TAMAMLANAN SEYİRLER (v2.0 Defter, kurucu onayı 2026-08): cihazda kalıcı
/// liste, en yeni başta. YARIŞ KORUMASI günlük/rota derslerinden aynen:
/// ekleme/silme yüklemeyi bekler; yükleme, kullanıcı dokunduysa uygulanmaz.
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
    final List<SeaTripLog> loaded = await _store.load();
    if (_touched || loaded.isEmpty) return;
    state = List<SeaTripLog>.unmodifiable(
      loaded..sort((SeaTripLog a, SeaTripLog b) => b.endMs - a.endMs),
    );
  }

  Future<void> add(SeaTripLog trip) async {
    await _loading; // diskteki seyirler gelsin — hiçbir kayıt kaybolmasın
    _touched = true;
    state = List<SeaTripLog>.unmodifiable(<SeaTripLog>[trip, ...state]);
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

/// SÜREN SEYİR beyni: "Seyri başlat" → rota fotoğrafı cihaza yazılır (sayfa
/// yenilense bile seyir sürmeye devam eder); "Seyri bitir" → tamamlanan
/// seyir Defter'e işlenir, süren kayıt silinir.
class ActiveTripController extends Notifier<ActiveTrip?> {
  bool _touched = false;

  @override
  ActiveTrip? build() {
    unawaited(_restore());
    return null;
  }

  SeaTripLogStore get _store => ref.read(tripStoreProvider);

  Future<void> _restore() async {
    final ActiveTrip? active = await _store.loadActive();
    if (_touched || active == null) return;
    state = active;
  }

  /// Seyri başlatır — o anki aktif rotadan ad/mesafe/durak fotoğrafı alır.
  /// Rota bağlamı yoksa (kuramsal) genel başlıkla yine de başlar: kaptanın
  /// "başlat" kararı asla sessizce yutulmaz.
  void start() {
    if (state != null) return; // zaten süren seyir var
    final LogContext? ctx = ref.read(logContextProvider);
    final L10n t = ref.read(l10nProvider);
    _touched = true;
    state = ActiveTrip(
      name: ctx?.routeName ?? t.routeChipTitle,
      startMs: DateTime.now().millisecondsSinceEpoch,
      distanceNm: ctx?.distanceNm ?? 0,
      stops: ctx?.stops ?? 0,
    );
    unawaited(_store.saveActive(state));
  }

  /// Seyri bitirir ve Defter'e işler; işlenen kaydı döndürür (yoksa null).
  Future<SeaTripLog?> finish() async {
    final ActiveTrip? a = state;
    if (a == null) return null;
    _touched = true;
    state = null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final SeaTripLog trip = SeaTripLog(
      id: 't$now',
      name: a.name,
      startMs: a.startMs,
      endMs: now,
      distanceNm: a.distanceNm,
      stops: a.stops,
    );
    await ref.read(tripLogProvider.notifier).add(trip);
    await _store.saveActive(null);
    return trip;
  }
}

final NotifierProvider<ActiveTripController, ActiveTrip?> activeTripProvider =
    NotifierProvider<ActiveTripController, ActiveTrip?>(
        ActiveTripController.new);
