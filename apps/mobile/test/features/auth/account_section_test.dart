import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_gateway.dart';
import 'package:dockly_mobile/features/auth/infrastructure/firebase_auth_gateway.dart';
import 'package:dockly_mobile/features/auth/presentation/account_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

Widget _app(FakeAuthRepository repo) {
  return ProviderScope(
    overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AccountSection())),
    ),
  );
}

/// Alt sayfayı açar (CI dersi: modal animasyonu için pumpAndSettle şart).
Future<void> _openSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Giriş yap veya kayıt ol'));
  await tester.pump();
  await tester.tap(find.text('Giriş yap veya kayıt ol'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String email, String password) async {
  final Finder fields = find.descendant(
    of: find.byType(SignInSheetBody),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await tester.pump();
}

/// Alt sayfadaki düğmeye güvenli dokunuş (CI dersi: görünür alana kaydır).
Future<void> _tapSheetButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('firebaseAuthErrorTr (birim)', () {
    test('bilinen kodlar Türkçe mesaja eşlenir', () {
      expect(firebaseAuthErrorTr('wrong-password').message,
          'E-posta ya da şifre hatalı.');
      expect(firebaseAuthErrorTr('email-already-in-use').message,
          contains('zaten kayıtlı'));
      expect(firebaseAuthErrorTr('weak-password').message, contains('6 karakter'));
      expect(firebaseAuthErrorTr('network-request-failed'), isA<NetworkFailure>());
    });

    test('bilinmeyen kod → genel mesaj (ham kod sızmaz)', () {
      expect(firebaseAuthErrorTr('garip-kod').message,
          'Giriş yapılamadı. Tekrar deneyin.');
    });
  });

  testWidgets('oturum yokken giriş kartı görünür; misafir ilkesi metinde',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository()));
    expect(find.text('Giriş yap veya kayıt ol'), findsOneWidget);
    expect(find.textContaining('misafir'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsNothing);
  });

  testWidgets('e-posta girişi: doğru bilgilerle oturum açılır, kart değişir',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);
    expect(find.text('Hoş geldin, kaptan'), findsOneWidget);

    await _fill(tester, 'kaptan@ornek.com', 'sifre123');
    await _tapSheetButton(tester, 'Giriş yap');

    expect(repo.emailCalls.single, (email: 'kaptan@ornek.com', register: false));
    // Sayfa kapandı, hesap kartı geldi.
    expect(find.byType(SignInSheetBody), findsNothing);
    expect(find.text('Hesabın açık'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);
  });

  testWidgets('Kayıt ol düğmesi register=true ile çağırır',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);
    await _fill(tester, 'yeni@ornek.com', 'sifre123');
    await _tapSheetButton(tester, 'Kayıt ol');
    expect(repo.emailCalls.single, (email: 'yeni@ornek.com', register: true));
  });

  testWidgets('geçersiz e-posta/kısa şifre: istemci doğrulaması, repo çağrılmaz',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);

    await _fill(tester, 'epostasiz', 'sifre123');
    await _tapSheetButton(tester, 'Giriş yap');
    expect(find.byKey(const ValueKey<String>('auth-error')), findsOneWidget);
    expect(find.text('Geçerli bir e-posta adresi yaz.'), findsOneWidget);

    await _fill(tester, 'kaptan@ornek.com', '123');
    await _tapSheetButton(tester, 'Giriş yap');
    expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);

    expect(repo.emailCalls, isEmpty);
    expect(find.byType(SignInSheetBody), findsOneWidget); // sayfa kapanmadı
  });

  testWidgets('sunucu/Firebase hatası sayfada gösterilir, sayfa kapanmaz',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository(
      signInError: const AuthFailure('E-posta ya da şifre hatalı.'),
    );
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);
    await _fill(tester, 'kaptan@ornek.com', 'sifre123');
    await _tapSheetButton(tester, 'Giriş yap');

    expect(find.text('E-posta ya da şifre hatalı.'), findsOneWidget);
    expect(find.byType(SignInSheetBody), findsOneWidget);
    expect(find.text('Hesabın açık'), findsNothing);
  });

  testWidgets('Google ile devam et → repo.signIn(google)',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);
    await _tapSheetButton(tester, 'Google ile devam et');
    expect(repo.signInCalls, contains(AuthProviderKind.google));
    expect(find.text('Hesabın açık'), findsOneWidget);
  });

  testWidgets('çıkış: hesap kartından tekrar giriş kartına dönülür',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);
    await _fill(tester, 'kaptan@ornek.com', 'sifre123');
    await _tapSheetButton(tester, 'Giriş yap');
    expect(find.text('Hesabın açık'), findsOneWidget);

    await _tapSheetButton(tester, 'Çıkış yap');
    expect(repo.loggedOut, isTrue);
    expect(find.text('Giriş yap veya kayıt ol'), findsOneWidget);
    expect(find.text('Hesabın açık'), findsNothing);
  });

  testWidgets('misafir oturumda (isGuest) giriş kartı gösterilmeye devam eder',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository(signInResult: testGuest);
    await tester.pumpWidget(_app(repo));
    await _openSheet(tester);
    await _fill(tester, 'kaptan@ornek.com', 'sifre123');
    await _tapSheetButton(tester, 'Giriş yap');
    // Misafir kimliği "hesap açık" sayılmaz — giriş kartı durur.
    expect(find.text('Giriş yap veya kayıt ol'), findsOneWidget);
  });

  // ŞİFREMİ UNUTTUM (kurucu talebi 2026-09-25): yalnız e-postayla çalışır,
  // sıfırlama sağlayıcıya iletilir, yeşil onay satırı görünür; sayfa kapanmaz.
  testWidgets('şifremi unuttum: e-posta ile sıfırlama gönderilir, onay görünür',
      (WidgetTester tester) async {
    final FakeResetGateway gw = FakeResetGateway();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        authGatewayProvider.overrideWithValue(gw),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AccountSection())),
      ),
    ));
    await _openSheet(tester);
    // Şifre alanı BOŞ bırakılır — sıfırlama şifre istemez.
    final Finder fields = find.descendant(
      of: find.byType(SignInSheetBody),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'kaptan@ornek.com');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('forgot-password')));
    await tester.pumpAndSettle();

    expect(gw.resetEmails.single, 'kaptan@ornek.com');
    expect(find.byKey(const ValueKey<String>('auth-info')), findsOneWidget);
    expect(find.textContaining('kaptan@ornek.com'), findsWidgets);
    expect(find.byType(SignInSheetBody), findsOneWidget); // sayfa açık kalır
  });

  testWidgets('şifremi unuttum: geçersiz e-postada doğrulama mesajı görünür',
      (WidgetTester tester) async {
    final FakeResetGateway gw = FakeResetGateway();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        authGatewayProvider.overrideWithValue(gw),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AccountSection())),
      ),
    ));
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey<String>('forgot-password')));
    await tester.pumpAndSettle();

    expect(gw.resetEmails, isEmpty);
    expect(find.byKey(const ValueKey<String>('auth-error')), findsOneWidget);
  });
}

/// Sıfırlama çağrısını yakalayan sahte kimlik köprüsü.
class FakeResetGateway implements AuthGateway {
  final List<String> resetEmails = <String>[];

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<String> obtainIdToken(AuthProviderKind kind) async => 'tok';

  @override
  Future<String> signInWithEmail(
          {required String email, required String password}) async =>
      'tok';

  @override
  Future<String> registerWithEmail(
          {required String email, required String password}) async =>
      'tok';

  @override
  Future<void> signOutProvider() async {}

  @override
  String? get currentEmail => null;
}
