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

  /// Etkinlik oluşturur (yalnız admin+; yetki sunucuda).
  Future<String> createEvent({
    required String accessToken,
    required AdminEventInput input,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/events',
        data: input.toJson(),
        options: _auth(accessToken),
      );
      return res.data!['id'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Etkinliği iptal eder — kayıtlılar uygulamada iptal şeridini görür (V1).
  Future<void> cancelEvent({
    required String accessToken,
    required String eventId,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/v1/admin/events/$eventId',
        data: <String, dynamic>{'status': 'cancelled'},
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<List<EventParticipantView>> participants({
    required String accessToken,
    required String eventId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/admin/events/$eventId/participants',
        options: _auth(accessToken),
      );
      return (res.data!['participants'] as List<dynamic>)
          .map((dynamic e) => EventParticipantView.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Future<String> createDeal({
    required String accessToken,
    required AdminDealInput input,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/deals',
        data: input.toJson(),
        options: _auth(accessToken),
      );
      return res.data!['id'] as String;
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Fırsatı aç/kapat (pasif fırsat listeden düşer).
  Future<void> setDealActive({
    required String accessToken,
    required String dealId,
    required bool isActive,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/v1/admin/deals/$dealId',
        data: <String, dynamic>{'isActive': isActive},
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// İÇERİK YÖNETİMİ (2026-10-27): tür başına en yeni içerikler.
  Future<List<AdminContentItem>> listContent({
    required String accessToken,
    required String type,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/admin/content',
        queryParameters: <String, dynamic>{'type': type, 'limit': limit},
        options: _auth(accessToken),
      );
      return (res.data!['data'] as List<dynamic>)
          .map((dynamic e) => AdminContentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Yayından indirme (yumuşak silme) — veri denetim için sunucuda durur.
  Future<void> deleteContent({
    required String accessToken,
    required String type,
    required String id,
  }) async {
    try {
      await _dio.delete<void>(
        '/v1/admin/content/$type/$id',
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
