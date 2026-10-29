import 'package:dio/dio.dart';

import 'dto/events.dart';
import 'problem_mapper.dart';

/// `/v1/events*` istemcisi (Etkinlikler & Fırsatlar V1 — kurucu onayı
/// 2026-10-23). Liste/detay isteğe bağlı token taşır (kitle kilitleri ve
/// "kayıtlı mıyım" bilgisi için); kayıt/iptal hesap ister.
class EventsApi {
  const EventsApi(this._dio);

  final Dio _dio;

  Options? _maybeAuth(String? token) => token == null
      ? null
      : Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  Future<List<DealView>> deals({String? accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/events/deals',
        options: _maybeAuth(accessToken),
      );
      return (res.data!['deals'] as List<dynamic>)
          .map((dynamic e) => DealView.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<EventView>> events({String? accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/events',
        options: _maybeAuth(accessToken),
      );
      return (res.data!['events'] as List<dynamic>)
          .map((dynamic e) => EventView.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<EventView> event(String eventId, {String? accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/events/$eventId',
        options: _maybeAuth(accessToken),
      );
      return EventView.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Kayıt — kontenjan kararı SUNUCUNUN; dolu etkinlikte 403 döner.
  /// [showName]: RIZALI katılımcı listesi (SP-4) — adım görünsün mü?
  Future<({bool registered, int remaining})> register({
    required String accessToken,
    required String eventId,
    bool showName = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/events/$eventId/register',
        data: <String, dynamic>{'showName': showName},
        options: _maybeAuth(accessToken),
      );
      return (
        registered: res.data!['registered'] as bool,
        remaining: res.data!['remaining'] as int,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<void> cancel({required String accessToken, required String eventId}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/events/$eventId/cancel',
        options: _maybeAuth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  // --- KULLANICI ETKİNLİKLERİ (SP-4, kurucu onayı 2026-10-31) ---

  /// Etkinlik kurma — Premium kapısı SUNUCUDA (402 premium-required).
  /// 'pending' doğar; moderasyon onayıyla yayınlanır.
  Future<String> createEvent({
    required String accessToken,
    required String template,
    required String title,
    required String body,
    required DateTime startsAt,
    DateTime? endsAt,
    required String locationText,
    required int quota,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/events',
        data: <String, dynamic>{
          'template': template,
          'title': title,
          'body': body,
          'startsAt': startsAt.toUtc().toIso8601String(),
          if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
          'locationText': locationText,
          'quota': quota,
        },
        options: _maybeAuth(accessToken),
      );
      return res.data!['id'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Kurucunun kendi etkinliğini iptali — kayıtlılara duyurulur.
  Future<void> cancelOwnEvent({
    required String accessToken,
    required String eventId,
  }) async {
    try {
      await _dio.delete<void>(
        '/v1/events/$eventId',
        options: _maybeAuth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// RIZALI katılımcı listesi — hesap ister; yalnız izin verenler gelir.
  Future<List<EventAttendee>> attendees({
    required String accessToken,
    required String eventId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/events/$eventId/attendees',
        options: _maybeAuth(accessToken),
      );
      final List<dynamic> data =
          (res.data!['attendees'] as List<dynamic>?) ?? const <dynamic>[];
      return data
          .map((dynamic e) => EventAttendee.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
