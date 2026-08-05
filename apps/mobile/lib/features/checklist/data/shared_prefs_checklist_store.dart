import 'package:shared_preferences/shared_preferences.dart';

import '../domain/checklist_store.dart';

/// `ChecklistStore`'un `shared_preferences` uygulaması (en iyi çaba).
class SharedPrefsChecklistStore implements ChecklistStore {
  const SharedPrefsChecklistStore();

  static const String _dayKey = 'checklist.v1.day';
  static const String _maskKey = 'checklist.v1.mask';
  static const String _askKey = 'checklist.v1.askDay';

  @override
  Future<(String?, int)> loadChecks() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return (prefs.getString(_dayKey), prefs.getInt(_maskKey) ?? 0);
    } catch (_) {
      return (null, 0);
    }
  }

  @override
  Future<void> saveChecks(String dayKey, int mask) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dayKey, dayKey);
      await prefs.setInt(_maskKey, mask);
    } catch (_) {
      // sessizce geç
    }
  }

  @override
  Future<String?> loadAskDay() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_askKey);
    } catch (_) {
      // Depo bozuksa "bugün soruldu" varsayılamaz — null döner; en kötü
      // ihtimalle şerit bir kez daha görünür (nag'lemekten iyidir).
      return null;
    }
  }

  @override
  Future<void> saveAskDay(String dayKey) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_askKey, dayKey);
    } catch (_) {
      // sessizce geç
    }
  }
}
