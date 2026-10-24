/// KULLANICI PROFİLİ veri sözleşmesi (Sosyalleşme Hafta 1A, kurucu onayı
/// 2026-10-24).
///
/// `GET/PATCH /v1/users/me` yanıtının istemcide kullanılan izdüşümü.
/// Sunucu daha fazla alan döndürür (settings, role, countryCode...);
/// burada YALNIZ profil düzenleme ekranının ihtiyacı taşınır — ihtiyaç
/// büyüyünce alan eklenir, önceden şişirilmez.
library;

/// Kaptanın kendi profili — tek doğruluk kaynağı sunucudur.
class UserProfileMe {
  const UserProfileMe({
    required this.id,
    required this.email,
    required this.displayName,
    required this.bio,
    required this.experienceYears,
  });

  final String id;
  final String? email;

  /// Toplulukta görünen ad (sunucu varsayılanı "Kaptan XXXX").
  final String displayName;

  /// Kısa tanıtım; hiç yazılmadıysa null.
  final String? bio;

  /// Denizcilik deneyimi (yıl); beyan edilmediyse null.
  final int? experienceYears;

  factory UserProfileMe.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> profile =
        (json['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return UserProfileMe(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: (profile['displayName'] as String?) ?? '',
      bio: profile['bio'] as String?,
      experienceYears: (profile['experienceYears'] as num?)?.toInt(),
    );
  }
}
