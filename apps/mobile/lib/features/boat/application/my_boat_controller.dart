import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_boat_storage.dart';
import '../domain/boat_storage.dart';
import '../domain/my_boat.dart';

/// Tekne depolama sağlayıcısı — testte sahte ile override edilir.
final Provider<BoatStorage> boatStorageProvider =
    Provider<BoatStorage>((ref) => const SharedPrefsBoatStorage());

/// Kullanıcının teknesi. Tanımlanınca "teknen sığar mı?" rozetleri her
/// lokasyonda görünür ve bilgi cihazda kalıcıdır (uygulama yeniden açılınca
/// geri yüklenir). Depolama en iyi çaba — yoksa bellek içi çalışır.
class MyBoatController extends Notifier<MyBoat?> {
  /// Kullanıcı açılış-yüklemesi tamamlanmadan tekneyi değiştirdi/sildi mi?
  /// Öyleyse geç gelen `_restore` kullanıcının seçimini EZMEZ (yarış koruması).
  bool _touched = false;

  /// Açılış yüklemesinin bittiği an — açılış kapısı "bağlı marina odağı"nı
  /// vermeden önce bunu bekler (kullanıcı isteği 2026-08: harita, teknenin
  /// bağlı olduğu marina çevresinde açılsın).
  late Future<void> _restored;

  @override
  MyBoat? build() {
    final Future<void> f = _restore();
    _restored = f;
    unawaited(f);
    return null;
  }

  /// Cihazdan yükleme tamamlanınca çözülür (hata durumunda da çözülür —
  /// asla fırlatmaz; depolama sözleşmesiyle aynı: en iyi çaba).
  Future<void> ensureRestored() => _restored;

  BoatStorage get _storage => ref.read(boatStorageProvider);

  /// Açılışta cihazdan yükler; kayıt varsa VE kullanıcı henüz dokunmadıysa uygular.
  Future<void> _restore() async {
    final MyBoat? boat = await _storage.load();
    if (_touched || boat == null) return;
    state = boat;
  }

  void set(MyBoat boat) {
    _touched = true;
    state = boat;
    unawaited(_storage.save(boat));
  }

  void clear() {
    _touched = true;
    state = null;
    unawaited(_storage.clear());
  }
}

final NotifierProvider<MyBoatController, MyBoat?> myBoatProvider =
    NotifierProvider<MyBoatController, MyBoat?>(MyBoatController.new);
