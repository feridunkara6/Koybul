import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/local_notifier.dart';

/// flutter_local_notifications sarmalayıcısı — bakım hatırlatması İÇİN
/// yeterli en küçük yüzey: başlat + göster + ZAMANLA + iptal.
///
/// ZAMANLAMA (saha isteği 2026-10-27, "uygulama kapalıyken de gelsin"):
/// eşiğin geçileceği an mutlak zaman (epoch ms) olarak kurulur; saat dilimi
/// adına İHTİYAÇ YOK — UTC anı her dilimde aynı fiziksel andır. Telefon o an
/// bildirimi kendisi çalar, uygulamanın açık olması gerekmez.
class FlutterLocalNotifier implements LocalNotifier {
  FlutterLocalNotificationsPlugin? _plugin;
  bool _tzReady = false;

  static const NotificationDetails _details = NotificationDetails(
    iOS: DarwinNotificationDetails(),
    android: AndroidNotificationDetails(
      'maintenance',
      'Bakım hatırlatmaları',
      importance: Importance.defaultImportance,
    ),
  );

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
      await p.show(id, title, body, _details);
    } catch (_) {/* en iyi çaba — bakım şeridi zaten uygulama içinde uyarır */}
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
  }) async {
    final FlutterLocalNotificationsPlugin? p = await _ensure();
    if (p == null) return;
    try {
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        _tzReady = true;
      }
      await p.zonedSchedule(
        id,
        title,
        body,
        // Mutlak an: UTC üzerinden kurulur — dilim adı gerekmez, an aynıdır.
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, atMs),
        _details,
        // Dakika hassasiyeti gerekmez; 'inexact' pil dostudur ve Android'de
        // özel alarm izni istemez (iOS'ta zaten dakikası dakikasına çalar).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // CI dersi (versyion 7 kırmızısı): bu parametre kütüphanede ZORUNLU —
        // eksikken analiz hatası hem mobil testini hem web derlemesini düşürdü.
        // 'absoluteTime' = verdiğimiz an MUTLAKTIR (UTC epoch); saat dilimi
        // değişse de bildirim aynı fiziksel anda çalar (eski iOS yolu için).
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {/* en iyi çaba */}
  }

  @override
  Future<void> cancel(int id) async {
    final FlutterLocalNotificationsPlugin? p = await _ensure();
    if (p == null) return;
    try {
      await p.cancel(id);
    } catch (_) {/* en iyi çaba */}
  }
}
