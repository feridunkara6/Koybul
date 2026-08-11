import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/data/auth_repository.dart';
import 'package:dockly_mobile/features/auth/domain/auth_gateway.dart';
import 'package:dockly_mobile/features/auth/domain/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const SessionUser testUser = SessionUser(id: 'u1', role: 'user', isGuest: false, locale: 'tr');
const SessionUser testGuest = SessionUser(id: 'g1', role: 'user', isGuest: true, locale: 'tr');

/// Sabit oturum durumu döndüren kontrolcü (üyelik kapısı testleri için).
class FixedAuthController extends AuthController {
  FixedAuthController(this._fixed);
  final AuthState _fixed;

  @override
  AuthState build() => _fixed;
}

/// Testte "hesap açık" durumu: authControllerProvider bu override ile
/// Authenticated(testUser) döndürür — üyelik kapısı açılmaz.
Override signedInAuthOverride({SessionUser user = testUser}) =>
    authControllerProvider
        .overrideWith(() => FixedAuthController(Authenticated(user)));

/// Testte AuthRepository yerine geçen sahte (yalnız testte mock kuralı, docs/15).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.restoreResult, this.signInResult = testUser, this.signInError});

  SessionUser? restoreResult;
  SessionUser signInResult;
  AppFailure? signInError;

  final List<AuthProviderKind> signInCalls = <AuthProviderKind>[];
  final List<({String email, bool register})> emailCalls =
      <({String email, bool register})>[];
  bool loggedOut = false;

  /// Hesap silme çağrıldı mı (Faz 0).
  bool deleted = false;

  /// Ayarlanırsa `deleteAccount` bu hatayla düşer — oturum KORUNMALI.
  AppFailure? deleteError;

  @override
  Future<SessionUser> signIn(AuthProviderKind kind) async {
    signInCalls.add(kind);
    final error = signInError;
    if (error != null) throw error;
    return signInResult;
  }

  @override
  Future<SessionUser> signInEmail({
    required String email,
    required String password,
    required bool register,
  }) async {
    emailCalls.add((email: email, register: register));
    final error = signInError;
    if (error != null) throw error;
    return signInResult;
  }

  @override
  Future<SessionUser?> restore() async => restoreResult;

  @override
  Future<String?> validAccessToken() async => 'test-access-token';

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<void> deleteAccount() async {
    final AppFailure? error = deleteError;
    if (error != null) throw error;
    deleted = true;
  }
}
