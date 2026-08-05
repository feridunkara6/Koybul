/// AÇILIŞ AKIŞI DEPOSU (onaylı tasarım 2026-08, E1–E7 onboarding v2 iskeleti).
///
/// "Karşılama ekranı (E2) gösterildi mi?" bayrağını cihazda tutar. Sözleşme
/// [WelcomeStore] ile aynıdır: EN İYİ ÇABA, asla fırlatmaz. Depolama bozuksa
/// kullanıcıyı her açılışta karşılama ekranıyla yormaktansa "tamamlandı"
/// varsayılır (dönen kullanıcı doğrudan haritaya — onaylı E1 kuralı).
abstract interface class LaunchStore {
  /// Karşılama akışı daha önce tamamlandı mı?
  Future<bool> isDone();

  /// Karşılama akışını tamamlandı olarak işaretler.
  Future<void> markDone();
}
