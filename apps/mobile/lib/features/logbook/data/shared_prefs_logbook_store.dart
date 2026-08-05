import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/log_entry.dart';

/// `LogbookStore`'un `shared_preferences` uygulaması. Her giriş tek JSON
/// satırı; bozuk satırlar sessizce atlanır (en iyi çaba — asla fırlatmaz).
class SharedPrefsLogbookStore implements LogbookStore {
  const SharedPrefsLogbookStore();

  static const String _key = 'logbook.v1.entries';

  @override
  Future<List<LogEntry>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList(_key) ?? const <String>[];
      final List<LogEntry> out = <LogEntry>[];
      for (final String line in raw) {
        final LogEntry? e = LogEntry.fromJson(jsonDecode(line));
        if (e != null) out.add(e);
      }
      return out;
    } catch (_) {
      return const <LogEntry>[];
    }
  }

  @override
  Future<void> save(List<LogEntry> entries) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        <String>[for (final LogEntry e in entries) jsonEncode(e.toJson())],
      );
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }
}
