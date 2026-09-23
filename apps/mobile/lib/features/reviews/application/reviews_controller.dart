import 'package:dockly_api/dockly_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_reviews_gateway.dart';
import '../domain/reviews_gateway.dart';

/// Yorum ağ geçidi sağlayıcısı — testte sahte ile override edilir.
/// P5: oturum varsa istek kimlikli gider (yorum kilidi kararı sunucuda).
final Provider<ReviewsGateway> reviewsGatewayProvider = Provider<ReviewsGateway>(
  (ref) => ApiReviewsGateway(
    ref.watch(locationsApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  ),
);

/// Bir lokasyonun onaylı yorumları (S-09, docs/23 §11.3). id/slug başına;
/// AsyncValue ile yükleme/hata/veri taşır.
///
/// P5: oturum durumu İZLENİR — giriş/çıkışta liste yeniden çekilir (detaydaki
/// desenle aynı; ekranda bayat kilitli/açık liste kalmaz).
final reviewsProvider = FutureProvider.family<List<Review>, String>(
  (ref, String idOrSlug) {
    ref.watch(authControllerProvider);
    return ref.watch(reviewsGatewayProvider).fetch(idOrSlug);
  },
);
