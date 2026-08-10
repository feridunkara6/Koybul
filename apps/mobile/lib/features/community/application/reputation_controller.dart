import 'package:dockly_api/dockly_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/api_reputation_gateway.dart';
import '../domain/reputation_gateway.dart';
import 'community_controller.dart';

/// DENİZCİ PROFİLİ — istemci tarafı orkestrasyonu.
///
/// Buradaki sağlayıcıların HİÇBİRİ misafirde okunmaz: onları izleyen ekranlar
/// (Teknem kartı, Katkılarım, Moderasyon) hesap yoksa zaten çizilmez. Bu,
/// misafirin her açılışta 401 üretmesini engeller.

final Provider<ReputationGateway> reputationGatewayProvider = Provider<ReputationGateway>((ref) {
  return ApiReputationGateway(
    ref.watch(reputationApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Oturum GERÇEK hesap mı (misafir sayılmaz) — kart/ekran çizilir mi kararı.
/// `hasAccount` (account_gate) ile aynı kuralı izler ama `watch` eder:
/// giriş yapılınca kart kendiliğinden dolar, ekran yeniden kurulmaz.
final Provider<bool> hasRealAccountProvider = Provider<bool>((ref) {
  final AuthState s = ref.watch(authControllerProvider);
  return s is Authenticated && !s.isGuest;
});

/// Moderatör mü — Moderasyon satırı yalnız bu doğruyken çizilir.
/// Sunucu ayrıca `@MinRole('moderator')` ile korur: bu yalnız GÖRÜNÜRLÜK.
final Provider<bool> isModeratorProvider = Provider<bool>((ref) {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return false;
  return const <String>{'moderator', 'admin', 'super_admin'}.contains(s.user.role);
});

/// Denizci profili özeti. Hesap yoksa BOŞ özet döner — ağ isteği yapılmaz.
final FutureProvider<ReputationSummary> reputationSummaryProvider =
    FutureProvider<ReputationSummary>((ref) async {
  if (!ref.watch(hasRealAccountProvider)) return ReputationSummary.empty;
  return ref.watch(reputationGatewayProvider).summary();
});

/// Katkı puanı dökümü — "Katkı puanı" ekranı.
final FutureProvider<List<ContributionItem>> contributionsProvider =
    FutureProvider<List<ContributionItem>>((ref) async {
  if (!ref.watch(hasRealAccountProvider)) return const <ContributionItem>[];
  return ref.watch(reputationGatewayProvider).contributions();
});

/// Kendi notlarım, duruma göre. `null` = hepsi.
/// autoDispose: Katkılarım ekranı kapanınca istek serbest kalır.
final myNotesProvider = FutureProvider.autoDispose.family<List<Note>, String?>(
  (ref, String? status) async {
    if (!ref.watch(hasRealAccountProvider)) return const <Note>[];
    return ref.watch(communityGatewayProvider).myNotes(status: status);
  },
);

/// Moderasyon kuyruğu (tür süzgeciyle). Rol yoksa hiç izlenmez.
final moderationQueueProvider =
    FutureProvider.autoDispose.family<List<ModerationItem>, String?>(
  (ref, String? entityType) async {
    if (!ref.watch(isModeratorProvider)) return const <ModerationItem>[];
    return ref.watch(reputationGatewayProvider).moderationQueue(entityType: entityType);
  },
);

/// Tür başına bekleyen sayılar — kuyruk şeridindeki rozetler.
final moderationCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  if (!ref.watch(isModeratorProvider)) return const <String, int>{};
  return ref.watch(reputationGatewayProvider).moderationCounts();
});

/// Karar sonrası kuyruktan DÜŞEN görevler. Sunucu listeyi hemen tazelese bile
/// karar verilen kart ekranda kalmamalı (occupancy/not deseniyle aynı).
class ModerationHandled extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void markHandled(String taskId) {
    state = <String>{...state, taskId};
  }
}

final NotifierProvider<ModerationHandled, Set<String>> moderationHandledProvider =
    NotifierProvider<ModerationHandled, Set<String>>(ModerationHandled.new);
