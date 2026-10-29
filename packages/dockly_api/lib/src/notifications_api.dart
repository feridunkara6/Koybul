import 'package:dio/dio.dart';

import 'dto/inbox_item.dart';
import 'dto/notifications.dart';
import 'problem_mapper.dart';

/// `/v1/notifications/*` istemcisi (push paketi, kurucu onayı 2026-10-27).
/// TÜM uçları hesap ister: cihaz satırı kullanıcıya bağlanır, çıkışta
/// kayıt düşürülür. Token URL'ye konmaz (uzun + ':' içerir) — hepsi gövdede.
class NotificationsApi {
  const NotificationsApi(this._dio);

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Cihaz kaydı/tazeleme — cihazın GÜNCEL tercihlerini döndürür.
  Future<NotificationPrefs> registerDevice({
    required String accessToken,
    required String token,
    required String platform,
    required String locale,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/notifications/devices',
        data: <String, dynamic>{
          'token': token,
          'platform': platform,
          'locale': locale,
        },
        options: _auth(accessToken),
      );
      return NotificationPrefs.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Kayıt silme (çıkışta çağrılır) — idempotent.
  Future<void> removeDevice({
    required String accessToken,
    required String token,
  }) async {
    try {
      await _dio.post<void>(
        '/v1/notifications/devices/remove',
        data: <String, dynamic>{'token': token},
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Tercih güncelleme — güncel tercihleri döndürür.
  Future<NotificationPrefs> updatePrefs({
    required String accessToken,
    required String token,
    bool? community,
    bool? events,
    bool? moderation,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/v1/notifications/devices/prefs',
        data: <String, dynamic>{
          'token': token,
          if (community != null) 'community': community,
          if (events != null) 'events': events,
          if (moderation != null) 'moderation': moderation,
        },
        options: _auth(accessToken),
      );
      return NotificationPrefs.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  // --- BİLDİRİM KUTUSU (SP-2 Döngü, 2026-10-31) ---

  /// Kutu listesi — en yeni 50 satır (metin istemcide üretilir).
  Future<List<InboxItem>> inbox({required String accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/notifications',
        options: _auth(accessToken),
      );
      final List<dynamic> raw =
          (res.data!['data'] as List<dynamic>?) ?? <dynamic>[];
      return raw
          .map((dynamic e) => InboxItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Kutu açılınca tümünü okundu işaretle (idempotent).
  Future<void> markAllRead({required String accessToken}) async {
    try {
      await _dio.post<void>(
        '/v1/notifications/read-all',
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
