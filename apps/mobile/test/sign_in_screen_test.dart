import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_gateway.dart';
import 'package:dockly_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';

Future<void> _pump(WidgetTester tester, FakeAuthRepository repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SignInScreen()),
    ),
  );
}

void main() {
  testWidgets('S-03: yalnız ÇALIŞAN seçenekler görünür (UX 2026-08)', (tester) async {
    await _pump(tester, FakeAuthRepository());
    expect(find.text('Apple ile devam et'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('Misafir olarak gez'), findsOneWidget);
    // "Çok yakında" duvarı KALDIRILDI: çalışmayan seçenek gösterilmez.
    expect(find.text('E-posta ile devam et'), findsNothing);
    expect(find.text('Telefon ile devam et'), findsNothing);
  });

  testWidgets('Google butonu repo.signIn(google) çağırır', (tester) async {
    final repo = FakeAuthRepository();
    await _pump(tester, repo);
    await tester.tap(find.text('Google ile devam et'));
    await tester.pump();
    expect(repo.signInCalls, contains(AuthProviderKind.google));
  });

  testWidgets('misafir seçeneği repo.signIn(guest) çağırır', (tester) async {
    final repo = FakeAuthRepository(signInResult: testGuest);
    await _pump(tester, repo);
    await tester.tap(find.text('Misafir olarak gez'));
    await tester.pump();
    expect(repo.signInCalls, contains(AuthProviderKind.guest));
  });

  testWidgets('giriş hatası → SnackBar ile AppFailure mesajı', (tester) async {
    final repo = FakeAuthRepository(
      signInError: const UnexpectedFailure('Giriş sağlayıcısı henüz hazır değil.'),
    );
    await _pump(tester, repo);
    await tester.tap(find.text('Apple ile devam et'));
    await tester.pump(); // future başlar
    await tester.pump(); // snackbar görünür
    expect(find.text('Giriş sağlayıcısı henüz hazır değil.'), findsOneWidget);
  });

}
