import 'package:dockly_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/launch/presentation/launch_gate.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/launch_fakes.dart';
import '../../support/welcome_fakes.dart';

Widget _app(FakeLaunchStore store, {FakeBoatStorage? boatStorage}) {
  return ProviderScope(
    overrides: <Override>[
      launchStoreProvider.overrideWithValue(store),
      boatStorageProvider.overrideWithValue(boatStorage ?? FakeBoatStorage()),
    ],
    child: const MaterialApp(
      home: LaunchGate(child: Text('KABUK')),
    ),
  );
}

/// Görünür olmayabilen öğeye güvenli dokunuş (CI dersi: 800×600 test ekranı).
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// AÇILIŞ AKIŞI testleri — E2–E5 (onaylı tasarım 2026-08, Paket 2):
/// karşılama → tekne tipi → ölçüler → bölge → harita; "Soruları atla" kalan
/// tümünü atlar; cevaplar Teknem modeline ve harita odağına akar.
void main() {
  testWidgets('İLK açılış: karşılama görünür, kabuk görünmez', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(FakeLaunchStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsOneWidget);
    expect(find.text('Keşfe başla'), findsOneWidget);
    expect(find.text("Ege ve Akdeniz'in koyları"), findsOneWidget);
    expect(find.text('KABUK'), findsNothing);
  });

  testWidgets('TAM AKIŞ: karşılama → tip → ölçüler → bölge → harita; '
      'cevaplar Teknem modeline ve harita odağına yazılır', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    await tester.pumpWidget(_app(store, boatStorage: boatStorage));
    await tester.pumpAndSettle();

    // E2 → E3 (adım cihaza işlenir — yarım kalan akış kaldığı yerden sürer).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    expect(find.text('Nasıl bir tekneyle geziyorsun?'), findsOneWidget);
    expect(store.savedStep, 1);

    // Yelkenli seç → Devam. Seçim otomatik İLERLETMEZ (onaylı kural).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('boat-type-sail')));
    expect(find.text('Nasıl bir tekneyle geziyorsun?'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));

    // E4: yelkenli varsayılanları (12 m / 1.8 m) ekranda; Devam.
    expect(find.text('Teknenin ölçüleri?'), findsOneWidget);
    expect(find.text('12 m'), findsOneWidget);
    expect(find.text('1.8 m'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));

    // E5: Bodrum–Gökova seç → Haritayı aç.
    expect(find.text('En çok nerede geziyorsun?'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('region-2')));
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));

    // Harita açıldı; karar kalıcı, adım izi temiz.
    expect(find.text('KABUK'), findsOneWidget);
    expect(store.done, isTrue);
    expect(store.markCount, 1);
    expect(store.savedStep, 0);

    // Tekne TEK gerçek kaynağa yazıldı (Profil → Teknem ile aynı depo).
    expect(boatStorage.boat, isNotNull);
    expect(boatStorage.boat!.lengthM, 12);
    expect(boatStorage.boat!.draftM, 1.8);
    expect(boatStorage.boat!.typeId, 'sail');

    // Bölge, haritanın açılış odağı oldu (körfez ölçeği zoom 9).
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.zoom, 9);
    expect(focus.point.lat, closeTo(36.99, 0.01));
  });

  testWidgets('SORULARI ATLA: E3\'te atla → doğrudan harita; tekne yazılmaz, '
      'bölge odağı uygulanmaz', (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    await tester.pumpWidget(_app(store, boatStorage: boatStorage));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    await _tapVisible(
        tester, find.byKey(const ValueKey<String>('launch-skip-all')));

    expect(find.text('KABUK'), findsOneWidget);
    expect(store.done, isTrue);
    expect(boatStorage.boat, isNull); // uydurma tekne kaydı yok
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    expect(c.read(mapFocusProvider), isNull); // uydurma bölge odağı yok
  });

  testWidgets('YARIM KALAN akış kaldığı adımdan sürer (onb.v2.step)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(FakeLaunchStore(savedStep: 2)));
    await tester.pumpAndSettle();

    // Karşılama DEĞİL, doğrudan E4 (ölçüler).
    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsNothing);
    expect(find.text('Teknenin ölçüleri?'), findsOneWidget);
  });

  testWidgets('DÖNEN kullanıcı: hiçbir açılış ekranı görünmez, doğrudan kabuk', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore(done: true, savedStep: 3);
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

    await _tapVisible(
        tester, find.byKey(const ValueKey<String>('launch-signin')));
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(store.done, isFalse); // giriş sayfasına gitmek karar değildir

    // Geri dön (giriş sayfasında AppBar yok → Navigator ile).
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
