import 'package:dio/dio.dart';

import 'dto/premium.dart';
import 'problem_mapper.dart';

/// `/v1/premium/*` istemcisi (P3, kurucu onayı 2026-09-21).
///
/// İKİ uç, ikisi de HESAP ister (premium hesaba bağlıdır):
/// - `me`: abonelik + keşif hakkı durumu (Profil/paket ekranının tek kaynağı).
/// - `linkApple`: satın alma / geri yükleme sonrası mağaza işlem kimliğini
///   hesaba bağlar. Sunucu durumu APPLE'DAN doğrular — istemci beyanına
///   güvenilmez; buradan yalnız işlem kimliği gider.
class PremiumApi {
  const PremiumApi(this._dio);

  final Dio _dio;

  Future<PremiumMe> me(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/premium/me',
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      return PremiumMe.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<PremiumLinkResult> linkApple({
    required String accessToken,
    required String transactionId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/premium/apple/link',
        data: <String, dynamic>{'originalTransactionId': transactionId},
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      return PremiumLinkResult.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
