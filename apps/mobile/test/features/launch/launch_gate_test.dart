import 'package:dockly_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:dockly_mobile/features/launch/presentation/launch_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/launch_fakes.dart';

Widget _app(FakeLaunchStore store) {
  return ProviderScope(
    overrides: <Override>[
      launchStoreProvider.overrideWithValue(store),
    ],
    child: const MaterialApp(
      home: LaunchGate(child: Text('KABUK')),
    ),
  );
}

/// AÇILIŞ KAPISI testleri — E2 karşılama (onaylı tasarım 2026-08, Paket 1):
/// ilk açılışta karşılama, "Keşfe başla" ile kalıcı karar, dönen kullanıcı
/// doğrudan kabuğa; "Giriş yap" akışı TAMAMLAMAZ.
void main() {
  testWidgets('İLK açılış: karşılama görünür, kabuk görünmez', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(FakeLaunchStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsOneWidget);
    expect(find.text('Keşfe başla'), findsOneWidget);
    expect(find.text("Ege ve Akdeniz'in koyları"), findsOneWidget);
    expect(find.text('Kayıt gerekmez — istediğin an hesap açabilirsin.'),
        findsOneWidget);
    expect(find.text('KABUK'), findsNothing);
  });

  testWidgets('"Keşfe başla": kabuğa geçilir ve karar CİHAZA işlenir', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // CI DERSİ: test ekranı 800×600 — alt öğeler ekran dışında kalabilir;
    // dokunmadan önce kaydırıp görünür yap (SingleChildScrollView var).
    await tester.ensureVisible(find.byKey(const ValueKey<String>('launch-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('launch-start')));
    await tester.pumpAndSettle();

    expect(find.text('KABUK'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsNothing);
    expect(store.done, isTrue);
    expect(store.markCount, 1);
  });

  testWidgets('DÖNEN kullanıcı: karşılama HİÇ görünmez, doğrudan kabuk', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore(done: true);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('KABUK'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsNothing);
    expect(store.markCount, 0); // tekrar yazılmaz
  });

  testWidgets('"Giriş yap": giriş sayfası açılır; akış TAMAMLANMAZ, '
      'dönüşte karşılama kaldığı yerde', (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // CI DERSİ: "Giriş yap" satırı 600 piksellik test ekranının hemen
    // altında (y≈607) — önce kaydır, sonra dokun; yoksa dokunuş boşa gider.
    await tester.ensureVisible(find.byKey(const ValueKey<String>('launch-signin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('launch-signin')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(store.done, isFalse); // giriş sayfasına gitmek karar değildir

    // Geri dön (giriş sayfasında AppBar yok → Navigator ile) → karşılama
    // hâlâ orada (onaylı E2 kuralı).
    final NavigatorState nav = tester.state(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsOneWidget);
    expect(find.text('KABUK'), findsNothing);
  });

  testWidgets('üç değer satırı ve iki renkli başlık ekranda', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(FakeLaunchStore()));
    await tester.pumpAndSettle();

    expect(find.text('artık cebinde'), findsOneWidget);
    expect(find.text('Koylar, marinalar, derinlik ve rüzgâr bilgisi'),
        findsOneWidget);
    expect(find.text('Karadan değil denizden giden akıllı rotalar'),
        findsOneWidget);
    expect(find.text('Denizcilerin yorumları ve gerçek deneyimleri'),
        findsOneWidget);
  });
}
