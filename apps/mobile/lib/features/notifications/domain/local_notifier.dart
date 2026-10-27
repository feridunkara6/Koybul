/// YEREL BİLDİRİM soyutlaması (bakım hatırlatması, kurucu talebi 2026-10-27).
///
/// Bakım verisi CİHAZDA yaşar (gizlilik kararı) — hatırlatması da sunucudan
/// değil, telefonun KENDİ bildiriminden gelir. Varsayılan stub no-op'tur;
/// gerçek impl yalnız bootstrap'ta mobilde override edilir (push deseni).
abstract interface class LocalNotifier {
  /// Bildirimi hemen gösterir. [id] aynı kalemin eski bildirimini günceller.
  Future<void> show({required int id, required String title, required String body});
}

/// No-op stub — web ve testler.
class StubLocalNotifier implements LocalNotifier {
  const StubLocalNotifier();

  @override
  Future<void> show({required int id, required String title, required String body}) async {}
}
