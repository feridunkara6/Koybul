import 'package:dockly_api/dockly_api.dart' show BlockedUser;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/profile_gateway.dart';
import 'follow_controller.dart';
import 'profile_controller.dart';

/// ENGELLEME orkestrasyonu (ENG-1, kurucu onayı 2026-11-03).
///
/// Engelleme SESSİZDİR: karşı tarafa bildirim gitmez, engellendiğini görmez
/// (profilimiz ona normal görünür; yalnız takip edemez — sunucu kapısı).
/// İçerik gizleme İSTEMCİDEDİR: listeler [blockedIdsProvider]'ı izleyip
/// yazarı engellenmiş satırları süzer — engel değişince kendiliğinden tazelenir.

/// Engellediklerim — misafir/oturumsuz: boş liste (sunucuya hiç gidilmez).
final blockedUsersProvider =
    FutureProvider.autoDispose<List<BlockedUser>>((ref) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <BlockedUser>[];
  return ref.watch(profileGatewayProvider).blocks();
});

/// Engellenen kimlik kümesi — liste süzgeçlerinin O(1) bakışı. Liste
/// yüklenemediyse boş küme (içerik gizlenmez; dürüst düşüş — uydurma yok).
final blockedIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  return ref.watch(blockedUsersProvider).maybeWhen(
        data: (List<BlockedUser> list) =>
            list.map((BlockedUser b) => b.id).toSet(),
        orElse: () => const <String>{},
      );
});

/// Eylemler — widget'tan `ref.read(blockActionsProvider)` ile çağrılır.
/// Hata fırlatır; ekran yakalayıp söyler (sessiz yutma yok).
final Provider<BlockActions> blockActionsProvider =
    Provider<BlockActions>((ref) => BlockActions(ref));

class BlockActions {
  const BlockActions(this._ref);

  final Ref _ref;

  /// [blocked] true → engelle; false → kaldır. Başarıda engel listem,
  /// takip listelerim ve kişinin kartı tazelenir (takip bağları düştü).
  Future<void> setBlocked(String userId, {required bool blocked}) async {
    final ProfileGateway gw = _ref.read(profileGatewayProvider);
    if (blocked) {
      await gw.block(userId);
    } else {
      await gw.unblock(userId);
    }
    _ref.invalidate(blockedUsersProvider);
    _ref.invalidate(followingProvider);
    _ref.invalidate(captainFollowersProvider);
    _ref.invalidate(captainFollowingProvider);
    _ref.invalidate(publicCaptainProvider(userId));
  }
}
