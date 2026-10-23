import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/marina_gateway.dart';

/// Gerçek sunucu ağ geçidi — soru-cevap geçidiyle aynı desen: okuma esnek
/// (topluluk token'sız da çalışır, sayılar herkese), yazma katı (token şart).
class ApiMarinaGateway implements MarinaGateway {
  ApiMarinaGateway(this._api, this._tokenProvider);

  final MarinaApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _requiredToken() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<MyMarinaBoat?> myBoat() async => _api.me(await _requiredToken());

  @override
  Future<MyMarinaBoat> upsertMyBoat({
    required String name,
    required String boatTypeCode,
    required double lengthM,
    String? brand,
    required String marinaLocationId,
    required bool visible,
    required bool shareSpecs,
  }) async =>
      _api.upsertMyBoat(
        accessToken: await _requiredToken(),
        name: name,
        boatTypeCode: boatTypeCode,
        lengthM: lengthM,
        brand: brand,
        marinaLocationId: marinaLocationId,
        visible: visible,
        shareSpecs: shareSpecs,
      );

  @override
  Future<MarinaCommunity> community(String locationId) async =>
      _api.community(locationId, accessToken: await _tokenProvider());
}
