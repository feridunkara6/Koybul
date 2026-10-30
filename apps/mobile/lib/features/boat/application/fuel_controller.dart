import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/shared_prefs_fuel_store.dart';
import '../domain/fuel.dart';

/// Yakıt deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<FuelStore> fuelStoreProvider =
    Provider<FuelStore>((ref) => const SharedPrefsFuelStore());

/// YAKIT KAYITLARI beyni (kurucu onayı 2026-10-30) — bakım kontrolcüsünün
/// birebir kardeşi.
///
/// HESAP KAPISI (kurucu kuralı): kayıtlar HESAPLA GELİR, çıkışta GÖRÜNMEZ
/// olur; cihazdan SİLİNMEZ — aynı hesapla dönünce geri gelir. Sahipsiz eski
/// kayıtlar ilk hesaplı açılışta sahiplenilir; başka hesabın kayıtları
/// gösterilmez ama diske aynen geri yazılır.
class FuelController extends Notifier<List<FuelEntry>> {
  bool _touched = false;
  Future<void>? _loading;

  /// Oturum döngüsü sayacı (bakım deseni): giriş/çıkışta build yeniden
  /// çalışır; eski döngünün geç biten yüklemesi yeni durumu ezemez.
  int _cycle = 0;

  /// Diskte duran ama BU hesaba ait olmayan kayıtlar — korunur, gösterilmez.
  List<FuelEntry> _hidden = const <FuelEntry>[];

  @override
  List<FuelEntry> build() {
    final String? uid = _uidOf(ref.watch(authControllerProvider));
    final int cycle = ++_cycle;
    _touched = false;
    _hidden = const <FuelEntry>[];
    if (uid == null) {
      // Hesap yok → liste boş. Depoya DOKUNMA (çıkış veriyi silmez).
      _loading = Future<void>.value();
      return const <FuelEntry>[];
    }
    final Future<void> f = _load(uid, cycle);
    _loading = f;
    unawaited(f);
    return const <FuelEntry>[];
  }

  /// Geçerli oturumun sunucu kullanıcı kimliği; misafir hesap SAYILMAZ.
  static String? _uidOf(AuthState auth) {
    if (auth is Authenticated && !auth.isGuest) return auth.user.id;
    return null;
  }

  FuelStore get _store => ref.read(fuelStoreProvider);

  Future<void> _load(String uid, int cycle) async {
    final List<FuelEntry> loaded = await _store.load();
    if (cycle != _cycle || _touched || loaded.isEmpty) return;
    final List<FuelEntry> mine = <FuelEntry>[];
    final List<FuelEntry> hidden = <FuelEntry>[];
    bool adopted = false;
    for (final FuelEntry e in loaded) {
      if (e.ownerUid == uid) {
        mine.add(e);
      } else if (e.ownerUid == null) {
        mine.add(e.withOwner(uid));
        adopted = true;
      } else {
        hidden.add(e); // başka hesabın kaydı — gösterme, ama koru
      }
    }
    _hidden = List<FuelEntry>.unmodifiable(hidden);
    if (mine.isEmpty) return;
    state = _sorted(mine);
    if (adopted) {
      unawaited(_store.save(<FuelEntry>[...state, ..._hidden]));
    }
  }

  static List<FuelEntry> _sorted(List<FuelEntry> list) {
    final List<FuelEntry> out = <FuelEntry>[...list]
      ..sort((FuelEntry a, FuelEntry b) => b.dateMs.compareTo(a.dateMs));
    return List<FuelEntry>.unmodifiable(out);
  }

  /// Dolum ekler — tek zorunlu bilgi litre; tarih gün hassasiyetindedir.
  Future<void> add({
    required DateTime day,
    required double liters,
    double? cost,
    double? engineHours,
  }) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbiri kaybolmasın
    final String? uid = _uidOf(ref.read(authControllerProvider));
    if (uid == null || liters <= 0) return; // kapı üstte; emniyet kemeri
    _touched = true;
    final FuelEntry entry = FuelEntry(
      id: 'f${DateTime.now().millisecondsSinceEpoch}',
      // Öğlen 12:00 sabitlenir (seyir kaydı dersi: yaz saati sınırında gün
      // kaymasın diye gece yarısı yerine gün ortası).
      dateMs: DateTime(day.year, day.month, day.day, 12).millisecondsSinceEpoch,
      liters: liters,
      cost: cost,
      engineHours: engineHours,
      ownerUid: uid,
    );
    state = _sorted(<FuelEntry>[...state, entry]);
    await _store.save(<FuelEntry>[...state, ..._hidden]);
  }

  /// Kaydı siler (yanlış giriş düzeltmesi — dolumun dönüşü yok, girişin var).
  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<FuelEntry>.unmodifiable(
      state.where((FuelEntry e) => e.id != id),
    );
    await _store.save(<FuelEntry>[...state, ..._hidden]);
  }
}

final NotifierProvider<FuelController, List<FuelEntry>> fuelProvider =
    NotifierProvider<FuelController, List<FuelEntry>>(FuelController.new);
