import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_saved_routes_store.dart';
import '../domain/saved_route.dart';

/// Kayıtlı rota deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<SavedRoutesStore> savedRoutesStoreProvider =
    Provider<SavedRoutesStore>((ref) => const SharedPrefsSavedRoutesStore());

/// KAYITLI ROTALAR beyni (rota planlama 2026-08): cihazda kalıcı liste —
/// favoriler gibi üyelik istemez. En yeni kayıt başta.
class SavedRoutesController extends Notifier<List<SavedRoute>> {
  /// YARIŞ KORUMASI (kullanıcı hatası 2026-08, "kaydettim ama listede yok"):
  /// sağlayıcı İLK kez tam kayıt anında kurulunca, diskten yükleme ile yeni
  /// ekleme yarışıyordu — geç gelen eski liste yeni kaydı bellekte EZİYOR,
  /// erken kaydetme de diskteki eski kayıtları silebiliyordu. Kural: ekleme/
  /// silme önce yüklemenin bitmesini BEKLER; yükleme de kullanıcı dokunduysa
  /// sonucu uygulamaz (MyBoatController ile aynı ilke).
  bool _touched = false;
  Future<void>? _loading;

  @override
  List<SavedRoute> build() {
    _loading = _load();
    unawaited(_loading);
    return const <SavedRoute>[];
  }

  SavedRoutesStore get _store => ref.read(savedRoutesStoreProvider);

  Future<void> _load() async {
    final List<SavedRoute> loaded = await _store.load();
    if (_touched || loaded.isEmpty) return;
    state = List<SavedRoute>.unmodifiable(
      loaded..sort((SavedRoute a, SavedRoute b) => b.savedAtMs - a.savedAtMs),
    );
  }

  Future<void> add(SavedRoute route) async {
    await _loading; // diskteki kayıtlar gelsin — hiçbir kayıt kaybolmasın
    _touched = true;
    state = List<SavedRoute>.unmodifiable(<SavedRoute>[route, ...state]);
    await _store.save(state);
  }

  Future<void> remove(String id) async {
    await _loading;
    _touched = true;
    state = List<SavedRoute>.unmodifiable(
      state.where((SavedRoute r) => r.id != id),
    );
    await _store.save(state);
  }
}

final NotifierProvider<SavedRoutesController, List<SavedRoute>>
    savedRoutesProvider =
    NotifierProvider<SavedRoutesController, List<SavedRoute>>(
        SavedRoutesController.new);
