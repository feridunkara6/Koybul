import 'package:dockly_api/dockly_api.dart'
    show SharedRouteDetail, SharedRouteSummary;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_shared_routes_gateway.dart';
import '../domain/shared_routes_gateway.dart';

/// TOPLULUK ROTALARI orkestrasyonu (Sosyalleşme Hafta 3, kurucu onayı
/// 2026-10-24). Keşif anonim çalışır; kaydet/yaptım/paylaş hesap ister
/// (kapı SUNUCUDA — istemci yalnız kibar mesaj gösterir).

final Provider<SharedRoutesGateway> sharedRoutesGatewayProvider =
    Provider<SharedRoutesGateway>((ref) {
  return ApiSharedRoutesGateway(
    ref.watch(routesApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Keşif sıralaması: 'new' | 'popular' (çip durumu).
final StateProvider<String> sharedRoutesSortProvider =
    StateProvider<String>((ref) => 'new');

/// Keşif akışı — sıralamaya göre aile; ekrandan çıkınca salınır.
final AutoDisposeFutureProviderFamily<List<SharedRouteSummary>, String>
    sharedRoutesFeedProvider =
    FutureProvider.autoDispose.family<List<SharedRouteSummary>, String>(
        (ref, String sort) {
  return ref.watch(sharedRoutesGatewayProvider).feed(sort: sort);
});

/// Rota detayı — kimlik varsa savedByMe/doneByMe dolu gelir.
final AutoDisposeFutureProviderFamily<SharedRouteDetail, String>
    sharedRouteDetailProvider =
    FutureProvider.autoDispose.family<SharedRouteDetail, String>(
        (ref, String routeId) {
  return ref.watch(sharedRoutesGatewayProvider).detail(routeId);
});
