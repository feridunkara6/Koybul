import 'package:dio/dio.dart';

import 'dto/feed_item.dart';
import 'problem_mapper.dart';

/// SEYİR PAYLAŞIMI + TAKİP AKIŞI istemcisi (SP-3b, kurucu onayı 2026-10-31).
///
/// TÜM uçlar hesap ister (misafir etkileşemez — kurucu kuralı). Paylaşım
/// yalnız YAPISAL veridir; "Konumum" başlangıcında [startName] null
/// GÖNDERİLİR (gizlilik: cihaz konumu adı/koordinatı sunucuya gitmez).
class TripsApi {
  const TripsApi(this._dio);

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Gerçekleşen seyri toplulukla paylaşır; sunucu kimliğini döndürür.
  Future<String> shareTrip({
    required String accessToken,
    String? startName,
    String? endName,
    required double distanceNm,
    int? durationMin,
    required int stopCount,
    required String sailedOn,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/trips/shared',
        data: <String, dynamic>{
          if (startName != null) 'startName': startName,
          if (endName != null) 'endName': endName,
          'distanceNm': distanceNm,
          if (durationMin != null) 'durationMin': durationMin,
          'stopCount': stopCount,
          'sailedOn': sailedOn,
        },
        options: _auth(accessToken),
      );
      return res.data!['id'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Sahibin paylaşımı kaldırması — anında yayından iner.
  Future<void> removeShared({
    required String accessToken,
    required String tripId,
  }) async {
    try {
      await _dio.delete<void>(
        '/v1/trips/shared/$tripId',
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// "Pruvan neta" ⚓ aç/kapat — güncel durumu ve sayacı döndürür.
  Future<({bool reacted, int pruvaCount})> togglePruva({
    required String accessToken,
    required String tripId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/trips/shared/$tripId/pruva',
        options: _auth(accessToken),
      );
      return (
        reacted: res.data!['reacted'] as bool,
        pruvaCount: (res.data!['pruvaCount'] as num).toInt(),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Takip akışı — takip edilenlerin seyir/not/rota kartları, en yeni önce.
  Future<List<FeedItem>> feed(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/feed',
        options: _auth(accessToken),
      );
      final List<dynamic> data =
          (res.data!['data'] as List<dynamic>?) ?? const <dynamic>[];
      return data
          .map((dynamic e) => FeedItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
