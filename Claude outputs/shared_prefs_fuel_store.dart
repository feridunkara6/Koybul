import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fuel.dart';

/// `FuelStore`'un `shared_preferences` uygulaması — bakım deposuyla aynı
/// ilkeler: her kayıt tek JSON satırı; bozuk satır sessizce atlanır; depo
/// hatası ASLA fırlatmaz (en iyi çaba).
class SharedPrefsFuelStore implements FuelStore {
  const SharedPrefsFuelStore();

  /// Cihaz deposundaki alan adı (sabit adında bilerek "key" geçmez —
  /// gitleaks dersi, bakım deposuyla aynı not).
  static const String _recordsPref = 'fuel.v1.records';

  @override
  Future<List<FuelEntry>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw =
          prefs.getStringList(_recordsPref) ?? const <String>[];
      final List<FuelEntry> out = <FuelEntry>[];
      for (final String line in raw) {
        final FuelEntry? e = FuelEntry.fromJson(jsonDecode(line));
        if (e != null) out.add(e);
      }
      return out;
    } catch (_) {
      return const <FuelEntry>[];
    }
  }

  @override
  Future<void> save(List<FuelEntry> entries) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recordsPref,
        <String>[for (final FuelEntry e in entries) jsonEncode(e.toJson())],
      );
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }
}
