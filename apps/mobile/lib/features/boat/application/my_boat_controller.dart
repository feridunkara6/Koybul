import 'dart:async';

import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/origin_provider.dart' show devicePositionProvider;
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../launch/domain/launch_answers.dart' show kHomeMarinaFocusZoom;
import '../../map/application/map_controller.dart' show mapFocusProvider;
import '../../map/domain/map_viewport.dart' show MapFocusRequest;
import '../data/shared_prefs_boat_storage.dart';
import '../domain/boat_storage.dart';
import '../domain/my_boat.dart';

/// Tekne depolama sağlayıcısı — testte sahte ile override edilir.
final Provider<BoatStorage> boatStorageProvider =
    Provider<BoatStorage>((ref) => const SharedPrefsBoatStorage());

/// Kullanıcının teknesi. Tanımlanınca "teknen sığar mı?" rozetleri her
/// lokasyonda görünür ve bilgi cihazda kalıcıdır (uygulama yeniden açılınca
/// geri yüklenir). Depolama en iyi çaba — yoksa bellek içi çalışır.
///
/// HESAP KAPISI (kurucu kararı 2026-10-26): tekne HESABA bağlıdır.
/// - Misafir/çıkış yapılmış oturumda tekne GÖRÜNMEZ (state=null) — ama
///   cihazdaki kayıt SİLİNMEZ; aynı hesapla dönünce geri gelir.
/// - Sahipsiz eski kayıt (ownerUid=null) ilk hesaplı açılışta o hesapça
///   sahiplenilir — mevcut kullanıcıların teknesi kaybolmaz.
/// - Başka hesabın teknesi ne gösterilir ne silinir (dokunulmaz).
class MyBoatController extends Notifier<MyBoat?> {
  /// Kullanıcı açılış-yüklemesi tamamlanmadan tekneyi değiştirdi/sildi mi?
  /// Öyleyse geç gelen `_restore` kullanıcının seçimini EZMEZ (yarış koruması).
  bool _touched = false;

  /// Oturum döngüsü sayacı: giriş/çıkışta build yeniden çalışır; ESKİ
  /// döngünün geç biten `_restore`'u YENİ döngünün durumunu ezemez
  /// (ör. A girdi → restore sürerken çıktı → A'nın teknesi misafire sızmaz).
  int _cycle = 0;

  /// Açılış yüklemesinin bittiği an — açılış kapısı "bağlı marina odağı"nı
  /// vermeden önce bunu bekler (kullanıcı isteği 2026-08: harita, teknenin
  /// bağlı olduğu marina çevresinde açılsın).
  late Future<void> _restored;

  @override
  MyBoat? build() {
    // Oturumu İZLE: giriş/çıkışta bu gövde yeniden çalışır → tekne
    // kendiliğinden görünür/gizlenir, hiçbir ekranın ek iş yapması gerekmez.
    final String? uid = _uidOf(ref.watch(authControllerProvider));
    final int cycle = ++_cycle;
    _touched = false; // yeni oturum döngüsü: yarış koruması sıfırlanır
    if (uid == null) {
      // Hesap yok → tekne yok. Depoya DOKUNMA (çıkış veriyi silmez).
      _restored = Future<void>.value();
      return null;
    }
    final Future<void> f = _restore(uid, cycle);
    _restored = f;
    unawaited(f);
    return null;
  }

  /// Geçerli oturumun sunucu kullanıcı kimliği; misafir hesap SAYILMAZ.
  /// (build İÇİNDE watch, metotlarda read ile çağrılır — Riverpod kuralı.)
  static String? _uidOf(AuthState auth) {
    if (auth is Authenticated && !auth.isGuest) return auth.user.id;
    return null;
  }

  /// Cihazdan yükleme tamamlanınca çözülür (hata durumunda da çözülür —
  /// asla fırlatmaz; depolama sözleşmesiyle aynı: en iyi çaba).
  Future<void> ensureRestored() => _restored;

  BoatStorage get _storage => ref.read(boatStorageProvider);

  /// Açılışta cihazdan yükler; kayıt bu hesaba aitse VE kullanıcı henüz
  /// dokunmadıysa uygular. Sahipsiz eski kayıt bu hesapça sahiplenilir.
  Future<void> _restore(String uid, int cycle) async {
    final MyBoat? boat = await _storage.load();
    if (cycle != _cycle || _touched || boat == null) return;
    if (boat.ownerUid == null) {
      // ESKİ KAYIT SAHİPLENME: kapıdan önce tanımlanmış tekne ilk hesaplı
      // açılışta bu hesaba yazılır — kurucu dâhil kimsenin teknesi uçmaz.
      final MyBoat adopted = boat.withOwner(uid);
      state = adopted;
      unawaited(_storage.save(adopted));
      _maybeFocusHomeMarina(adopted);
      return;
    }
    if (boat.ownerUid != uid) return; // başka hesabın teknesi — dokunma
    state = boat;
    _maybeFocusHomeMarina(boat);
  }

  /// BAĞLI MARİNA AÇILIŞ ODAĞI (kullanıcı isteği 2026-08): GPS yokken harita
  /// teknenin marinası çevresinde açılır. Eskiden açılış kapısı kurardı; hesap
  /// kapısından sonra oturum geri yüklemesi kapı kararından GEÇ bitebilir —
  /// odak artık teknenin gerçekten geri geldiği ANDA, buradan verilir.
  /// Yalnız kimse odak kurmamışken (null) dokunur; bölge/konum odağını EZMEZ.
  void _maybeFocusHomeMarina(MyBoat boat) {
    try {
      final HomeMarina? hm = boat.homeMarina;
      if (hm == null) return;
      if (ref.read(devicePositionProvider) != null) return;
      if (ref.read(mapFocusProvider) != null) return;
      ref.read(mapFocusProvider.notifier).state = MapFocusRequest(
        point: GeoPoint(lat: hm.lat, lon: hm.lon),
        seq: 1,
        zoom: kHomeMarinaFocusZoom,
      );
    } catch (_) {/* en iyi çaba — odak süslemedir, tekneyi geciktirmez */}
  }

  void set(MyBoat boat) {
    final String? uid = _uidOf(ref.read(authControllerProvider));
    _touched = true;
    // Hesap varsa kayıt o hesabın kimliğiyle damgalanır ve görünür.
    // Hesap YOKSA (tek ungated yazar: açılış akışı ölçü sorusu) cevap
    // SAHİPSİZ saklanır ama GÖSTERİLMEZ — ilk hesap açılışında sahiplenilir;
    // kaptanın açılışta verdiği cevap çöpe gitmez, kapı da delinmez.
    final MyBoat owned = boat.withOwner(uid);
    if (uid != null) state = owned;
    unawaited(_storage.save(owned));
  }

  void clear() {
    _touched = true;
    state = null;
    unawaited(_storage.clear());
  }
}

final NotifierProvider<MyBoatController, MyBoat?> myBoatProvider =
    NotifierProvider<MyBoatController, MyBoat?>(MyBoatController.new);
