import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/shared_prefs_saved_routes_store.dart';
import '../domain/saved_route.dart';

/// Kayıtlı rota deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<SavedRoutesStore> savedRoutesStoreProvider =
    Provider<SavedRoutesStore>((ref) => const SharedPrefsSavedRoutesStore());

/// KAYITLI ROTALAR beyni (rota planlama 2026-08): cihazda kalıcı liste.
/// En yeni kayıt başta.
///
/// HESAP KAPISI (kurucu kararı 2026-10-26, teknede olduğu gibi): kayıtlı
/// rotalar HESABA bağlıdır.
/// - Misafir/çıkış yapılmış oturumda liste BOŞ görünür — cihazdaki kayıtlar
///   SİLİNMEZ; aynı hesapla dönünce geri gelir.
/// - Sahipsiz eski kayıtlar ilk hesaplı açılışta o hesapça sahiplenilir.
/// - Başka hesabın rotaları ne gösterilir ne silinir: diske yazarken
///   görünen liste + o gizli kayıtlar BİRLİKTE yazılır (veri kaybı yok).
class SavedRoutesController extends Notifier<List<SavedRoute>> {
  /// YARIŞ KORUMASI (kullanıcı hatası 2026-08, "kaydettim ama listede yok"):
  /// sağlayıcı İLK kez tam kayıt anında kurulunca, diskten yükleme ile yeni
  /// ekleme yarışıyordu — geç gelen eski liste yeni kaydı bellekte EZİYOR,
  /// erken kaydetme de diskteki eski kayıtları silebiliyordu. Kural: ekleme/
  /// silme önce yüklemenin bitmesini BEKLER; yükleme de kullanıcı dokunduysa
  /// sonucu uygulamaz (MyBoatController ile aynı ilke).
  bool _touched = false;
  Future<void>? _loading;

  /// Oturum döngüsü sayacı (teknedekiyle aynı): giriş/çıkışta build yeniden
  /// çalışır; eski döngünün geç biten yüklemesi yeni durumu ezemez.
  int _cycle = 0;

  /// Diskte duran ama BU hesaba ait olmayan kayıtlar — gösterilmez, kaydetme
  /// sırasında aynen geri yazılır (başkasının rotası asla silinmez).
  List<SavedRoute> _hidden = const <SavedRoute>[];

  @override
  List<SavedRoute> build() {
    // Oturumu İZLE: giriş/çıkışta liste kendiliğinden dolar/boşalır.
    final String? uid = _uidOf(ref.watch(authControllerProvider));
    final int cycle = ++_cycle;
    _touched = false;
    _hidden = const <SavedRoute>[];
    if (uid == null) {
      // Hesap yok → liste boş. Depoya DOKUNMA (çıkış veriyi silmez).
      _loading = Future<void>.value();
      return const <SavedRoute>[];
    }
    final Future<void> f = _load(uid, cycle);
    _loading = f;
    unawaited(f);
    return const <SavedRoute>[];
  }

  /// Geçerli oturumun sunucu kullanıcı kimliği; misafir hesap SAYILMAZ.
  static String? _uidOf(AuthState auth) {
    if (auth is Authenticated && !auth.isGuest) return auth.user.id;
    return null;
  }

  SavedRoutesStore get _store => ref.read(savedRoutesStoreProvider);

  Future<void> _load(String uid, int cycle) async {
    final List<SavedRoute> loaded = await _store.load();
    if (cycle != _cycle || _touched || loaded.isEmpty) return;
    final List<SavedRoute> mine = <SavedRoute>[];
    final List<SavedRoute> hidden = <SavedRoute>[];
    bool adopted = false;
    for (final SavedRoute r in loaded) {
      if (r.ownerUid == uid) {
        mine.add(r);
      } else if (r.ownerUid == null) {
        // ESKİ KAYIT SAHİPLENME: kapıdan önce kaydedilmiş rotalar ilk
        // hesaplı açılışta bu hesaba yazılır — kimsenin rotası uçmaz.
        mine.add(r.withOwner(uid));
        adopted = true;
      } else {
        hidden.add(r); // başka hesabın rotası — gösterme, ama koru
      }
    }
    _hidden = List<SavedRoute>.unmodifiable(hidden);
    if (mine.isEmpty) return; // durum zaten boş liste
    mine.sort((SavedRoute a, SavedRoute b) => b.savedAtMs - a.savedAtMs);
    state = List<SavedRoute>.unmodifiable(mine);
    if (adopted) {
      unawaited(_store.save(<SavedRoute>[...state, ..._hidden]));
    }
  }

  Future<void> add(SavedRoute route) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbir kayıt kaybolmasın
    final String? uid = _uidOf(ref.read(authControllerProvider));
    if (uid == null) return; // kapı zaten engeller; emniyet kemeri
    _touched = true;
    state =
        List<SavedRoute>.unmodifiable(<SavedRoute>[route.withOwner(uid), ...state]);
    await _store.save(<SavedRoute>[...state, ..._hidden]);
  }

  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<SavedRoute>.unmodifiable(
      state.where((SavedRoute r) => r.id != id),
    );
    await _store.save(<SavedRoute>[...state, ..._hidden]);
  }
}

final NotifierProvider<SavedRoutesController, List<SavedRoute>>
    savedRoutesProvider =
    NotifierProvider<SavedRoutesController, List<SavedRoute>>(
        SavedRoutesController.new);
