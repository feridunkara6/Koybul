import 'package:dockly_api/dockly_api.dart' show GeoPoint, LocationSummary;
import 'package:dockly_mobile/core/origin_provider.dart';
import 'package:dockly_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/launch/domain/launch_store.dart';
import 'package:dockly_mobile/features/launch/presentation/launch_gate.dart';
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:dockly_mobile/features/search/application/search_controller.dart';
import 'package:dockly_mobile/features/splash/presentation/splash_screen.dart'
    show appReadyProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/launch_fakes.dart';
import '../../support/location_fakes.dart';
import '../../support/search_fakes.dart';
import '../../support/welcome_fakes.dart';

Widget _app(
  FakeLaunchStore store, {
  FakeBoatStorage? boatStorage,
  FakeLocationService? location,
  FakeSearchGateway? search,
}) {
  return ProviderScope(
    overrides: <Override>[
      launchStoreProvider.overrideWithValue(store),
      boatStorageProvider.overrideWithValue(boatStorage ?? FakeBoatStorage()),
      // CI DERSİ: konum akışına dokunan HER test sahte konum servisi kullanır
      // (gerçek eklenti test ortamında sonsuza dek bekler).
      locationServiceProvider
          .overrideWithValue(location ?? FakeLocationService(null)),
      // Bağlı marina seçimi MEVCUT arama ekranını kullanır — sahte ağ geçidi.
      searchGatewayProvider.overrideWithValue(search ?? FakeSearchGateway()),
      searchDebounceProvider.overrideWithValue(Duration.zero),
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

/// AÇILIŞ AKIŞI testleri — FAZ 1'de kısaltıldı (5 ekran → 3):
/// karşılama → ölçüler → KONUM ÖN-İZNİ → harita.
/// Bölge sorusu yalnız konum gelmezse çıkar (izin varken cevabı zaten
/// kullanılmıyordu). Tekne tipi sorusu tamamen kaldırıldı (cevabı hiçbir
/// yerde okunmuyordu).
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

  testWidgets('TAM AKIŞ (konum yok): karşılama → ölçüler → konum ön-izni → '
      'bölge → harita; cevaplar Teknem modeline ve harita odağına yazılır', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    await tester.pumpWidget(_app(store, boatStorage: boatStorage));
    await tester.pumpAndSettle();

    // Karşılama → ÖLÇÜLER (artık ilk soru bu; tekne tipi kaldırıldı).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    expect(find.text('Nasıl bir tekneyle geziyorsun?'), findsNothing);
    expect(find.text('Teknenin ölçüleri?'), findsOneWidget);
    expect(store.savedStep, 1);
    // Varsayılanlar tipten değil sabitten gelir (12 m / 1.8 m).
    expect(find.text('12 m'), findsOneWidget);
    expect(find.text('1.8 m'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));

    // KONUM ÖN-İZNİ.
    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    expect(store.savedStep, 2);

    // "Şimdilik bölgemle devam" → BÖLGE sorusu (harita bir yeri göstermeli).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-skip')));
    expect(find.text('En çok nerede geziyorsun?'), findsOneWidget);
    expect(find.text('KABUK'), findsNothing);
    expect(store.savedStep, 3);

    // Bodrum–Gökova seç → "Haritayı aç" → harita.
    await _tapVisible(tester, find.byKey(const ValueKey<String>('region-2')));
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));
    expect(find.text('KABUK'), findsOneWidget);
    expect(store.done, isTrue);
    expect(store.markCount, 1);
    expect(store.savedStep, 0);

    // Tekne TEK gerçek kaynağa yazıldı (tip sorulmadı → null).
    expect(boatStorage.boat, isNotNull);
    expect(boatStorage.boat!.lengthM, 12);
    expect(boatStorage.boat!.draftM, 1.8);
    expect(boatStorage.boat!.typeId, isNull);

    // Bölge odağı: Gökova, körfez ölçeği (zoom 9).
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.zoom, 9);
    expect(focus.point.lat, closeTo(36.99, 0.01));
  });

  testWidgets('İZİN VERİLİRSE bölge HİÇ sorulmaz — akış 2 soruda biter',
      (WidgetTester tester) async {
    // Faz 1'in asıl kazancı bu yol: eski kodda bölge sorulup cevap ÇÖPE
    // ATILIYORDU (konum varken uygulanmıyordu). Artık hiç sorulmuyor.
    final FakeLaunchStore store = FakeLaunchStore();
    await tester.pumpWidget(_app(
      store,
      location: FakeLocationService(const GeoPoint(lat: 36.55, lon: 28.05)),
    ));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-use')));

    expect(find.text('En çok nerede geziyorsun?'), findsNothing);
    expect(find.text('KABUK'), findsOneWidget);
  });

  testWidgets('E6 "Konumumu kullan" (izin VERİLDİ): konum alınır, kamera '
      'konuma iner — bölge odağı konumu EZMEZ', (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeLocationService location =
        FakeLocationService(const GeoPoint(lat: 36.55, lon: 28.05));
    await tester.pumpWidget(_app(store, location: location));
    await tester.pumpAndSettle();

    // Hızlı yol: soruları atla → konum ön-izni.
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

  testWidgets('İZİN REDDEDİLDİ: suçlama yok — bölge sorulur, sonra harita',
      (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore(savedStep: 2);
    final FakeLocationService location = FakeLocationService(null);
    await tester.pumpWidget(_app(store, location: location));
    await tester.pumpAndSettle();

    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-use')));

    expect(location.calls, 1);
    // Konum gelmedi → harita bir yeri göstermek zorunda; onu ancak kullanıcı
    // bilir. Akış kilitlenmez, bölge sorusuna düşer.
    expect(find.text('En çok nerede geziyorsun?'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-skip-all')));
    expect(find.text('KABUK'), findsOneWidget);
    expect(store.done, isTrue);
  });

  testWidgets('SORULARI ATLA: niyet TAŞINIR — bölge bir daha sorulmaz',
      (WidgetTester tester) async {
    // İnceleme bulgusu: "atla" diyene, konum ekranından sonra ÜÇÜNCÜ bir
    // soru çıkarmak sözden dönmektir. Konum bir soru değil, izin — o sorulur.
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    await tester.pumpWidget(_app(store, boatStorage: boatStorage));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    await _tapVisible(
        tester, find.byKey(const ValueKey<String>('launch-skip-all')));

    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-skip')));

    // Doğrudan harita — bölge sorusu ÇIKMAZ.
    expect(find.text('En çok nerede geziyorsun?'), findsNothing);
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
    await tester.pumpWidget(_app(FakeLaunchStore(savedStep: 1)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('launch-welcome')), findsNothing);
    expect(find.text('Teknenin ölçüleri?'), findsOneWidget);
  });

  testWidgets('BOZUK/İLERİ adım değeri boş ekrana düşürmez', (
    WidgetTester tester,
  ) async {
    // Akış Faz 1'de kısaldı. Eski numaralar depolama anahtarı sürümlendiği
    // için hiç okunmaz; yine de aralık dışı bir değer gelirse kullanıcı boş
    // ekranda kalmamalı — son geçerli koda kırpılır.
    await tester.pumpWidget(_app(FakeLaunchStore(savedStep: 99)));
    await tester.pumpAndSettle();

    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
  });

  testWidgets('ATLA niyeti uygulama kapansa bile yaşar (cihaza yazılır)', (
    WidgetTester tester,
  ) async {
    // "Soruları atla" dedikten sonra uygulamayı kapatıp açan kullanıcıya,
    // konum ekranından sonra bölge sorusu ÇIKMAMALI. Niyet 4 koduyla cihaza
    // yazılıyor; burada o kodla yeniden başlatılıyoruz.
    final FakeLaunchStore store = FakeLaunchStore(savedStep: 4);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-skip')));
    expect(find.text('En çok nerede geziyorsun?'), findsNothing);
    expect(find.text('KABUK'), findsOneWidget);
  });

  testWidgets('ATLA cihaza 4 olarak yazılır (ekran 2, niyet dahil)', (
    WidgetTester tester,
  ) async {
    final FakeLaunchStore store = FakeLaunchStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    await _tapVisible(
        tester, find.byKey(const ValueKey<String>('launch-skip-all')));

    expect(find.text('Haritayı sana göre açalım'), findsOneWidget);
    expect(store.savedStep, 4);
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
  // TEKNE ADI + BAĞLI MARİNA (kullanıcı isteği 2026-08): ölçüler ekranında
  // iki isteğe bağlı alan. Marina seçilirse bölge sorusu ATLANIR ve harita
  // marina çevresinde açılır; ad ve marina Teknem modeline yazılır.
  // ===========================================================================

  testWidgets('AD + MARİNA verilirse: bölge sorulmaz, tekneye yazılır, '
      'harita marina çevresine odaklanır', (WidgetTester tester) async {
    final FakeLaunchStore store = FakeLaunchStore();
    final FakeBoatStorage boatStorage = FakeBoatStorage();
    final FakeSearchGateway search = FakeSearchGateway(
      // sampleSummary konumu: lat 36.75, lon 28.93 (odak beklentisiyle aynı).
      results: <LocationSummary>[sampleSummary('dm1', 'D-Marin Göcek')],
    );
    await tester.pumpWidget(
        _app(store, boatStorage: boatStorage, search: search));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-start')));
    // Tekne adı yaz.
    await tester.enterText(
        find.byKey(const ValueKey<String>('launch-boat-name')), 'Martı');
    // Marina seç: arama ekranı açılır, sonuç seçilir, geri dönülür.
    await _tapVisible(
        tester, find.byKey(const ValueKey<String>('launch-marina-pick')));
    await tester.enterText(find.byType(TextField).first, 'göcek');
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('D-Marin Göcek'));
    // Ölçüler ekranına dönüldü; seçim ve kazanç cümlesi görünür.
    expect(find.text('D-Marin Göcek'), findsOneWidget);
    expect(find.textContaining('çevresinde açarız'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-q-cta')));
    // Konum ön-izni → izinsiz devam: bölge SORULMAZ (marina cevabı yeter).
    await _tapVisible(tester, find.byKey(const ValueKey<String>('launch-loc-skip')));
    expect(find.text('En çok nerede geziyorsun?'), findsNothing);
    expect(find.text('KABUK'), findsOneWidget);

    // Tekne kaydı: ad + marina.
    expect(boatStorage.boat, isNotNull);
    expect(boatStorage.boat!.name, 'Martı');
    expect(boatStorage.boat!.homeMarina, isNotNull);
    expect(boatStorage.boat!.homeMarina!.name, 'D-Marin Göcek');
    expect(boatStorage.boat!.homeMarina!.lat, closeTo(36.75, 0.001));

    // Harita odağı: marina çevresi (zoom 11 — bölgeden yakın, Konumum'dan geniş).
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.zoom, 11);
    expect(focus.point.lat, closeTo(36.75, 0.001));
    expect(focus.point.lon, closeTo(28.93, 0.001));
  });

  testWidgets('DÖNEN kullanıcı + kayıtlı marina: harita açılışta marina '
      'çevresine odaklanır (GPS yokken)', (WidgetTester tester) async {
    final FakeBoatStorage boatStorage = FakeBoatStorage(
      boat: const MyBoat(
        lengthM: 11,
        name: 'Martı',
        homeMarina:
            HomeMarina(id: 'dm1', name: 'D-Marin Göcek', lat: 36.75, lon: 28.93),
      ),
    );
    await tester.pumpWidget(_app(
      FakeLaunchStore(done: true),
      boatStorage: boatStorage,
    ));
    await tester.pumpAndSettle();

    expect(find.text('KABUK'), findsOneWidget);
    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.zoom, 11);
    expect(focus.point.lat, closeTo(36.75, 0.001));
  });

  testWidgets('DÖNEN kullanıcı + marinasız tekne: açılış odağı KURULMAZ',
      (WidgetTester tester) async {
    final FakeBoatStorage boatStorage =
        FakeBoatStorage(boat: const MyBoat(lengthM: 11));
    await tester.pumpWidget(_app(
      FakeLaunchStore(done: true),
      boatStorage: boatStorage,
    ));
    await tester.pumpAndSettle();

    final ProviderContainer c =
        ProviderScope.containerOf(tester.element(find.text('KABUK')));
    expect(c.read(mapFocusProvider), isNull);
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
