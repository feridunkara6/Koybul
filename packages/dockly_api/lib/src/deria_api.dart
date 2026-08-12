import 'package:dio/dio.dart';

import 'dto/deria.dart';
import 'problem_mapper.dart';

/// `/v1/deria/availability` istemcisi — anonim uç; hatalar `AppFailure`'a
/// eşlenir. Sunucu kaynağa ulaşamadığında BOŞ liste döner (5xx değil);
/// arayüz göstergeyi sessizce gizler.
class DeriaApi {
  const DeriaApi(this._dio);

  final Dio _dio;

  Future<DeriaAvailability> availability() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/deria/availability');
      return DeriaAvailability.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
