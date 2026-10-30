import 'package:dockly_api/dockly_api.dart' show BoatsApi, FavoriteBoatRef;

import '../domain/favorites_gateway.dart';

/// Gerçek uygulama — `/v1/boats` favori uçları (TK-5, 0025).
class ApiFavoritesGateway implements FavoritesGateway {
  const ApiFavoritesGateway(this._api);

  final BoatsApi _api;

  @override
  Future<List<FavoriteBoatRef>> favorites() => _api.favorites();

  @override
  Future<void> favorite(String boatId) => _api.favorite(boatId);

  @override
  Future<void> unfavorite(String boatId) => _api.unfavorite(boatId);
}
