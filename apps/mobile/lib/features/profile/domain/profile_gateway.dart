import 'package:dockly_api/dockly_api.dart' show UserProfileMe;

/// Profil ağ geçidi sözleşmesi (Sosyalleşme Hafta 1A, kurucu onayı 2026-10-24).
///
/// Kaptanın kendi profili SUNUCUDA durur (tek doğruluk kaynağı); bu arayüz
/// testte sahteyle değiştirilebilsin diye soyuttur (marina ile aynı desen).
abstract interface class ProfileGateway {
  /// Kendi profilim — oturum şart.
  Future<UserProfileMe> me();

  /// Profil düzenleme: yalnız verilen alanlar değişir.
  /// [clearBio]/[clearExperience] alanı bilerek boşaltır.
  Future<UserProfileMe> update({
    String? displayName,
    String? bio,
    bool clearBio,
    int? experienceYears,
    bool clearExperience,
  });
}
