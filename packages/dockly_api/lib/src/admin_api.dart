import 'package:dio/dio.dart';

import 'dto/admin.dart';
import 'problem_mapper.dart';

/// `/v1/admin/*` istemcisi (YÖNETİM PANELİ, kurucu talebi 2026-09-25).
///
/// İki uç, ikisi de HESAP + asgari 'admin' rolü ister; yetki denetimi
/// SUNUCUDADIR (RolesGuard) — istemcideki görünürlük yalnız kolaylıktır.
class AdminApi {
  const AdminApi(this._dio);

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Panel sayıları: kullanıcı/premium/moderasyon/yorum-not toplamları.
  Future<AdminStats> stats(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/admin/stats',
        options: _auth(accessToken),
      );
      return AdminStats.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// E-postayla elle premium tanımlar ([months] ay). Hesap bulunamazsa
  /// sunucu `not-found` döner — panel bunu dürüst mesajla gösterir.
  Future<AdminPremiumGrant> grantPremium({
    required String accessToken,
    required String email,
    required int months,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/premium',
        data: <String, dynamic>{'email': email, 'months': months},
        options: _auth(accessToken),
      );
      return AdminPremiumGrant.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
