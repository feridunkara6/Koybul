/// YEREL BİLDİRİM soyutlaması (bakım hatırlatması, kurucu talebi 2026-10-27).
///
/// Bakım verisi CİHAZDA yaşar (gizlilik kararı) — hatırlatması da sunucudan
/// değil, telefonun KENDİ bildiriminden gelir. Varsayılan stub no-op'tur;
/// gerçek impl yalnız bootstrap'ta mobilde override edilir (push deseni).
///
/// v2 (saha isteği 2026-10-27, "uygulama kapalıyken de gelsin"): anlık
/// göstermenin yanına ZAMANLAMA eklendi — eşiğin geçileceği gün için bildirim
/// telefona önceden kurulur; uygulama hiç açılmasa da o gün çalar.
abstract interface class LocalNotifier {
  /// Bildirimi hemen gösterir. [id] aynı kalemin eski bildirimini günceller.
  Future<void> show({required int id, required String title, required String body});

  /// [atMs] (epoch, ms) anı için bildirim KURAR — uygulama kapalıyken de
  /// çalar. Aynı [id] ile yeniden kurmak eskisini değiştirir (çift çalmaz).
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
  });

  /// Kurulu/gösterilmiş bildirimi iptal eder (örn. bakım "yapıldı" olunca
  /// ya da hesaptan çıkılınca).
  Future<void> cancel(int id);
}

/// No-op stub — web ve testler.
class StubLocalNotifier implements LocalNotifier {
  const StubLocalNotifier();

  @override
  Future<void> show({required int id, required String title, required String body}) async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}
