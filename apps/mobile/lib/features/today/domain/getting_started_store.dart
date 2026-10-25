/// BAŞLANGIÇ GÖREVLERİ deposu (Hoş Geldin Paketi, kurucu onayı 2026-10-25).
///
/// Tek bilgi tutulur: kullanıcı kartı eliyle kapattı mı ("Gizle"). Görev
/// durumlarının KENDİSİ burada saklanmaz — onlar gerçek verilerden okunur
/// (tekne, marina, favori, kayıtlı rota); böylece kart asla yalan söylemez.
/// En iyi çaba: asla fırlatmaz.
abstract interface class GettingStartedStore {
  /// Kart kapatıldı mı? Kayıt yoksa/okunamazsa false (kart görünür —
  /// en kötü ihtimalle bir kez daha gösterilir, bu da kabul edilebilir).
  Future<bool> loadDismissed();

  /// "Gizle" kalıcı yazılır — kart bir daha kendiliğinden çıkmaz.
  Future<void> saveDismissed();
}
