import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/feed_gateway.dart';

/// Gerçek sunucu ağ geçidi — profil geçidiyle aynı desen: tüm uçlar
/// kişiseldir, token ŞART (misafire bu yüzeyler hiç açılmaz).
class ApiFeedGateway implements FeedGateway {
  ApiFeedGateway(this._api, this._tokenProvider);

  final TripsApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _requiredToken() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<List<FeedItem>> following() async =>
      _api.feed(await _requiredToken());

  @override
  Future<String> shareTrip({
    String? startName,
    String? endName,
    required double distanceNm,
    int? durationMin,
    required int stopCount,
    required String sailedOn,
  }) async =>
      _api.shareTrip(
        accessToken: await _requiredToken(),
        startName: startName,
        endName: endName,
        distanceNm: distanceNm,
        durationMin: durationMin,
        stopCount: stopCount,
        sailedOn: sailedOn,
      );

  @override
  Future<({bool reacted, int pruvaCount})> togglePruva(String tripId) async =>
      _api.togglePruva(accessToken: await _requiredToken(), tripId: tripId);
}
