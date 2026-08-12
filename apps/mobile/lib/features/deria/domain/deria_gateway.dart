import 'package:dockly_api/dockly_api.dart';

/// DERİA doluluk ağ geçidi (clean architecture) — ekran somut API yerine buna
/// bağlanır; testte sahte ile değiştirilir, test ASLA ağa çıkmaz.
abstract interface class DeriaGateway {
  Future<DeriaAvailability> availability();
}
