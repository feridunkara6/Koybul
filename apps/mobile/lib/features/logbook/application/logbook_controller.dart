import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../map/application/map_controller.dart';
import '../../map/domain/map_state.dart';
import '../../route/domain/saved_route.dart' show suggestRouteName;
import '../../route/domain/sea_trip.dart';
import '../data/shared_prefs_logbook_store.dart';
import '../domain/log_entry.dart';

/// Günlük deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<LogbookStore> logbookStoreProvider =
    Provider<LogbookStore>((ref) => const SharedPrefsLogbookStore());

/// KAPTANIN GÜNLÜĞÜ beyni (kullanıcı onayı 2026-08): cihazda kalıcı liste,
/// en yeni giriş başta. YARIŞ KORUMASI kayıtlı-rotalar dersinden aynen:
/// ekleme/silme yüklemeyi bekler; yükleme, kullanıcı dokunduysa uygulanmaz.
class LogbookController extends Notifier<List<LogEntry>> {
  bool _touched = false;
  Future<void>? _loading;

  @override
  List<LogEntry> build() {
    _loading = _load();
    unawaited(_loading);
    return const <LogEntry>[];
  }

  LogbookStore get _store => ref.read(logbookStoreProvider);

  Future<void> _load() async {
    final List<LogEntry> loaded = await _store.load();
    if (_touched || loaded.isEmpty) return;
    state = List<LogEntry>.unmodifiable(
      loaded..sort((LogEntry a, LogEntry b) => b.dateMs - a.dateMs),
    );
  }

  Future<void> add(LogEntry entry) async {
    await _loading; // diskteki girişler gelsin — hiçbir kayıt kaybolmasın
    _touched = true;
    state = List<LogEntry>.unmodifiable(<LogEntry>[entry, ...state]);
    await _store.save(state);
  }

  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<LogEntry>.unmodifiable(
      state.where((LogEntry e) => e.id != id),
    );
    await _store.save(state);
  }

  /// GERİ AL (P0, UX denetimi 2026-08 — kullanıcı onaylı): silme artık
  /// "kaydır → sil + Geri al" akışıyla çalışır; bu metot snackbar'daki
  /// Geri al'ın beynidir. Giriş, TARİH SIRASI BOZULMADAN geri gelir (liste
  /// her zaman en-yeni-başta) ve çift dokunuş çift kayıt üretmez.
  Future<void> restore(LogEntry entry) async {
    await _loading;
    _touched = true;
    if (state.any((LogEntry e) => e.id == entry.id)) return;
    state = List<LogEntry>.unmodifiable(
      <LogEntry>[entry, ...state]
        ..sort((LogEntry a, LogEntry b) => b.dateMs - a.dateMs),
    );
    await _store.save(state);
  }
}

final NotifierProvider<LogbookController, List<LogEntry>> logbookProvider =
    NotifierProvider<LogbookController, List<LogEntry>>(LogbookController.new);

/// OTOMATİK BAĞLAM (onaylı tasarım): o anki aktif rotadan günlük bağlamı.
/// Rota yoksa null — giriş bağlamsız açılır. Testte doğrudan override edilir
/// (harita sahtelerine gerek kalmaz).
final Provider<LogContext?> logContextProvider = Provider<LogContext?>((ref) {
  final MapState s = ref.watch(mapControllerProvider);
  final RouteOrigin? origin = s.routeOrigin;
  if (s.route == null || origin == null || s.routeWaypoints.isEmpty) {
    return null;
  }
  final L10n t = ref.watch(l10nProvider);
  final String originLabel = origin.name ??
      (origin.isDevice ? t.routeOriginDevice : t.routeOriginPicked);
  int stops = 0;
  for (final RouteWaypoint w in s.routeWaypoints) {
    if (w.isStop) stops++;
  }
  return LogContext(
    routeName: suggestRouteName(originLabel, s.routeWaypoints),
    distanceNm: s.route!.distanceNm,
    stops: stops,
  );
});
