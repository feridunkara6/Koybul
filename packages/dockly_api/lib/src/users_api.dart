import 'package:dio/dio.dart';

import 'dto/public_captain.dart';
import 'dto/user_me.dart';
import 'problem_mapper.dart';

/// `/v1/users/me` istemcisi.
///
/// V1'de tek uç vardı: HESAP SİLME (Apple/Google zorunluluğu + KVKK md. 11).
/// Sosyalleşme Hafta 1A (kurucu onayı 2026-10-24) ile profil OKUMA ve
/// DÜZENLEME eklendi — sunucu uçları zaten hazırdı (GET/PATCH /users/me),
/// istemci ucu yoktu; "kimlik → keşif → geri çağırma" zincirinin ilk halkası.
class UsersApi {
  const UsersApi(this._dio);

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'});

  /// Kaptanın kendi profili (görünen ad, bio, deneyim yılı).
  Future<UserProfileMe> me(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/users/me',
        options: _auth(accessToken),
      );
      return UserProfileMe.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Profil düzenleme — sunucunun beyaz listesine birebir uyar (yalnız
  /// profile.* alanları; rol/e-posta gibi alanlar istemciden ASLA gitmez).
  ///
  /// `bio` ve `experienceYears` null GÖNDERİLEBİLİR (alanı temizler);
  /// `clearBio`/`clearExperience` bu niyeti açık yazdırır — "parametre
  /// verilmedi" ile "null yap" karışmasın diye.
  Future<UserProfileMe> updateProfile({
    required String accessToken,
    String? displayName,
    String? bio,
    bool clearBio = false,
    int? experienceYears,
    bool clearExperience = false,
  }) async {
    final Map<String, dynamic> profile = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (bio != null || clearBio) 'bio': bio,
      if (experienceYears != null || clearExperience)
        'experienceYears': experienceYears,
    };
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/v1/users/me',
        data: <String, dynamic>{'profile': profile},
        options: _auth(accessToken),
      );
      return UserProfileMe.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Herkese açık kaptan kartı (Hafta 1B) — kimlik İSTEMEZ; S-C akışı gibi
  /// anonim de okunur. Bilinmeyen/silinmiş kullanıcıda `not-found` fırlar.
  Future<PublicCaptain> publicProfile(String userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/users/$userId/public',
      );
      return PublicCaptain.fromJson(res.data!);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Hesabı siler. Sunucu kimlik alanlarını anonimleştirir ve tüm
  /// oturumları sonlandırır; 204 döner. Hesap yoksa `not-found` gelir.
  Future<void> deleteMe(String accessToken) async {
    try {
      await _dio.delete<void>(
        '/v1/users/me',
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
