import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sea_trip_log.dart';

/// `SeaTripLogStore`'un `shared_preferences` uygulaması. Günlük deposuyla
/// aynı ilkeler: her seyir tek JSON satırı; bozuk satırlar sessizce atlanır;
/// depo hatası asla fırlatmaz (en iyi çaba).
class SharedPrefsTripStore implements SeaTripLogStore {
  const SharedPrefsTripStore();

  static const String _key = 'trips.v1.entries';
  static const String _activeKey = 'trips.v1.active';

  @override
  Future<List<SeaTripLog>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList(_key) ?? const <String>[];
      final List<SeaTripLog> out = <SeaTripLog>[];
      for (final String line in raw) {
        final SeaTripLog? e = SeaTripLog.fromJson(jsonDecode(line));
        if (e != null) out.add(e);
      }
      return out;
    } catch (_) {
      return const <SeaTripLog>[];
    }
  }

  @override
  Future<void> save(List<SeaTripLog> trips) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        <String>[for (final SeaTripLog e in trips) jsonEncode(e.toJson())],
      );
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }

  @override
  Future<ActiveTrip?> loadActive() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_activeKey);
      if (raw == null) return null;
      return ActiveTrip.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveActive(ActiveTrip? trip) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (trip == null) {
        await prefs.remove(_activeKey);
      } else {
        await prefs.setString(_activeKey, jsonEncode(trip.toJson()));
      }
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }
}
