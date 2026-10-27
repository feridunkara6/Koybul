import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/local_notifier.dart';

/// flutter_local_notifications sarmalayıcısı — bakım hatırlatması İÇİN
/// yeterli en küçük yüzey: başlat + göster. Zamanlama (zonedSchedule) ve
/// timezone bağımlılığı BİLEREK YOK (v1): kontrol uygulama açılışında
/// yapılır, bildirim o an gösterilir — basit ve test edilebilir.
class FlutterLocalNotifier implements LocalNotifier {
  FlutterLocalNotificationsPlugin? _plugin;

  Future<FlutterLocalNotificationsPlugin?> _ensure() async {
    if (_plugin != null) return _plugin;
    try {
      final FlutterLocalNotificationsPlugin p =
          FlutterLocalNotificationsPlugin();
      // İzinler burada İSTENMEZ (requestAlertPermission: false): sistem izin
      // diyaloğunun tek sahibi push kaydıdır (giriş sonrası). Aynı iOS izni
      // yerel bildirimleri de kapsar.
      await p.initialize(const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      _plugin = p;
      return p;
    } catch (_) {
      return null; // eklenti yoksa/başlatılamadıysa sessizce vazgeç
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    final FlutterLocalNotificationsPlugin? p = await _ensure();
    if (p == null) return;
    try {
      await p.show(
        id,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          android: AndroidNotificationDetails(
            'maintenance',
            'Bakım hatırlatmaları',
            importance: Importance.defaultImportance,
          ),
        ),
      );
    } catch (_) {/* en iyi çaba — bakım şeridi zaten uygulama içinde uyarır */}
  }
}
