import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/profile_gateway.dart';

/// Gerçek sunucu ağ geçidi — marina geçidiyle aynı desen: yazma/okuma katı
/// (profil kişiseldir, token ŞART; misafire bu ekran hiç açılmaz).
class ApiProfileGateway implements ProfileGateway {
  ApiProfileGateway(this._api, this._tokenProvider);

  final UsersApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _requiredToken() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<UserProfileMe> me() async => _api.me(await _requiredToken());

  @override
  Future<UserProfileMe> update({
    String? displayName,
    String? bio,
    bool clearBio = false,
    int? experienceYears,
    bool clearExperience = false,
  }) async =>
      _api.updateProfile(
        accessToken: await _requiredToken(),
        displayName: displayName,
        bio: bio,
        clearBio: clearBio,
        experienceYears: experienceYears,
        clearExperience: clearExperience,
      );

  // --- TAKİP (SP-3a, kurucu onayı 2026-10-31) ---

  @override
  Future<List<FollowedCaptain>> following() async =>
      _api.following(await _requiredToken());

  @override
  Future<void> follow(String userId) async =>
      _api.follow(accessToken: await _requiredToken(), userId: userId);

  @override
  Future<void> unfollow(String userId) async =>
      _api.unfollow(accessToken: await _requiredToken(), userId: userId);
}
