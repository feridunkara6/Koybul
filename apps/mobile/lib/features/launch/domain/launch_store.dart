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

  /// Yarım kalan akışın adımı (Faz 1 numaralandırması: 0 = karşılama,
  /// 1 = ölçüler, 2 = konum ön-izni, 3 = bölge). Hata/boş → 0. Onaylı
  /// iyileştirme: sekmeyi ölçülerde kapatan kullanıcı ertesi gün orada açar,
  /// başa dönmez.
  ///
  /// Numaraların ANLAMI Faz 1'de değiştiği için depolama anahtarı da
  /// sürümlendi (`onb.v3.step`); eski değerler okunmaz.
  Future<int> step();

  /// Akış adımını cihaza işler (her geçişte çağrılır).
  Future<void> setStep(int value);
}
