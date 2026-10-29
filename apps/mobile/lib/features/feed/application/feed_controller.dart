import 'package:dockly_api/dockly_api.dart' show FeedItem;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/api_feed_gateway.dart';
import '../domain/feed_gateway.dart';

/// TAKİP AKIŞI orkestrasyonu (SP-3b, kurucu onayı 2026-10-31).
///
/// Akış kişiseldir (takip grafiği): misafir/oturumsuzda sunucuya hiç
/// gidilmez, boş liste döner — Bugün'deki bölüm kendini çizmez (0-uydurma)
/// ve topluluk şeridi keşif kapısı olarak kalır.

final Provider<FeedGateway> feedGatewayProvider = Provider<FeedGateway>((ref) {
  return ApiFeedGateway(
    ref.watch(tripsApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Akış — en yeni önce. autoDispose: ekrandan çıkınca salınır.
/// NOT: sağ taraf tür değişkende tekrarlanmaz (CI dersi, invalid_assignment).
final feedProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <FeedItem>[];
  return ref.watch(feedGatewayProvider).following();
});

/// Eylemler — hata fırlatır; ekran yakalayıp söyler (sessiz yutma yok).
final Provider<FeedActions> feedActionsProvider =
    Provider<FeedActions>((ref) => FeedActions(ref));

class FeedActions {
  const FeedActions(this._ref);

  final Ref _ref;

  /// "Pruvan neta" aç/kapat — sunucu doğruluk kaynağıdır; dönen sayaçla
  /// kart yerinde güncellenir (ekran tarafı), akış tazelenmez (zıplamasın).
  Future<({bool reacted, int pruvaCount})> togglePruva(String tripId) {
    return _ref.read(feedGatewayProvider).togglePruva(tripId);
  }
}
