import 'package:dockly_api/dockly_api.dart';

import '../domain/reviews_gateway.dart';

/// `ReviewsGateway`'in gerçek uygulaması — `LocationsApi.reviews`'e devreder.
///
/// P5 (premium v3 §9): oturum varsa access token da gönderilir — bayrak
/// açıkken yorumlar kilitlidir; tam erişimli kullanıcı (premium/keşif hakkı)
/// listeyi kimliğiyle alır. Oturum yoksa istek eskisi gibi ANONİM gider.
class ApiReviewsGateway implements ReviewsGateway {
  const ApiReviewsGateway(this._api, this._tokenProvider);

  final LocationsApi _api;
  final Future<String?> Function() _tokenProvider;

  @override
  Future<List<Review>> fetch(String idOrSlug) async {
    final String? token = await _tokenProvider();
    return _api.reviews(idOrSlug, accessToken: token);
  }
}
