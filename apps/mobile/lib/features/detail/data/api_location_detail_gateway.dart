import 'package:dockly_api/dockly_api.dart';

import '../domain/location_detail_gateway.dart';

/// `LocationDetailGateway`'in gerçek uygulaması — `LocationsApi.detail`'e devreder.
///
/// P4 (premium v3 raporu §9): oturum varsa access token da gönderilir —
/// sunucu premium/keşif-hakkı kararını kimliğe göre verir (vitrin ya da tam).
/// Oturum yoksa istek eskisi gibi ANONİM gider; davranış değişmez.
class ApiLocationDetailGateway implements LocationDetailGateway {
  const ApiLocationDetailGateway(this._api, this._tokenProvider);

  final LocationsApi _api;
  final Future<String?> Function() _tokenProvider;

  @override
  Future<LocationDetail> fetch(String idOrSlug) async {
    final String? token = await _tokenProvider();
    return _api.detail(idOrSlug, accessToken: token);
  }
}
