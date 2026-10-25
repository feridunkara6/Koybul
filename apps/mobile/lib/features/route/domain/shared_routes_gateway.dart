import 'package:dockly_api/dockly_api.dart'
    show SharedRouteDetail, SharedRouteSummary;

/// TOPLULUK ROTALARI ağ geçidi (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24).
/// Gerçek implementasyon `data/api_shared_routes_gateway.dart`; testte sahte.
abstract interface class SharedRoutesGateway {
  /// Keşif listesi — kimliksiz çalışır; yalnız onaylı rotalar gelir.
  Future<List<SharedRouteSummary>> feed({required String sort});

  /// Detay — kimlik varsa savedByMe/doneByMe dolar.
  Future<SharedRouteDetail> detail(String routeId);

  /// Paylaşım — hesap ister; PENDING döner (moderasyon onayı beklenir).
  Future<({String id, String status})> share({
    required String name,
    required String body,
    String? season,
    String? boatSuggestion,
    required double distanceNm,
    double? durationHours,
    required List<String> stopLocationIds,
  });

  Future<({bool saved, int saveCount})> toggleSave(String routeId);
  Future<({bool done, int doneCount})> toggleDone(String routeId);
}
