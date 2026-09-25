import 'package:dockly_api/dockly_api.dart' show AdminStats;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/api_admin_gateway.dart';
import '../domain/admin_gateway.dart';

/// YÖNETİM PANELİ orkestrasyonu (kurucu talebi 2026-09-25).
///
/// Görünürlük istemcide `isAdminProvider` ile, YETKİ sunucuda RolesGuard ile
/// denetlenir (moderasyonla aynı iki-katman deseni). Panel yalnız sunucunun
/// bildiği sayıları gösterir; indirme sayısı App Store Connect'tedir.

final Provider<AdminGateway> adminGatewayProvider = Provider<AdminGateway>((ref) {
  return ApiAdminGateway(
    ref.watch(adminApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Bu hesap yönetim panelini görebilir mi? (admin ve üstü; moderatör GÖREMEZ —
/// moderasyonun kendi satırı zaten var.)
final Provider<bool> isAdminProvider = Provider<bool>((ref) {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return false;
  return const <String>{'admin', 'super_admin'}.contains(s.user.role);
});

/// Panel sayıları — ekran her açılışta tazelenir (autoDispose) ve elle
/// yenilenebilir (ref.invalidate).
final AutoDisposeFutureProvider<AdminStats> adminStatsProvider =
    FutureProvider.autoDispose<AdminStats>((ref) {
  return ref.watch(adminGatewayProvider).stats();
});

