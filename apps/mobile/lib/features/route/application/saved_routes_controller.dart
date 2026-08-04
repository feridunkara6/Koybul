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
  @override
  List<SavedRoute> build() {
    unawaited(_load());
    return const <SavedRoute>[];
  }

  SavedRoutesStore get _store => ref.read(savedRoutesStoreProvider);

  Future<void> _load() async {
    final List<SavedRoute> loaded = await _store.load();
    if (loaded.isEmpty) return;
    state = List<SavedRoute>.unmodifiable(
      loaded..sort((SavedRoute a, SavedRoute b) => b.savedAtMs - a.savedAtMs),
    );
  }

  Future<void> add(SavedRoute route) async {
    state = List<SavedRoute>.unmodifiable(<SavedRoute>[route, ...state]);
    await _store.save(state);
  }

  Future<void> remove(String id) async {
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
