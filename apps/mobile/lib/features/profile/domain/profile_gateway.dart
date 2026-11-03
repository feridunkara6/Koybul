import 'package:dockly_api/dockly_api.dart'
    show BlockedUser, FollowedCaptain, UserProfileMe;

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

  // --- TAKİP (SP-3a, kurucu onayı 2026-10-31) ---

  /// Takip ettiklerim — en yeni takip önce; oturum şart.
  Future<List<FollowedCaptain>> following();

  /// Kaptanı takip et — idempotent.
  Future<void> follow(String userId);

  /// Takibi bırak — idempotent.
  Future<void> unfollow(String userId);

  // --- TAKİPÇİ/TAKİP LİSTELERİ (PR-1 profil düzeni, 2026-11-03) ---

  /// Bir kaptanın takipçileri — kurucu kuralı: üyelik şart.
  Future<List<FollowedCaptain>> followersOf(String userId);

  /// Bir kaptanın takip ettikleri — üyelik şart.
  Future<List<FollowedCaptain>> followingOf(String userId);

  // --- ENGELLEME (ENG-1, kurucu onayı 2026-11-03) ---

  /// Engellediklerim — yalnız bana iner.
  Future<List<BlockedUser>> blocks();

  /// Kullanıcıyı engelle — sessiz, idempotent.
  Future<void> block(String userId);

  /// Engeli kaldır — idempotent.
  Future<void> unblock(String userId);
}
