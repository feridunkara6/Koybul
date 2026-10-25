import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/shared_routes_gateway.dart';

/// Gerçek sunucu ağ geçidi — marina/qa geçitleriyle aynı desen: okuma esnek
/// (token varsa gönderilir, yoksa anonim), yazma katı (token şart).
class ApiSharedRoutesGateway implements SharedRoutesGateway {
  ApiSharedRoutesGateway(this._api, this._tokenProvider);

  final RoutesApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _requiredToken() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<List<SharedRouteSummary>> feed({required String sort, String? locationId}) =>
      _api.list(sort: sort, locationId: locationId);

  @override
  Future<SharedRouteDetail> detail(String routeId) async =>
      _api.detail(routeId, accessToken: await _tokenProvider());

  @override
  Future<({String id, String status})> share({
    required String name,
    required String body,
    String? season,
    String? boatSuggestion,
    required double distanceNm,
    double? durationHours,
    required List<String> stopLocationIds,
  }) async =>
      _api.create(
        accessToken: await _requiredToken(),
        name: name,
        body: body,
        season: season,
        boatSuggestion: boatSuggestion,
        distanceNm: distanceNm,
        durationHours: durationHours,
        stopLocationIds: stopLocationIds,
      );

  @override
  Future<({bool saved, int saveCount})> toggleSave(String routeId) async =>
      _api.toggleSave(accessToken: await _requiredToken(), routeId: routeId);

  @override
  Future<({bool done, int doneCount})> toggleDone(String routeId) async =>
      _api.toggleDone(accessToken: await _requiredToken(), routeId: routeId);
}
