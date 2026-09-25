import 'package:dockly_api/dockly_api.dart' show AdminPremiumGrant, AdminStats;

/// YÖNETİM PANELİ ağ geçidi (kurucu talebi 2026-09-25) — testte sahteyle
/// değiştirilir; gerçek uygulama `/v1/admin/*` uçlarına gider.
abstract interface class AdminGateway {
  Future<AdminStats> stats();

  Future<AdminPremiumGrant> grantPremium({
    required String email,
    required int months,
  });
}
