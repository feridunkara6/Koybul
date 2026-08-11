import 'package:dio/dio.dart';

import 'problem_mapper.dart';

/// `/v1/users/me` istemcisi.
///
/// Şimdilik tek uç: HESAP SİLME. Apple ve Google, hesap açtıran her
/// uygulamadan uygulama İÇİNDE silme yolu ister; KVKK'nın 11. maddesi de
/// silme hakkını tanır. Sunucu tarafı zaten vardı, istemci ucu yoktu —
/// yani hak kâğıt üzerinde kalıyordu (Faz 0 denetim bulgusu).
class UsersApi {
  const UsersApi(this._dio);

  final Dio _dio;

  /// Hesabı siler. Sunucu kimlik alanlarını anonimleştirir ve tüm
  /// oturumları sonlandırır; 204 döner. Hesap yoksa `not-found` gelir.
  Future<void> deleteMe(String accessToken) async {
    try {
      await _dio.delete<void>(
        '/v1/users/me',
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
        ),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
