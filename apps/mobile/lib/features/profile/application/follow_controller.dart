import 'package:dockly_api/dockly_api.dart' show FollowedCaptain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/profile_gateway.dart';
import 'profile_controller.dart';

/// TAKİP orkestrasyonu (SP-3a, kurucu onayı 2026-10-31).
///
/// "Kaptanı takip et" bir İÇERİK ABONELİĞİDİR: karşılıklı onay istemez,
/// mesajlaşma hakkı vermez (sosyalleşme raporu §4A). Misafir kullanıcı
/// takip EDEMEZ (kurucu kuralı: hesapsız kullanıcı diğer kullanıcılarla
/// etkileşime geçemez) — düğme hesaba davet eder, liste boş döner.

/// Takip ettiklerim — en yeni takip önce. Misafir/oturumsuz: boş liste
/// (sunucuya hiç gidilmez; 403 turu yok).
/// NOT: sağ taraf tür BİLEREK değişkende tekrarlanmaz — CI dersi
/// (invalid_assignment, inbox_controller ile aynı desen).
final followingProvider =
    FutureProvider.autoDispose<List<FollowedCaptain>>((ref) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <FollowedCaptain>[];
  return ref.watch(profileGatewayProvider).following();
});

/// Takip edilen kimlik kümesi — kaptan kartındaki düğme durumuna O(1) bakış.
/// Liste yüklenemediyse/boşsa boş küme (düğme "Takip et" görünür; eylem
/// idempotent olduğundan ikinci takip zararsızdır).
final followedIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  return ref.watch(followingProvider).maybeWhen(
        data: (List<FollowedCaptain> list) =>
            list.map((FollowedCaptain f) => f.id).toSet(),
        orElse: () => const <String>{},
      );
});

/// TAKİPÇİ/TAKİP LİSTELERİ (PR-1 profil düzeni, kurucu onayı 2026-11-03).
/// Kurucu kuralı: listeler yalnız GİRİŞ YAPMIŞ ÜYEYE açıktır — misafir
/// sayaçları görür; buraya hiç gelinmez (ekran kapının arkasında).
/// Oturum yoksa sunucuya gidilmez, boş liste döner.
final captainFollowersProvider = FutureProvider.autoDispose
    .family<List<FollowedCaptain>, String>((ref, String userId) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <FollowedCaptain>[];
  return ref.watch(profileGatewayProvider).followersOf(userId);
});

final captainFollowingProvider = FutureProvider.autoDispose
    .family<List<FollowedCaptain>, String>((ref, String userId) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <FollowedCaptain>[];
  return ref.watch(profileGatewayProvider).followingOf(userId);
});

/// Eylemler — widget'tan `ref.read(followActionsProvider)` ile çağrılır.
/// Hata fırlatır; ekran yakalayıp söyler (sessiz yutma yok).
final Provider<FollowActions> followActionsProvider =
    Provider<FollowActions>((ref) => FollowActions(ref));

class FollowActions {
  const FollowActions(this._ref);

  final Ref _ref;

  /// [follow] true → takip et; false → bırak. Başarıda hem listem hem
  /// kaptanın kartı (takipçi sayısı) tazelenir — 0-bayat kuralı.
  Future<void> setFollowing(String userId, {required bool follow}) async {
    final ProfileGateway gw = _ref.read(profileGatewayProvider);
    if (follow) {
      await gw.follow(userId);
    } else {
      await gw.unfollow(userId);
    }
    _ref.invalidate(followingProvider);
    _ref.invalidate(publicCaptainProvider(userId));
    // PR-1: açık liste ekranları da tazelensin (takipçi sayısı/satırı değişti).
    _ref.invalidate(captainFollowersProvider);
    _ref.invalidate(captainFollowingProvider);
  }
}
