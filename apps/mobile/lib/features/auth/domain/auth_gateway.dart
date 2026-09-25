import 'package:dockly_core/dockly_core.dart';

/// Giriş sağlayıcıları (docs/23 §3). email/phone detay akışları 2.4c ekranlarında.
enum AuthProviderKind { apple, google, email, phone, guest }

/// Firebase kimlik köprüsü arayüzü (docs/26 §8). Sağlayıcı ile oturum açar ve
/// sunucuya verilecek Firebase ID token'ını döndürür. Gerçek implementasyon:
/// `infrastructure/firebase_auth_gateway.dart` (bootstrap web'de override eder);
/// testlerde ve Firebase kurulamadığında stub devrededir (çökme yok).
abstract interface class AuthGateway {
  /// Sağlayıcı düğmesiyle giriş (Google/Apple/misafir) → Firebase ID token.
  Future<String> obtainIdToken(AuthProviderKind kind);

  /// E-posta + şifre ile GİRİŞ → Firebase ID token.
  Future<String> signInWithEmail({required String email, required String password});

  /// E-posta + şifre ile KAYIT (hesap oluşturur) → Firebase ID token.
  Future<String> registerWithEmail({required String email, required String password});

  /// ŞİFREMİ UNUTTUM (kurucu talebi 2026-09-25): e-postaya sıfırlama
  /// bağlantısı gönderir. Bağlantı Firebase'in barındırdığı sayfayı açar;
  /// kullanıcı yeni şifresini orada belirler — uygulamada ek ekran gerekmez.
  Future<void> sendPasswordReset(String email);

  /// Sağlayıcı tarafındaki oturumu kapatır (bizim sunucu oturumundan ayrı).
  Future<void> signOutProvider();

  /// Görüntülenecek e-posta (oturum açık Firebase kullanıcısından); yoksa null.
  String? get currentEmail;
}

/// Firebase henüz yapılandırılmadığında kullanılan güvenli varsayılan.
/// Butona basılırsa kullanıcıya nazik bir mesaj gösterilir (çökme yok).
class StubAuthGateway implements AuthGateway {
  const StubAuthGateway();

  static const AppFailure _notReady = UnexpectedFailure(
    'Giriş şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
  );

  @override
  Future<String> obtainIdToken(AuthProviderKind kind) async => throw _notReady;

  @override
  Future<String> signInWithEmail({required String email, required String password}) async =>
      throw _notReady;

  @override
  Future<String> registerWithEmail({required String email, required String password}) async =>
      throw _notReady;

  @override
  Future<void> sendPasswordReset(String email) async => throw _notReady;

  @override
  Future<void> signOutProvider() async {}

  @override
  String? get currentEmail => null;
}
