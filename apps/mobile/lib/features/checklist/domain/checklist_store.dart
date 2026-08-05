/// SEYİR ÖNCESİ KONTROL deposu (kullanıcı onayı 2026-08).
///
/// İki bilgi tutulur, ikisi de GÜNLÜKTÜR (gün değişince sıfırlanır):
/// - işaretli maddelerin bit maskesi (o günün kontrolleri),
/// - nazik şeridin en son sorulduğu gün (günde bir kez sorulur).
/// En iyi çaba: asla fırlatmaz.
abstract interface class ChecklistStore {
  /// (günAnahtarı, maske) — kayıt yoksa (null, 0).
  Future<(String?, int)> loadChecks();

  Future<void> saveChecks(String dayKey, int mask);

  /// Şeridin en son sorulduğu gün anahtarı (yoksa null).
  Future<String?> loadAskDay();

  Future<void> saveAskDay(String dayKey);
}

/// Gün anahtarı: '2026-08-05' — cihaz yerel saatiyle.
String checklistDayKey(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
