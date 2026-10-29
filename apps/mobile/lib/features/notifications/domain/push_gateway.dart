/// PUSH KÖPRÜSÜ soyutlaması (push paketi, kurucu onayı 2026-10-27).
///
/// authGateway ile AYNI desen: varsayılan sağlayıcı no-op stub'dır; gerçek
/// Firebase Messaging köprüsü yalnız bootstrap'ta, Firebase başarıyla
/// başlatıldığında override edilir. Böylece widget testleri ve web hiçbir
/// eklenti kanalına dokunmaz.
abstract interface class PushGateway {
  /// Bildirim izni ister (iOS sistem diyaloğu). İzin verildiyse true.
  Future<bool> requestPermission();

  /// Cihazın FCM tokenı — henüz üretilmediyse/platform desteklemiyorsa null.
  Future<String?> token();

  /// Token tazelenme akışı (FCM token zamanla değişebilir).
  Stream<String> get onTokenRefresh;

  /// BİLDİRİME DOKUNUŞ akışı (SP-2 Döngü, kurucu onayı 2026-10-31):
  /// kullanıcı telefon bildirimine dokununca mesajın `data` yükü düşer
  /// (kind + id). Uygulama kapalıyken dokunulduysa açılıştaki ilk mesaj da
  /// bu akışa verilir — tek dinleyici her iki yolu da tek yerden karşılar.
  Stream<Map<String, String>> get onNotificationTap;
}

/// No-op stub — web ve testler. İzin yok, token yok, akış boş.
class StubPushGateway implements PushGateway {
  const StubPushGateway();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Stream<Map<String, String>> get onNotificationTap =>
      const Stream<Map<String, String>>.empty();
}
