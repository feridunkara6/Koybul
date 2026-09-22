import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/premium_offline_cache.dart';
import '../domain/purchase_gateway.dart';
import '../infrastructure/purchase_gateway_factory.dart';

/// Sunucu tarafı premium işlemleri — testte sahteyle değiştirilir.
/// (Gerçek uygulama: PremiumApi + geçerli access token.)
abstract interface class PremiumBackend {
  Future<PremiumMe> me();
  Future<PremiumLinkResult> link(String transactionId);
}

class ApiPremiumBackend implements PremiumBackend {
  ApiPremiumBackend(this._api, this._tokenProvider);

  final PremiumApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _token() async {
    final String? token = await _tokenProvider();
    if (token == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return token;
  }

  @override
  Future<PremiumMe> me() async => _api.me(await _token());

  @override
  Future<PremiumLinkResult> link(String transactionId) async =>
      _api.linkApple(accessToken: await _token(), transactionId: transactionId);
}

final Provider<PremiumBackend> premiumBackendProvider =
    Provider<PremiumBackend>((ref) {
  return ApiPremiumBackend(
    ref.watch(premiumApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Mağaza kapısı — platforma göre gerçek/stub; testler override eder.
final Provider<PurchaseGateway> purchaseGatewayProvider =
    Provider<PurchaseGateway>((ref) {
  final PurchaseGateway gateway = createPurchaseGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});

/// Abonelik + keşif hakkı durumu. Hesapsız (misafir/çıkış) durumda null —
/// ekranlar bunu "premium yok" diye okur; sunucuya boşuna istek atılmaz.
///
/// ÇEVRİMDIŞI KORUMA (P4b, premium v3 raporu §9): denizde ağ yokken premium
/// SIFIRLANMAZ — son başarılı yanıtın bitiş tarihi cihazda saklanır; tarih
/// geçmediyse premium sürer, geçtiyse biter (uydurma uzatma yok).
final FutureProvider<PremiumMe?> premiumMeProvider =
    FutureProvider<PremiumMe?>((ref) async {
  final AuthState auth = ref.watch(authControllerProvider);
  if (auth is! Authenticated || auth.isGuest) return null;
  final PremiumOfflineStore offline = ref.watch(premiumOfflineStoreProvider);
  try {
    final PremiumMe me = await ref.watch(premiumBackendProvider).me();
    // İz BEKLENMEDEN yazılır (en iyi çaba): ekran depo yüzünden gecikmez.
    unawaited(offline.save(me));
    return me;
  } on AppFailure {
    final PremiumMe? cached = await offline.read();
    if (cached != null) return cached;
    rethrow;
  }
});

/// PREMIUM ETKİN Mİ? — kota/kilit kararlarının tek senkron kaynağı (P4b).
/// Durum yüklenmemiş/hatalı/hesapsızken false: kapılar güvenli tarafta kalır
/// (premium'a haksız kapı DEĞİL, ücretsiz kurala düşüş).
final Provider<bool> isPremiumActiveProvider = Provider<bool>(
  (ref) => ref.watch(premiumMeProvider).valueOrNull?.active ?? false,
);

/// Paket ekranının akış durumu.
enum PurchasePhase {
  /// Mağaza sorgulanıyor (ekran ilk açılış).
  loading,

  /// Mağazaya ulaşılamıyor (web, mağaza hesabı yok, ağ yok).
  unavailable,

  /// Paketler listelendi, satın alınabilir.
  ready,

  /// Mağaza penceresi açık / işlem sürüyor.
  purchasing,

  /// Satın alma bitti, sunucu Apple'dan doğruluyor.
  linking,

  /// Premium hesaba işlendi.
  done,
}

class PurchaseUiState {
  const PurchaseUiState({
    required this.phase,
    this.packages = const <PremiumPackage>[],
    this.failed = false,
    this.restoreChecked = false,
  });

  final PurchasePhase phase;
  final List<PremiumPackage> packages;

  /// Son işlem hatayla bitti (arayüz kibar genel mesaj gösterir; ham mağaza
  /// hatası kullanıcıya sızmaz).
  final bool failed;

  /// "Geri yükle" taraması bitti ve yeni abonelik çıkmadı — bilgi notu.
  final bool restoreChecked;

  PurchaseUiState copyWith({
    PurchasePhase? phase,
    List<PremiumPackage>? packages,
    bool? failed,
    bool? restoreChecked,
  }) {
    return PurchaseUiState(
      phase: phase ?? this.phase,
      packages: packages ?? this.packages,
      failed: failed ?? this.failed,
      restoreChecked: restoreChecked ?? this.restoreChecked,
    );
  }
}

/// Satın alma orkestrasyonu (P3): mağaza olaylarını dinler, başarıda işlem
/// kimliğini SUNUCUYA bağlatır (premium'u veren adım budur) ve durum
/// sağlayıcısını tazeler.
class PurchaseController extends Notifier<PurchaseUiState> {
  StreamSubscription<PurchaseOutcome>? _sub;

  @override
  PurchaseUiState build() {
    final PurchaseGateway gateway = ref.watch(purchaseGatewayProvider);
    _sub?.cancel();
    _sub = gateway.outcomes.listen(_onOutcome);
    ref.onDispose(() => _sub?.cancel());
    Future<void>.microtask(_init);
    return const PurchaseUiState(phase: PurchasePhase.loading);
  }

  PurchaseGateway get _gateway => ref.read(purchaseGatewayProvider);

  Future<void> _init() async {
    if (!await _gateway.isAvailable()) {
      state = state.copyWith(phase: PurchasePhase.unavailable);
      return;
    }
    try {
      final List<PremiumPackage> packages = await _gateway.loadPackages();
      state = packages.isEmpty
          ? state.copyWith(phase: PurchasePhase.unavailable)
          : state.copyWith(phase: PurchasePhase.ready, packages: packages);
    } catch (_) {
      state = state.copyWith(phase: PurchasePhase.unavailable);
    }
  }

  Future<void> buy(PremiumPackage package) async {
    if (state.phase != PurchasePhase.ready) return;
    state = state.copyWith(
        phase: PurchasePhase.purchasing, failed: false, restoreChecked: false);
    try {
      await _gateway.buy(package);
    } catch (_) {
      state = state.copyWith(phase: PurchasePhase.ready, failed: true);
    }
  }

  Future<void> restore() async {
    if (state.phase != PurchasePhase.ready) return;
    state = state.copyWith(
        phase: PurchasePhase.purchasing, failed: false, restoreChecked: false);
    try {
      await _gateway.restore();
    } catch (_) {
      state = state.copyWith(phase: PurchasePhase.ready, failed: true);
    }
  }

  Future<void> _onOutcome(PurchaseOutcome outcome) async {
    switch (outcome.kind) {
      case PurchaseOutcomeKind.purchased:
        await _link(outcome.transactionId!);
      case PurchaseOutcomeKind.canceled:
        if (state.phase == PurchasePhase.purchasing) {
          state = state.copyWith(phase: PurchasePhase.ready);
        }
      case PurchaseOutcomeKind.failed:
        if (state.phase == PurchasePhase.purchasing) {
          state = state.copyWith(phase: PurchasePhase.ready, failed: true);
        }
      case PurchaseOutcomeKind.restoreFinished:
        if (state.phase == PurchasePhase.purchasing) {
          state = state.copyWith(
              phase: PurchasePhase.ready, restoreChecked: true);
        }
    }
  }

  Future<void> _link(String transactionId) async {
    state = state.copyWith(phase: PurchasePhase.linking);
    try {
      final PremiumLinkResult result =
          await ref.read(premiumBackendProvider).link(transactionId);
      ref.invalidate(premiumMeProvider);
      // Bitmiş abonelik geri yüklendiyse dürüst davran: "etkin" deme.
      state = result.active
          ? state.copyWith(phase: PurchasePhase.done)
          : state.copyWith(phase: PurchasePhase.ready, restoreChecked: true);
    } on AppFailure {
      state = state.copyWith(phase: PurchasePhase.ready, failed: true);
    }
  }
}

final NotifierProvider<PurchaseController, PurchaseUiState>
    purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseUiState>(
        PurchaseController.new);
