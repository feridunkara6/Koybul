import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
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
///
/// HESAP KAPISI (saha hatası 2026-10-27, Defter paketi): Defter'in üç rafı
/// da (Seyirler/Rotalarım/Notlar) hesapla gelir, çıkışta görünmez olur.
/// Cihazdaki kayıtlar SİLİNMEZ; aynı hesapla dönünce geri gelir. Sahipsiz
/// eski girişler ilk hesaplı açılışta sahiplenilir; başka hesabın girişleri
/// gösterilmez ama diske aynen geri yazılır (veri kaybı yok).
class LogbookController extends Notifier<List<LogEntry>> {
  bool _touched = false;
  Future<void>? _loading;

  /// Oturum döngüsü sayacı (kayıtlı rotalardaki desen).
  int _cycle = 0;

  /// Diskte duran ama BU hesaba ait olmayan girişler — korunur, gösterilmez.
  List<LogEntry> _hidden = const <LogEntry>[];

  @override
  List<LogEntry> build() {
    final String? uid = _uidOf(ref.watch(authControllerProvider));
    final int cycle = ++_cycle;
    _touched = false;
    _hidden = const <LogEntry>[];
    if (uid == null) {
      // Hesap yok → liste boş. Depoya DOKUNMA (çıkış veriyi silmez).
      _loading = Future<void>.value();
      return const <LogEntry>[];
    }
    final Future<void> f = _load(uid, cycle);
    _loading = f;
    unawaited(f);
    return const <LogEntry>[];
  }

  /// Geçerli oturumun sunucu kullanıcı kimliği; misafir hesap SAYILMAZ.
  static String? _uidOf(AuthState auth) {
    if (auth is Authenticated && !auth.isGuest) return auth.user.id;
    return null;
  }

  LogbookStore get _store => ref.read(logbookStoreProvider);

  Future<void> _load(String uid, int cycle) async {
    final List<LogEntry> loaded = await _store.load();
    if (cycle != _cycle || _touched || loaded.isEmpty) return;
    final List<LogEntry> mine = <LogEntry>[];
    final List<LogEntry> hidden = <LogEntry>[];
    bool adopted = false;
    for (final LogEntry e in loaded) {
      if (e.ownerUid == uid) {
        mine.add(e);
      } else if (e.ownerUid == null) {
        // ESKİ GİRİŞ SAHİPLENME: kapıdan önce yazılmış günlükler ilk
        // hesaplı açılışta bu hesaba yazılır — kimsenin hikâyesi uçmaz.
        mine.add(e.withOwner(uid));
        adopted = true;
      } else {
        hidden.add(e); // başka hesabın girişi — gösterme, ama koru
      }
    }
    _hidden = List<LogEntry>.unmodifiable(hidden);
    if (mine.isEmpty) return; // durum zaten boş liste
    mine.sort((LogEntry a, LogEntry b) => b.dateMs - a.dateMs);
    state = List<LogEntry>.unmodifiable(mine);
    if (adopted) {
      unawaited(_store.save(<LogEntry>[...state, ..._hidden]));
    }
  }

  Future<void> add(LogEntry entry) async {
    await _loading; // diskteki girişler gelsin — hiçbir kayıt kaybolmasın
    final String? uid = _uidOf(ref.read(authControllerProvider));
    if (uid == null) return; // kapı zaten engeller; emniyet kemeri
    _touched = true;
    state =
        List<LogEntry>.unmodifiable(<LogEntry>[entry.withOwner(uid), ...state]);
    await _store.save(<LogEntry>[...state, ..._hidden]);
  }

  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<LogEntry>.unmodifiable(
      state.where((LogEntry e) => e.id != id),
    );
    await _store.save(<LogEntry>[...state, ..._hidden]);
  }

  /// GERİ AL (P0, UX denetimi 2026-08 — kullanıcı onaylı): silme artık
  /// "kaydır → sil + Geri al" akışıyla çalışır; bu metot snackbar'daki
  /// Geri al'ın beynidir. Giriş, TARİH SIRASI BOZULMADAN geri gelir (liste
  /// her zaman en-yeni-başta) ve çift dokunuş çift kayıt üretmez.
  Future<void> restore(LogEntry entry) async {
    await _loading;
    final String? uid = _uidOf(ref.read(authControllerProvider));
    if (uid == null) return;
    _touched = true;
    if (state.any((LogEntry e) => e.id == entry.id)) return;
    state = List<LogEntry>.unmodifiable(
      <LogEntry>[entry.withOwner(uid), ...state]
        ..sort((LogEntry a, LogEntry b) => b.dateMs - a.dateMs),
    );
    await _store.save(<LogEntry>[...state, ..._hidden]);
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
