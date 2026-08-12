import 'package:dockly_api/dockly_api.dart';

import '../domain/deria_gateway.dart';

/// Gerçek API'ye giden uygulama.
class ApiDeriaGateway implements DeriaGateway {
  const ApiDeriaGateway(this._api);

  final DeriaApi _api;

  @override
  Future<DeriaAvailability> availability() => _api.availability();
}
