import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_state.dart';
import '../domain/token_store.dart';

/// Giriş sağlayıcısı — Firebase kurulunca StubAuthGateway gerçek impl ile override edilir.
final Provider<AuthGateway> authGatewayProvider =
    Provider<AuthGateway>((ref) => const StubAuthGateway());

/// Token deposu — web: localStorage (rotasyon + aile iptaliyle dengelenmiş
/// bilinçli karar); MOBİL: Keychain/Keystore (SecureTokenStore, mağaza fazı).
/// Depoya erişilemezse her iki depo da hatayı yutar: oturumsuz devam edilir.
final Provider<TokenStore> tokenStoreProvider =
    Provider<TokenStore>((ref) => kIsWeb ? PrefsTokenStore() : SecureTokenStore());

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    usersApi: ref.watch(usersApiProvider),
    gateway: ref.watch(authGatewayProvider),
    store: ref.watch(tokenStoreProvider),
  );
});

/// Oturum durumu (docs/26 §4). Ekranlar bunu izler; hata istisna olarak fırlar,
/// çağıran ekran yakalayıp AppFailure.message'ı gösterir.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthRestoring();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Açılışta çağrılır — saklanan oturumu geri yükler.
  Future<void> restore() async {
    final user = await _repo.restore();
    state = user == null ? const Unauthenticated() : Authenticated(user);
  }

  /// Sağlayıcıyla giriş; başarısızlıkta AppFailure fırlatır (durum değişmez).
  Future<void> signIn(AuthProviderKind kind) async {
    final user = await _repo.signIn(kind);
    state = Authenticated(user);
  }

  /// E-posta + şifre ile giriş/kayıt; başarısızlıkta AppFailure fırlatır.
  Future<void> signInEmail({
    required String email,
    required String password,
    required bool register,
  }) async {
    final user = await _repo.signInEmail(
        email: email, password: password, register: register);
    state = Authenticated(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const Unauthenticated();
  }

  /// Hesabı siler. Başarısızlıkta AppFailure fırlatır ve OTURUM KORUNUR —
  /// kaptan hesabının silindiğini sanmasın (Faz 0).
  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    state = const Unauthenticated();
  }
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
