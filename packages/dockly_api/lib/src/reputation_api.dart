import 'package:dio/dio.dart';

import 'dto/reputation.dart';
import 'problem_mapper.dart';

/// Denizci profili ve moderasyon istemcisi.
///
/// BURADAKİ HER UÇ HESAP İSTER — misafirde çağrılmamalıdır (sunucu
/// `guest-not-allowed` 403 döner). Moderasyon uçları ayrıca `moderator`
/// rolü ister; rolü olmayan `forbidden` alır ve ekran hiç açılmaz.
class ReputationApi {
  const ReputationApi(this._dio);

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  Future<ReputationSummary> summary(String accessToken) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/users/me/summary',
        options: _auth(accessToken),
      );
      return ReputationSummary.fromJson(res.data!);
    });
  }

  Future<List<ContributionItem>> contributions(String accessToken, {int limit = 50}) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/users/me/contributions',
        queryParameters: <String, dynamic>{'limit': limit},
        options: _auth(accessToken),
      );
      return _list(res.data!, ContributionItem.fromJson);
    });
  }

  /// Bekleyen içerik sayıları — tür başına. Rozet şeridini besler.
  Future<Map<String, int>> moderationCounts(String accessToken) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/moderation/counts',
        options: _auth(accessToken),
      );
      return <String, int>{
        for (final MapEntry<String, dynamic> e in (res.data ?? const <String, dynamic>{}).entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      };
    });
  }

  Future<List<ModerationItem>> moderationQueue(
    String accessToken, {
    String? entityType,
    int limit = 20,
  }) async {
    return _call(() async {
      final Response<Map<String, dynamic>> res = await _dio.get<Map<String, dynamic>>(
        '/v1/moderation/queue',
        queryParameters: <String, dynamic>{
          if (entityType != null) 'entityType': entityType,
          'limit': limit,
        },
        options: _auth(accessToken),
      );
      return _list(res.data!, ModerationItem.fromJson);
    });
  }

  /// Karar ver. Reddin sebebi ZORUNLUDUR (sunucu sebepsiz reddi kabul etmez).
  Future<void> decide({
    required String taskId,
    required bool approve,
    required String accessToken,
    String? reason,
  }) async {
    return _call(() async {
      await _dio.post<Map<String, dynamic>>(
        '/v1/moderation/$taskId/decision',
        data: <String, dynamic>{
          'decision': approve ? 'approve' : 'reject',
          if (!approve && reason != null) 'reason': reason,
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
