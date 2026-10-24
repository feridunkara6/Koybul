import 'package:dockly_api/dockly_api.dart' show UserProfileMe;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../community/application/reputation_controller.dart';
import '../data/api_profile_gateway.dart';
import '../domain/profile_gateway.dart';

/// PROFİL DÜZENLEME orkestrasyonu (Sosyalleşme Hafta 1A, kurucu onayı
/// 2026-10-24).
///
/// Sunucudaki GET/PATCH /users/me uçları hazırdı; eksik olan istemciydi.
/// Görünen ad toplulukta (not/soru/cevap yazarlarında) göründüğü için
/// kayıttan sonra İTİBAR ÖZETİ de tazelenir — iki ekranda iki farklı ad
/// görünmesin (0-uydurma kuralının kardeşi: 0-bayat kuralı).

final Provider<ProfileGateway> profileGatewayProvider = Provider<ProfileGateway>((ref) {
  return ApiProfileGateway(
    ref.watch(usersApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Kendi profilim — düzenleme ekranının doğruluk kaynağı.
/// autoDispose: ekrandan çıkınca salınır; kayıt sonrası invalidate edilir.
final AutoDisposeFutureProvider<UserProfileMe> myProfileProvider =
    FutureProvider.autoDispose<UserProfileMe>((ref) {
  return ref.watch(profileGatewayProvider).me();
});

/// Kaydedici — widget'tan `ref.read(profileSaverProvider).save(...)` ile
/// çağrılır. Hata fırlatır; ekran yakalayıp kullanıcıya söyler (sessiz
/// yutma yok).
final Provider<ProfileSaver> profileSaverProvider =
    Provider<ProfileSaver>((ref) => ProfileSaver(ref));

class ProfileSaver {
  const ProfileSaver(this._ref);

  final Ref _ref;

  Future<UserProfileMe> save({
    String? displayName,
    String? bio,
    bool clearBio = false,
    int? experienceYears,
    bool clearExperience = false,
  }) async {
    final UserProfileMe updated = await _ref.read(profileGatewayProvider).update(
          displayName: displayName,
          bio: bio,
          clearBio: clearBio,
          experienceYears: experienceYears,
          clearExperience: clearExperience,
        );
    _ref.invalidate(myProfileProvider);
    // Denizci kartı adı itibar özetinden okur — birlikte tazelenir.
    _ref.invalidate(reputationSummaryProvider);
    return updated;
  }
}
