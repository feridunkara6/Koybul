import 'package:dio/dio.dart';

import 'dto/community.dart';
import 'dto/geo.dart';
import 'problem_mapper.dart';

/// Topluluk istemcisi: Kaptan Notları, yorum yazma, şikâyet.
///
/// Okuma uçları anonimdir (misafir her şeyi okur); yazma uçları access token
/// ister — sunucu misafire `guest-not-allowed` (403) döner.
class CommunityApi {
  const CommunityApi(this._dio);

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Bir noktanın onaylı notları. Uyarılar listenin başında gelir.
  Future<List<Note>> notesForLocation(String locationId, {NoteKind? kind, int limit = 20}) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/locations/$locationId/notes',
        queryParameters: <String, dynamic>{
          if (kind != null) 'kind': kind.wire,
          'limit': limit,
        },
      );
      return _list(res.data!, Note.fromJson);
    });
  }

  /// "Yakında paylaşılanlar" — konum + tazelik penceresi.
  Future<List<NearbyNote>> nearbyNotes({
    required GeoPoint position,
    double radiusNm = 50,
    int sinceHours = 48,
    int limit = 20,
  }) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/notes/nearby',
        queryParameters: <String, dynamic>{
          'lat': position.lat,
          'lon': position.lon,
          'radiusNm': radiusNm,
          'sinceHours': sinceHours,
          'limit': limit,
        },
      );
      return _list(res.data!, NearbyNote.fromJson);
    });
  }

  /// Kendi katkılarım (durum süzgeciyle) — "Katkılarım" ekranının kaynağı.
  Future<List<Note>> myNotes({required String accessToken, String? status}) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/users/me/notes',
        queryParameters: <String, dynamic>{if (status != null) 'status': status},
        options: _auth(accessToken),
      );
      return _list(res.data!, Note.fromJson);
    });
  }

  /// Not bırak. `position` yalnız status/hazard için zorunludur (sunucu denetler).
  Future<Note> createNote({
    required String locationId,
    required NoteKind kind,
    required String body,
    required String observedOn,
    required String accessToken,
    String? title,
    String? boatId,
    GeoPoint? position,
    NoteWind? wind,
  }) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.post<Map<String, dynamic>>(
        '/v1/locations/$locationId/notes',
        data: <String, dynamic>{
          'kind': kind.wire,
          'body': body,
          'observedOn': observedOn,
          if (title != null && title.isNotEmpty) 'title': title,
          if (boatId != null) 'boatId': boatId,
          if (position != null)
            'position': <String, dynamic>{'lat': position.lat, 'lon': position.lon},
          if (wind != null) 'wind': wind.toJson(),
        },
        options: _auth(accessToken),
      );
      return Note.fromJson(res.data!);
    });
  }

  Future<void> deleteNote({required String noteId, required String accessToken}) async {
    return _call(() async {
      await _dio.delete<void>('/v1/notes/$noteId', options: _auth(accessToken));
    });
  }

  /// 'helpful' | 'confirm' | 'dispute'. Kendi notuna oy 403 döner.
  Future<NoteCounts> reactToNote({
    required String noteId,
    required String reaction,
    required String accessToken,
  }) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.post<Map<String, dynamic>>(
        '/v1/notes/$noteId/reactions',
        data: <String, dynamic>{'reaction': reaction},
        options: _auth(accessToken),
      );
      return NoteCounts.fromJson(res.data!);
    });
  }

  /// Yorum yaz. Lokasyon başına tek aktif yorum — ikincisi 409 döner.
  Future<String> createReview({
    required String idOrSlug,
    required int overallRating,
    required String accessToken,
    String? body,
    String? visitedOn,
    Map<String, int>? dimensions,
  }) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.post<Map<String, dynamic>>(
        '/v1/locations/$idOrSlug/reviews',
        data: <String, dynamic>{
          'overallRating': overallRating,
          if (body != null && body.isNotEmpty) 'body': body,
          if (visitedOn != null) 'visitedOn': visitedOn,
          if (dimensions != null && dimensions.isNotEmpty) 'dimensions': dimensions,
        },
        options: _auth(accessToken),
      );
      return res.data!['id'] as String;
    });
  }

  Future<int> reactToReview({required String reviewId, required String accessToken}) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.post<Map<String, dynamic>>(
        '/v1/reviews/$reviewId/reactions',
        options: _auth(accessToken),
      );
      return (res.data!['helpfulCount'] as num).toInt();
    });
  }

  /// Hatalı bilgi ya da içerik şikâyeti.
  Future<void> report({
    required String idOrSlug,
    required String reason,
    required String accessToken,
    String? message,
    String? targetType,
    String? targetId,
  }) async {
    return _call(() async {
      await _dio.post<Map<String, dynamic>>(
        '/v1/locations/$idOrSlug/reports',
        data: <String, dynamic>{
          'reason': reason,
          if (message != null && message.isNotEmpty) 'message': message,
          if (targetType != null) 'targetType': targetType,
          if (targetId != null) 'targetId': targetId,
        },
        options: _auth(accessToken),
      );
    });
  }

  List<T> _list<T>(Map<String, dynamic> body, T Function(Map<String, dynamic>) from) {
    final List<dynamic> raw = (body['data'] as List<dynamic>?) ?? <dynamic>[];
    return raw.map((dynamic e) => from(e as Map<String, dynamic>)).toList(growable: false);
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
