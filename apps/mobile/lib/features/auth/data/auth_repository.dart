import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/auth_gateway.dart';
import '../domain/token_store.dart';

/// Auth repository sözleşmesi (docs/26 §2 data katmanı).
abstract interface class AuthRepository {
  /// Sağlayıcıyla giriş: gateway → sunucu oturumu → token saklama → kullanıcı.
  Future<SessionUser> signIn(AuthProviderKind kind);

  /// E-posta + şifre ile giriş ya da kayıt (register=true → hesap oluşturur).
  Future<SessionUser> signInEmail({
    required String email,
    required String password,
    required bool register,
  });

  /// Açılışta saklanan refresh token'dan oturumu geri yükler; yoksa/geçersizse null.
  Future<SessionUser?> restore();

  /// Yetkili uçlar için geçerli access token (2026-07 doluluk paketi).
  /// Süresi dolmuşsa/yoksa refresh ile tazelemeyi dener; oturum yoksa null.
  Future<String?> validAccessToken();

  /// Çıkış: sunucuda aile iptali (best-effort) + yerel temizlik.
  Future<void> logout();

  /// HESAP SİLME (Faz 0 — mağaza ve KVKK şartı).
  ///
  /// Çıkıştan farkı: sunucu hatası YUTULMAZ. Silme başarısızsa yerel oturum
  /// da korunur — yoksa kaptan hesabı sildiğini sanır, oysa hesap durmaya
  /// devam eder. Sunucu 204 dönerse yerel temizlik çıkışla aynıdır.
  Future<void> deleteAccount();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required UsersApi usersApi,
    required AuthGateway gateway,
    required TokenStore store,
  })  : _api = api,
        _usersApi = usersApi,
        _gateway = gateway,
        _store = store;

  final AuthApi _api;
  final UsersApi _usersApi;
  final AuthGateway _gateway;
  final TokenStore _store;

  /// Bellekteki access token + bitiş anı (yalnız refresh token kalıcıdır;
  /// access token GÜVENLİK gereği diske yazılmaz — docs/26 §8).
  String? _accessToken;
  DateTime? _accessExpiresAt;

  void _rememberAccess(SessionBundle bundle) {
    _accessToken = bundle.accessToken;
    // 60 sn emniyet payı: süre sonuna yaklaşan token kullanılmaz.
    _accessExpiresAt =
        DateTime.now().add(Duration(seconds: bundle.expiresIn - 60));
  }

  @override
  Future<String?> validAccessToken() async {
    final DateTime? exp = _accessExpiresAt;
    if (_accessToken != null && exp != null && DateTime.now().isBefore(exp)) {
      return _accessToken;
    }
    // Süresi dolmuş → refresh dene (restore aynı zamanda tokenı da hatırlar).
    final SessionUser? user = await restore();
    return user == null ? null : _accessToken;
  }

  @override
  Future<SessionUser> signIn(AuthProviderKind kind) async {
    final idToken = await _gateway.obtainIdToken(kind);
    return _openSession(idToken);
  }

  @override
  Future<SessionUser> signInEmail({
    required String email,
    required String password,
    required bool register,
  }) async {
    final idToken = register
        ? await _gateway.registerWithEmail(email: email, password: password)
        : await _gateway.signInWithEmail(email: email, password: password);
    return _openSession(idToken);
  }

  /// Firebase ID token → sunucu oturumu (docs/23 §3.1) → refresh saklama.
  Future<SessionUser> _openSession(String idToken) async {
    final bundle = await _api.createSession(idToken);
    await _store.saveRefreshToken(bundle.refreshToken);
    _rememberAccess(bundle);
    return bundle.user;
  }

  @override
  Future<SessionUser?> restore() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final bundle = await _api.refresh(refreshToken);
      await _store.saveRefreshToken(bundle.refreshToken);
      _rememberAccess(bundle);
      return bundle.user;
    } on AppFailure {
      // Geçersiz/expired refresh → yerel temizlik, sessiz düşüş (docs/26 §8).
      await _store.clear();
      return null;
    }
  }

  @override
  Future<void> deleteAccount() async {
    // Geçerli access token ŞART: yoksa sunucuya silme isteği gönderemeyiz ve
    // sessizce "silindi" demek yalan olur.
    final String? token = await validAccessToken();
    if (token == null) {
      throw const AuthFailure('Oturum bulunamadı. Tekrar giriş yapıp dene.');
    }
    // Hata bilerek YUKARI FIRLAR — ekran mesajı gösterir, oturum korunur.
    await _usersApi.deleteMe(token);
    // Sunucu sildi: yerelde çıkışla aynı temizlik.
    await _store.clear();
    _accessToken = null;
    _accessExpiresAt = null;
    await _gateway.signOutProvider();
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } on AppFailure {
        // Çıkış her hâlükârda yerelde tamamlanır; sunucu hatası yutulur.
      }
    }
    await _store.clear();
    _accessToken = null;
    _accessExpiresAt = null;
    // Sağlayıcı (Firebase) oturumunu da kapat — en-iyi-çaba, hata fırlatmaz.
    await _gateway.signOutProvider();
  }
}
