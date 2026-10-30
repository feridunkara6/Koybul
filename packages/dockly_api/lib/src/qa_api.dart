import 'package:dio/dio.dart';

import 'dto/qa.dart';
import 'problem_mapper.dart';

/// `/v1/qa/*` istemcisi (Blog V1 — kurucu onayı 2026-10-23).
///
/// Akış herkese açıktır (token istemez). Detay isteğe bağlı token taşır:
/// token'lı istekte sunucu "sahibi mi / premium mu" kararını verebilir.
/// Yazma uçları HESAP ister; Premium kapısı SUNUCUDADIR — ücretsiz üyenin
/// yazma denemesi 403 `premium-required` döner ve istemci paywall gösterir.
class QaApi {
  const QaApi(this._dio);

  final Dio _dio;

  Options? _maybeAuth(String? token) => token == null
      ? null
      : Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Ana akış: öne çıkan şeridi + kronolojik liste (herkese açık).
  /// Akış — SAYFALI (2026-10-30): [page] 1 tabanlı; [query] anahtar kelime
  /// araması (başlık + gövde). Eski `before` imleci kaldırıldı.
  Future<QaFeed> feed({
    String? category,
    String? query,
    int? page,
    int? limit,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/qa/questions',
        queryParameters: <String, dynamic>{
          if (category != null) 'category': category,
          if (query != null && query.trim().length >= 2) 'q': query.trim(),
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
        },
      );
      return QaFeed.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Detay — erişim kararı sunucudan gelir (full/teaser).
  Future<QaDetail> detail(String questionId, {String? accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/qa/questions/$questionId',
        options: _maybeAuth(accessToken),
      );
      return QaDetail.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<QaCreateResult> createQuestion({
    required String accessToken,
    required String category,
    required String title,
    required String body,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/qa/questions',
        data: <String, dynamic>{'category': category, 'title': title, 'body': body},
        options: _maybeAuth(accessToken),
      );
      return QaCreateResult.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<QaCreateResult> createAnswer({
    required String accessToken,
    required String questionId,
    required String body,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/qa/questions/$questionId/answers',
        data: <String, dynamic>{'body': body},
        options: _maybeAuth(accessToken),
      );
      return QaCreateResult.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Soru beğenisi (aç/kapa) — dönen sayaç ekrana yazılır.
  Future<({bool liked, int likeCount})> toggleLike({
    required String accessToken,
    required String questionId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/qa/questions/$questionId/like',
        options: _maybeAuth(accessToken),
      );
      return (liked: res.data!['liked'] as bool, likeCount: res.data!['likeCount'] as int);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// "Faydalı" işareti (aç/kapa).
  Future<({bool helped, int helpfulCount})> toggleHelpful({
    required String accessToken,
    required String answerId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/qa/answers/$answerId/helpful',
        options: _maybeAuth(accessToken),
      );
      return (
        helped: res.data!['helped'] as bool,
        helpfulCount: res.data!['helpfulCount'] as int,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// ⚑ Uygunsuz içerik bildirimi — Premium ŞARTI YOK (Apple UGC beklentisi).
  Future<void> report({
    required String accessToken,
    required String entity, // 'question' | 'answer'
    required String id,
  }) async {
    try {
      final String path = entity == 'answer'
          ? '/v1/qa/answers/$id/report'
          : '/v1/qa/questions/$id/report';
      await _dio.post<void>(path, options: _maybeAuth(accessToken));
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
