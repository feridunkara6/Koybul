import 'package:dio/dio.dart';

import 'dto/marina.dart';
import 'problem_mapper.dart';

/// `/v1/marina/*` istemcisi (Marina Topluluğu V1 — kurucu onayı 2026-10-23).
///
/// Topluluk okuma isteğe bağlı token taşır (sayılar herkese; liste erişim
/// kuralına tabi — kendi marinan ücretsiz, gezinti Premium; kilit SUNUCUDA).
/// Tekne kaydı hesap ister ama Premium İSTEMEZ (ağ etkisi kararı).
class MarinaApi {
  const MarinaApi(this._dio);

  final Dio _dio;

  Options? _maybeAuth(String? token) => token == null
      ? null
      : Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Kullanıcının sunucuya kayıtlı teknesi (yoksa boat=null).
  Future<MyMarinaBoat?> me(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/marina/me',
        options: _maybeAuth(accessToken),
      );
      final Map<String, dynamic>? boat = res.data!['boat'] as Map<String, dynamic>?;
      return boat == null ? null : MyMarinaBoat.fromJson(boat);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Tekneyi kaydet/güncelle + marinaya bağla (topluluğa katılım yolu).
  Future<MyMarinaBoat> upsertMyBoat({
    required String accessToken,
    required String name,
    required String boatTypeCode,
    required double lengthM,
    String? brand,
    String? model,
    int? buildYear,
    required String marinaLocationId,
    required bool visible,
    required bool shareSpecs,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/v1/marina/my-boat',
        data: <String, dynamic>{
          'name': name,
          'boatTypeCode': boatTypeCode,
          'lengthM': lengthM,
          'brand': brand,
          // Hafta 2 (Tekne Kartı): modele özel çizim için.
          'model': model,
          'buildYear': buildYear,
          'marinaLocationId': marinaLocationId,
          'visible': visible,
          'shareSpecs': shareSpecs,
        },
        options: _maybeAuth(accessToken),
      );
      return MyMarinaBoat.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Marina topluluğu: sayılar + (erişime göre) görünür tekne listesi.
  Future<MarinaCommunity> community(String locationId, {String? accessToken}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/marina/$locationId/community',
        options: _maybeAuth(accessToken),
      );
      return MarinaCommunity.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
