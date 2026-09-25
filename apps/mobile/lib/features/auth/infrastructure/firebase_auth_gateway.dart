import 'package:dockly_core/dockly_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../domain/auth_gateway.dart';

/// Gerçek Firebase kimlik köprüsü (docs/23 §3, docs/26 §8).
///
/// Yalnız kimlik doğrular ve ID token üretir; oturumun sahibi BİZİM sunucudur
/// (POST /v1/auth/sessions bu token'ı Google JWKS ile doğrular). Şifreler
/// hiçbir zaman bizim elimizden geçip saklanmaz — Firebase yönetir.
/// Bootstrap yalnız web'de ve Firebase.initializeApp başarılıysa bunu devreye
/// alır; aksi hâlde StubAuthGateway kalır (uygulama misafir modda çalışır).
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Future<String> obtainIdToken(AuthProviderKind kind) async {
    switch (kind) {
      case AuthProviderKind.google:
        return _guard(() async {
          // Web: popup akışı. MOBİL (mağaza fazı): sistem sayfalı sağlayıcı
          // akışı — firebase_auth signInWithProvider ek eklenti istemez.
          final UserCredential cred = kIsWeb
              ? await _auth.signInWithPopup(GoogleAuthProvider())
              : await _auth.signInWithProvider(GoogleAuthProvider());
          return _idTokenOf(cred);
        });
      case AuthProviderKind.apple:
        return _guard(() async {
          if (kIsWeb) {
            // Web'de Apple girişi ayrıca Apple Developer "Services ID"
            // yapılandırması ister — mağaza fazından sonra açılacak.
            throw const UnexpectedFailure(
                'Apple ile giriş şimdilik iOS uygulamasında.');
          }
          // iOS: yerli Sign in with Apple sayfası. App Store kuralı 4.8:
          // üçüncü taraf girişi (Google) sunan uygulamada bu seçenek ZORUNLU.
          final UserCredential cred =
              await _auth.signInWithProvider(AppleAuthProvider());
          return _idTokenOf(cred);
        });
      case AuthProviderKind.phone:
        throw const UnexpectedFailure('Bu giriş yöntemi çok yakında.');
      case AuthProviderKind.guest:
        // Misafirlik uygulamada "oturumsuz" durumdur; anonim Firebase hesabı
        // bilinçli olarak AÇILMAZ (docs/23 §3.3 — gereksiz hesap kirliliği).
        throw const UnexpectedFailure('Misafir modu için giriş gerekmez.');
      case AuthProviderKind.email:
        throw const UnexpectedFailure(
            'E-posta girişi için signInWithEmail kullanılır.');
    }
  }

  @override
  Future<String> signInWithEmail({required String email, required String password}) {
    return _guard(() async {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return _idTokenOf(cred);
    });
  }

  @override
  Future<String> registerWithEmail({required String email, required String password}) {
    return _guard(() async {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return _idTokenOf(cred);
    });
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // ŞİFREMİ UNUTTUM (kurucu talebi 2026-09-25): Firebase sıfırlama e-postası
    // gönderir; kullanıcı bağlantıdaki sayfada yeni şifresini belirler.
    // Hata eşlemesi giriş akışıyla AYNI dili konuşur (firebaseAuthErrorTr).
    await _guard(() async {
      await _auth.sendPasswordResetEmail(email: email);
      return ''; // _guard String döndürür; burada değer kullanılmaz
    });
  }

  @override
  Future<void> signOutProvider() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Sağlayıcı çıkışı en-iyi-çaba: yerel oturum temizliği her durumda yapılır.
    }
  }

  static Future<String> _idTokenOf(UserCredential cred) async {
    final String? token = await cred.user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const UnexpectedFailure('Kimlik doğrulanamadı. Tekrar deneyin.');
    }
    return token;
  }

  /// FirebaseAuthException → uygulamanın tek hata dili (AppFailure, Türkçe).
  static Future<String> _guard(Future<String> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      throw firebaseAuthErrorTr(e.code);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const UnexpectedFailure('Giriş yapılamadı. Tekrar deneyin.');
    }
  }
}

/// Firebase hata kodu → kullanıcı dostu Türkçe mesaj (saf işlev — birim testli).
AppFailure firebaseAuthErrorTr(String code) {
  switch (code) {
    case 'invalid-email':
      return const AuthFailure('E-posta adresi geçersiz görünüyor.');
    case 'user-not-found':
      return const AuthFailure(
          'Bu e-posta ile kayıt bulunamadı — önce "Kayıt ol"u deneyin.');
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return const AuthFailure('E-posta ya da şifre hatalı.');
    case 'email-already-in-use':
      return const AuthFailure(
          'Bu e-posta zaten kayıtlı — "Giriş yap"ı deneyin.');
    case 'weak-password':
      return const AuthFailure('Şifre çok zayıf — en az 6 karakter kullanın.');
    case 'user-disabled':
      return const AuthFailure('Bu hesap devre dışı bırakılmış.');
    case 'too-many-requests':
      return const AuthFailure(
          'Çok fazla deneme yapıldı — birkaç dakika sonra tekrar deneyin.');
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return const AuthFailure('Google penceresi kapatıldı — tekrar deneyin.');
    case 'popup-blocked':
      return const AuthFailure(
          'Tarayıcı açılır pencereyi engelledi — izin verip tekrar deneyin.');
    case 'network-request-failed':
      return const NetworkFailure();
    default:
      return const UnexpectedFailure('Giriş yapılamadı. Tekrar deneyin.');
  }
}
