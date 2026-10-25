import 'package:dio/dio.dart';

import 'dto/public_boat.dart';
import 'problem_mapper.dart';

/// `/v1/boats` istemcisi — şimdilik tek uç: TEKNE KARTI (Sosyalleşme
/// Hafta 2, kurucu onayı 2026-10-24). Tekne CRUD'u mobilde kullanılmıyor
/// (tekne profili cihazda yaşar; sunucuya marina katılımıyla gider) —
/// ihtiyaç doğunca eklenir, önceden şişirilmez.
class BoatsApi {
  const BoatsApi(this._dio);

  final Dio _dio;

  /// Tekne Kartı — kimlik İSTEMEZ. Görünmeyen/silinmiş/bilinmeyen tekne
  /// `not-found` fırlatır (sunucu ayrım sızdırmaz).
  Future<PublicBoatCard> publicCard(String boatId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/boats/$boatId/public',
      );
      return PublicBoatCard.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
