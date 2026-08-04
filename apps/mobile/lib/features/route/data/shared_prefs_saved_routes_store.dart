import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_route.dart';

/// `SavedRoutesStore`'un `shared_preferences` uygulaması. Her rota tek JSON
/// satırı; bozuk satırlar sessizce atlanır (en iyi çaba — asla fırlatmaz).
class SharedPrefsSavedRoutesStore implements SavedRoutesStore {
  const SharedPrefsSavedRoutesStore();

  static const String _key = 'routes.v1.saved';

  @override
  Future<List<SavedRoute>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList(_key) ?? const <String>[];
      final List<SavedRoute> out = <SavedRoute>[];
      for (final String line in raw) {
        final SavedRoute? r = SavedRoute.fromJson(jsonDecode(line));
        if (r != null) out.add(r);
      }
      return out;
    } catch (_) {
      return const <SavedRoute>[];
    }
  }

  @override
  Future<void> save(List<SavedRoute> routes) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        <String>[for (final SavedRoute r in routes) jsonEncode(r.toJson())],
      );
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }
}
