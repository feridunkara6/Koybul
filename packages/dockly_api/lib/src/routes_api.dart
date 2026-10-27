import 'package:dio/dio.dart';

import 'dto/routes.dart';
import 'problem_mapper.dart';

/// `/v1/routes` istemcisi (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24).
/// Okuma herkese açık; detayda kimlik gönderilirse savedByMe/doneByMe dolar.
/// Yazma hesap ister; moderasyon ve aylık tavan kararları SUNUCUDADIR.
class RoutesApi {
  const RoutesApi(this._dio);

  final Dio _dio;

  Options? _maybeAuth(String? token) => token == null
      ? null
      : Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Keşif listesi — onaylı rotalar + (kimlik gönderilirse) bakanın KENDİ
  /// bekleyen rotaları başta, 'pending' durumuyla (saha isteği 2026-10-27).
  Future<List<SharedRouteSummary>> list({
    String sort = 'new',
    String? locationId,
    int limit = 20,
    String? accessToken,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/routes',
        queryParameters: <String, dynamic>{
          'sort': sort,
          if (locationId != null) 'locationId': locationId,
          'limit': limit,
        },
        options: _maybeAuth(accessToken),
      );
      return (res.data!['data'] as List<dynamic>)
          .map((dynamic e) => SharedRouteSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<SharedRouteDetail> detail(String routeId, {String? accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/routes/$routeId',
        options: _maybeAuth(accessToken),
      );
      return SharedRouteDetail.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Rota paylaşma — PENDING döner (moderasyon onayı beklenir).
  Future<({String id, String status})> create({
    required String accessToken,
    required String name,
    required String body,
    String? season,
    String? boatSuggestion,
    required double distanceNm,
    double? durationHours,
    required List<String> stopLocationIds,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/routes',
        data: <String, dynamic>{
          'name': name,
          'body': body,
          if (season != null) 'season': season,
          if (boatSuggestion != null) 'boatSuggestion': boatSuggestion,
          'distanceNm': distanceNm,
          if (durationHours != null) 'durationHours': durationHours,
          'stopLocationIds': stopLocationIds,
        },
        options: _maybeAuth(accessToken),
      );
      return (
        id: res.data!['id'] as String,
        status: res.data!['status'] as String,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<({bool saved, int saveCount})> toggleSave({
    required String accessToken,
    required String routeId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/routes/$routeId/save',
        options: _maybeAuth(accessToken),
      );
      return (
        saved: res.data!['saved'] as bool,
        saveCount: res.data!['saveCount'] as int,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<({bool done, int doneCount})> toggleDone({
    required String accessToken,
    required String routeId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/routes/$routeId/done',
        options: _maybeAuth(accessToken),
      );
      return (
        done: res.data!['done'] as bool,
        doneCount: res.data!['doneCount'] as int,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Sahibin silmesi — paylaşım anında yayından iner.
  Future<void> remove({required String accessToken, required String routeId}) async {
    try {
      await _dio.delete<void>(
        '/v1/routes/$routeId',
        options: _maybeAuth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
