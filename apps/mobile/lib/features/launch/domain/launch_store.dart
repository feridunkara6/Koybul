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

  /// Yarım kalan akışın adımı (0 = karşılama, 1 = tekne tipi, 2 = ölçüler,
  /// 3 = bölge). Hata/boş → 0. Onaylı iyileştirme: sekmeyi E4'te kapatan
  /// kullanıcı ertesi gün E4'te açar, başa dönmez.
  Future<int> step();

  /// Akış adımını cihaza işler (her geçişte çağrılır).
  Future<void> setStep(int value);
}
