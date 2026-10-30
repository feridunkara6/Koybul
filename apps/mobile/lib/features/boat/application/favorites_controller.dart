import 'package:dockly_api/dockly_api.dart' show FavoriteBoatRef;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/api_favorites_gateway.dart';
import '../domain/favorites_gateway.dart';
import 'boat_card_controller.dart';

/// FAVORİLE orkestrasyonu (TK-5, kurucu onayı 2026-10-30).
///
/// "Favorile" SESSİZ bir beğenidir: tekne sahibine bildirim gitmez, kimin
/// favorilediği listelenmez — kartta yalnız toplam sayı görünür. Misafir
/// favorileyemez (kurucu kuralı: hesapsız kullanıcı etkileşime geçemez);
/// kalp hesaba davet eder. Takip (SP-3a) ile aynı desen.

final Provider<FavoritesGateway> favoritesGatewayProvider =
    Provider<FavoritesGateway>(
  (ref) => ApiFavoritesGateway(ref.watch(boatsApiProvider)),
);

/// Favori teknelerim — misafir/oturumsuz: boş liste (sunucuya hiç gidilmez).
/// NOT: sağ taraf tür değişkende tekrarlanmaz — CI dersi (invalid_assignment).
final favoriteBoatsProvider =
    FutureProvider.autoDispose<List<FavoriteBoatRef>>((ref) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <FavoriteBoatRef>[];
  return ref.watch(favoritesGatewayProvider).favorites();
});

/// Favori kimlik kümesi — karttaki kalbin durumuna O(1) bakış. Liste
/// yüklenemediyse boş küme (eylem idempotent; ikinci favori zararsız).
final favoriteBoatIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  return ref.watch(favoriteBoatsProvider).maybeWhen(
        data: (List<FavoriteBoatRef> list) =>
            list.map((FavoriteBoatRef f) => f.id).toSet(),
        orElse: () => const <String>{},
      );
});

/// Eylemler — widget'tan `ref.read(favoriteActionsProvider)` ile çağrılır.
/// Hata fırlatır; ekran yakalayıp söyler (sessiz yutma yok).
final Provider<FavoriteActions> favoriteActionsProvider =
    Provider<FavoriteActions>((ref) => FavoriteActions(ref));

class FavoriteActions {
  const FavoriteActions(this._ref);

  final Ref _ref;

  /// [favorite] true → favorile; false → çıkar. Başarıda hem listem hem
  /// tekne kartı (favori sayısı) tazelenir — 0-bayat kuralı.
  Future<void> setFavorite(String boatId, {required bool favorite}) async {
    final FavoritesGateway gw = _ref.read(favoritesGatewayProvider);
    if (favorite) {
      await gw.favorite(boatId);
    } else {
      await gw.unfavorite(boatId);
    }
    _ref.invalidate(favoriteBoatsProvider);
    _ref.invalidate(publicBoatCardProvider(boatId));
  }
}
