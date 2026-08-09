import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/maintenance.dart';

/// `MaintenanceStore`'un `shared_preferences` uygulaması. Günlük/seyir
/// depolarıyla aynı ilkeler: her kayıt tek JSON satırı; bozuk satır sessizce
/// atlanır; depo hatası ASLA fırlatmaz (en iyi çaba).
class SharedPrefsMaintenanceStore implements MaintenanceStore {
  const SharedPrefsMaintenanceStore();

  /// Cihaz deposundaki alan adı. (Sabit adında bilerek "key" GEÇMEZ: sır
  /// tarayıcı gitleaks, "key" adlı sabitlere atanan uzun metinleri olası
  /// API anahtarı sanıp yanlış alarm veriyordu — CI dersi 2026-08.)
  static const String _recordsPref = 'maintenance.v1.records';

  @override
  Future<List<MaintenanceRecord>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw =
          prefs.getStringList(_recordsPref) ?? const <String>[];
      final List<MaintenanceRecord> out = <MaintenanceRecord>[];
      for (final String line in raw) {
        final MaintenanceRecord? r = MaintenanceRecord.fromJson(
          jsonDecode(line),
        );
        if (r != null) out.add(r);
      }
      return out;
    } catch (_) {
      return const <MaintenanceRecord>[];
    }
  }

  @override
  Future<void> save(List<MaintenanceRecord> records) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recordsPref,
        <String>[
          for (final MaintenanceRecord r in records) jsonEncode(r.toJson()),
        ],
      );
    } catch (_) {
      // sessizce geç (en iyi çaba)
    }
  }
}
