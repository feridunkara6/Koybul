import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/core/origin_provider.dart';
import 'package:dockly_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/launch/domain/launch_store.dart';
import 'package:dockly_mobile/features/launch/presentation/launch_gate.dart';
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:dockly_mobile/features/splash/presentation/splash_screen.dart'
    show appReadyProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/launch_fakes.dart';
import '../../support/location_fakes.dart';
import '../../support/welcome_fakes.dart';

Widget _app(
  FakeLaunchStore store, {
  FakeBoatStorage? boatStorage,
  FakeLocationService? location,
}) {
  return ProviderScope(
    overrides: <Override>[
      launchStoreProvider.overrideWithValue(store),
      boatStorageProvider.overrideWithValue(boatStorage ?? FakeBoatStorage()),
      // CI DERSİ: konum akışına dokunan HER test sahte konum servisi kullanır
      // (gerçek eklenti test ortamında sonsuza dek bekler).
      locationServiceProvider
          .overrideWithValue(location ?? FakeLocationService(null)),
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

/// AÇILIŞ AKIŞI testleri — E2–E6 (onaylı tasarım 2026-08, Paket 3):
/// karşılama → tekne tipi → ölçüler → bölge → KONUM ÖN-İZNİ → harita.
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

  testWidgets('TAM AKIŞ: sorular → E6 "bölgemle devam" → harita; cevaplar '
      'Teknem modeline, bölge harita odağına yazılır', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    await tester.pumpWidget(_app(store, boatStorage: boatStorage));
    await tester.pumpAndSettle();

    // E2 → E3 (adım cihaza işlenir).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    expect(find.text('Nasıl bir tekneyle geziyorsun?'), findsOneWidget);
    expect(store.savedStep, 1);

    // Yelkenli seç → Devam (seçim otomatik ilerletmez — onaylı kural).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('boat-type-sail')));
    expect(find.text('Nasıl bir tekneyle geziyorsun?'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));

    // E4: yelkenli varsayılanları (12 m / 1.8 m); Devam.
    expect(find.text('Teknenin ölçüleri?'), findsOneWidget);
    expect(find.text('12 m'), findsOneWidget);
    expect(find.text('1.8 m'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));

    // E5: Bodrum–Gökova seç → "Haritayı aç" → E6 KONUM ÖN-İZNİ (harita değil!).
    expect(find.text('En çok nerede geziyorsun?'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('region-2')));
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));
    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    expect(find.text('KABUK'), findsNothing);
    expect(store.savedStep, 4);

    // E6: izinsiz devam → harita; bölge odağı uygulanır, izin penceresi YOK.
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-skip')));
    expect(find.text('KABUK'), findsOneWidget);
    expect(store.done, isTrue);
    expect(store.markCount, 1);
    expect(store.savedStep, 0);

    // Tekne TEK gerçek kaynağa yazıldı.
    expect(boatStorage.boat, isNotNull);
    expect(boatStorage.boat!.lengthM, 12);
    expect(boatStorage.boat!.draftM, 1.8);
    expect(boatStorage.boat!.typeId, 'sail');

    // Bölge odağı: Gökova, körfez ölçeği (zoom 9).
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.zoom, 9);
    expect(focus.point.lat, closeTo(36.99, 0.01));
  });

  testWidgets('E6 "Konumumu kullan" (izin VERİLDİ): konum alınır, kamera '
      'konuma iner — bölge odağı konumu EZMEZ', (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeLocationService location =
        FakeLocationService(const GeoPoint(lat: 36.55, lon: 28.05));
    await tester.pumpWidget(_app(store, location: location));
    await tester.pumpAndSettle();

    // Hızlı yol: soruları atla → E6.
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-skip-all')));
    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-use')));
    expect(find.text('KABUK'), findsOneWidget);
    expect(location.calls, 1); // izin akışı tetiklendi
    expect(store.done, isTrue);

    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    expect(c.read(devicePositionProvider)?.lat, 36.55);
    // Odak KONUMA gitti (locateMe üretti; zoom yüzey varsayılanı → null).
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.point.lat, closeTo(36.55, 0.001));
    expect(focus.zoom, isNull);
  });

  testWidgets('E6 izin REDDEDİLDİ: sessizce devam — kabuk açılır, suçlama yok',
      (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore(savedStep: 4);
    final FakeLocationService location = FakeLocationService(null);
    await tester.pumpWidget(_app(store, location: location));
    await tester.pumpAndSettle();

    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-use')));

    expect(location.calls, 1);
    expect(find.text('KABUK'), findsOneWidget); // akış kilitlenmedi
    expect(store.done, isTrue);
  });

  testWidgets('SORULARI ATLA: E3\'te atla → E6\'ya gider (haritaya değil); '
      'tekne yazılmaz, bölge odağı uygulanmaz', (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    await tester.pumpWidget(_app(store, boatStorage: boatStorage));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    await _tapVisible(
        tester, find.byKey(const ValueKey<String>('launch-skip-all')));

    // Onaylı akış: Atla → E6 (konum sorusu atlanmaz, sorular atlanır).
    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-skip')));

    expect(find.text('KABUK'), findsOneWidget);
    expect(store.done, isTrue);
    expect(boatStorage.boat, isNull); // uydurma tekne kaydı yok
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    expect(c.read(mapFocusProvider), isNull); // seçilmemiş bölge uydurulamaz
  });

  testWidgets('YARIM KALAN akış kaldığı adımdan sürer (onb.v2.step)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(FakeLaunchStore(savedStep: 2)));
    await tester.pumpAndSettle();

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

  // ===========================================================================
  // FAZ 1 (hız): kapı iki cihaz okumasını AYNI ANDA yapıyor ve bitince açılış
  // ekranına "hazır" diyor. İki yeni sözleşme:
  // ===========================================================================

  testWidgets('karar verilince AÇILIŞ EKRANINA hazır sinyali gider',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLaunchStore(done: true)));
    await tester.pumpAndSettle();

    expect(find.text('KABUK'), findsOneWidget);
    final ProviderContainer c = ProviderScope.containerOf(
      tester.element(find.byType(LaunchGate)),
      listen: false,
    );
    expect(c.read(appReadyProvider), isTrue);
  });

  testWidgets('depo FIRLATIRSA boş ekranda kilitlenmez — haritaya girilir',
      (WidgetTester tester) async {
    // Paralelleştirmenin yan etkisi: `step()` artık dönen kullanıcıda da
    // çağrılıyor. Fırlatırsa eski kodda `_done` sonsuza dek null kalır ve
    // kullanıcı boş bir ekranda kalırdı. Sözleşme (LaunchStore): bozuk
    // depoda "tamamlandı" varsayılır.
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        launchStoreProvider.overrideWithValue(_ThrowingLaunchStore()),
        boatStorageProvider.overrideWithValue(FakeBoatStorage()),
        locationServiceProvider.overrideWithValue(FakeLocationService(null)),
      ],
      child: const MaterialApp(home: LaunchGate(child: Text('KABUK'))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('KABUK'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsNothing);
    final ProviderContainer c = ProviderScope.containerOf(
      tester.element(find.byType(LaunchGate)),
      listen: false,
    );
    expect(c.read(appReadyProvider), isTrue, reason: 'açılış yine çekilmeli');
  });
}

/// Bozuk cihaz deposu benzetimi (gerçek depo yutar; bu test kalkanı sınar).
class _ThrowingLaunchStore implements LaunchStore {
  @override
  Future<bool> isDone() async => throw StateError('bozuk depo');

  @override
  Future<void> markDone() async {}

  @override
  Future<int> step() async => throw StateError('bozuk depo');

  @override
  Future<void> setStep(int value) async {}
}
