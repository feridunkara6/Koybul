import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_gateway.dart';

/// Gerçek FCM köprüsü — YALNIZ bootstrap'ta, Firebase başlatıldıysa devreye
/// girer (authGateway deseni). Tüm çağrılar en-iyi-çaba: eklenti hatası
/// uygulamayı asla düşürmez, kayıt bir sonraki açılışta yeniden denenir.
class FirebasePushGateway implements PushGateway {
  @override
  Future<bool> requestPermission() async {
    try {
      // AÇIKÇA tam izin istenir (saha düzeltmesi 2026-10-27): provisional
      // (sessiz teslim) İSTENMEZ — sessiz izinde bildirim kilit ekranına
      // düşmez, bildirim merkezine sessizce girer; kaptan "gelmiyor" sanır.
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      // Ön planda da afiş görünsün (iOS varsayılanı sessizdir).
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
              alert: true, badge: true, sound: true);
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    // iOS'ta APNs tokenı FCM tokenından ÖNCE hazır olmalı; izinden hemen
    // sonra istenirse kısa bir yarış olabilir — bir kez bekleyip tekrar dene.
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final String? t = await FirebaseMessaging.instance.getToken();
        if (t != null) return t;
      } catch (_) {/* aşağıda tekrar denenir */}
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<Map<String, String>> get onNotificationTap async* {
    // Uygulama BİLDİRİMDEN açıldıysa ilk mesaj burada yakalanır (soğuk
    // açılış yolu) — sonra arka plandan öne geçiş dokunuşları akar.
    try {
      final RemoteMessage? initial =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) yield _dataOf(initial);
    } catch (_) {/* en iyi çaba — akış sürer */}
    yield* FirebaseMessaging.onMessageOpenedApp.map(_dataOf);
  }

  static Map<String, String> _dataOf(RemoteMessage m) =>
      m.data.map((String k, dynamic v) => MapEntry(k, '$v'));
}
