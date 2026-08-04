/// Yeni kullanıcı tanıtımı kalıcı durumu (2026-08, kullanıcı onaylı):
/// karşılama/tur bir kez gösterilir, ilk-dokunuş ipuçları görüldükçe işlenir.
class OnboardingData {
  const OnboardingData({
    this.welcomeDone = false,
    this.seenHints = const <String>{},
  });

  /// Karşılama kartı kararı verildi (tur başlatıldı YA DA "şimdi değil").
  final bool welcomeDone;

  /// Görülen ilk-dokunuş ipucu anahtarları (bkz. kHint* sabitleri).
  final Set<String> seenHints;
}

/// Tanıtım deposu. En iyi çaba felsefesi (WelcomeStore ile aynı): depolama
/// çalışmıyorsa `load` NULL döner ve tanıtım HİÇ gösterilmez — bozuk depoda
/// kullanıcıyı her açılışta karşılama ekranıyla rahatsız etmemek yeğdir.
abstract interface class OnboardingStore {
  Future<OnboardingData?> load();
  Future<void> save(OnboardingData data);
}
