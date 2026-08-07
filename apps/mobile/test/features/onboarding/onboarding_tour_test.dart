import 'package:dockly_mobile/features/favorites/application/favorites_controller.dart';
import 'package:dockly_mobile/features/logbook/application/logbook_controller.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/presentation/map_screen.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/onboarding/domain/onboarding_store.dart';
import 'package:dockly_mobile/features/onboarding/presentation/tour_targets.dart';
import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/application/sea_route_engine.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:dockly_mobile/features/shell/presentation/dockly_shell.dart';
import 'package:dockly_mobile/features/welcome/presentation/welcome_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_map_surface.dart';
import '../../support/favorites_fakes.dart';
import '../../support/logbook_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/saved_routes_fakes.dart';
import '../../support/weather_fakes.dart';
import '../../support/welcome_fakes.dart';

/// Örnek rota için sahte motor (tur v5): iki nokta arasını dolaysız döner.
class _FakeRouteEngine implements SeaRouteEngine {
  @override
  Future<SeaRoutePlan?> route(GeoPoint from, GeoPoint to) async {
    return SeaRoutePlan(
      points: <GeoPoint>[from, to],
      distanceNm: 5,
      reachedGoal: true,
      viaSea: true,
    );
  }

  @override
  Future<SeaTrip?> trip(GeoPoint from, List<GeoPoint> stops) async {
    final SeaRoutePlan? leg = await route(from, stops.last);
    if (leg == null) return null;
    return SeaTrip(
      legs: <SeaRoutePlan>[leg],
      combined: combineTripLegs(<SeaRoutePlan>[leg]),
    );
  }

  @override
  Future<GeoPoint?> snapWater(GeoPoint p) async => p;
}

/// TUR v3 testleri KABUĞU (DocklyShell) pompalar: tur artık sekme
/// değiştirebildiği için kaplama kabuğun üstünde yaşar.
Widget _app(FakeOnboardingStore store) {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      onboardingStoreProvider.overrideWithValue(store),
      // Kabuk sekmeleri (tur gezer): gerçek depolar yerine bellek içi.
      welcomeStoreProvider.overrideWithValue(FakeWelcomeStore(shown: true)),
      favoritesStorageProvider.overrideWithValue(FakeFavoritesStorage()),
      savedRoutesStoreProvider.overrideWithValue(FakeSavedRoutesStore()),
      logbookStoreProvider.overrideWithValue(FakeLogbookStore()),
      // Örnek rota (tur v5): gerçek motor/ağ yerine sahteler.
      seaRouteEngineProvider.overrideWithValue(_FakeRouteEngine()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
    ],
    child: const MaterialApp(home: DocklyShell()),
  );
}

/// Sadece harita ekranı (ipucu balonu testleri — tur kapalı).
Widget _mapOnly(FakeOnboardingStore store) {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      onboardingStoreProvider.overrideWithValue(store),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

const ValueKey<String> _pinKey = ValueKey<String>('pin-loc-1');
const ValueKey<String> _spotKey = ValueKey<String>('onb-tour-spot');

int _tab(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(DocklyShell)),
    ).read(shellTabProvider);

Future<void> _advance(WidgetTester tester) async {
  await tester.tapAt(const Offset(40, 300));
  await tester.pumpAndSettle();
}

/// TANITIM TURU v3 testleri (kullanıcı isteği 2026-08): kartlar ilgili bölgeyi
/// SPOT + OKLA gösterir, gerektiğinde SAYFA DEĞİŞİR, dokundukça ilerler ve
/// son kart "Hazırsın" deyip Keşfet'e döner.
void main() {
  testWidgets('İLK açılış: kart 1 kendiliğinden görünür; dokununca ilerler',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsOneWidget);
    expect(find.text('Harita hazır, kaptan'), findsOneWidget);
    expect(store.data!.welcomeDone, isTrue); // karar anında işlendi
    expect(find.byKey(_spotKey), findsNothing); // hoş geldin: hedefsiz kart

    await _advance(tester);
    expect(find.text('Harita ve koylar'), findsOneWidget);

    // Kartın kendisine dokunmak da ilerletir.
    await tester.tap(find.text('Harita ve koylar'));
    await tester.pumpAndSettle();
    expect(find.text('Filtreler'), findsOneWidget);
  });

  testWidgets('OKLU ADIM (v3): "Filtreler" kartı hedefi spot ışığıyla gösterir',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _app(FakeOnboardingStore(data: const OnboardingData())));
    await tester.pumpAndSettle();

    await _advance(tester); // → harita ve koylar
    await _advance(tester); // → filtreler (hedef: üstteki çip şeridi)
    expect(find.text('Filtreler'), findsOneWidget);
    expect(find.byKey(_spotKey), findsOneWidget); // vurgu (delikli karartma)

    // "İleri" düğmesi de ilerletir (premium v4 — açık eylem düğmesi).
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(find.text('Konumum'), findsOneWidget);
  });

  testWidgets('Atla: kartlar kapanır, Keşfet\'e dönülür, bir daha açılmaz',
      (WidgetTester tester) async {
    final FakeOnboardingStore store =
        FakeOnboardingStore(data: const OnboardingData());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsNothing);
    expect(store.data!.welcomeDone, isTrue);
    expect(_tab(tester), 0);
  });

  testWidgets('SAYFA GEZİNTİSİ (v2.0): tur Defter ve Teknem sekmelerine '
      'uğrar; son kart "Hazırsın" der ve Keşfet\'e döner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _app(FakeOnboardingStore(data: const OnboardingData())));
    await tester.pumpAndSettle();
    final ProviderContainer c = ProviderScope.containerOf(
        tester.element(find.byType(DocklyShell)));

    // Adım 1 (işaretler): ÖRNEK koy işareti kendiliğinden seçilir.
    await _advance(tester);
    expect(c.read(mapControllerProvider).selectedPinId, 'loc-1');

    // Adım 2'ye geçince örnek seçim geri alınır.
    await _advance(tester);
    expect(c.read(mapControllerProvider).selectedPinId, isNull);

    // Adım 5 (deniz rotası): ÖRNEK ROTA motorla çizilir, adıyla görünür.
    await _advance(tester);
    await _advance(tester);
    await _advance(tester);
    expect(c.read(mapControllerProvider).route, isNotNull);
    expect(c.read(mapControllerProvider).routeLabel, 'Örnek rota');

    // Adım 6: örnek rota DURUR — bilgi kartı (çip) vurgulanır.
    await _advance(tester);
    expect(c.read(mapControllerProvider).route, isNotNull);
    expect(find.byKey(_spotKey), findsOneWidget);

    // Adım 7 (Defter): sekme 2 + ÖRNEK rozetli rota kartı; örnek rota
    // haritadan TEMİZLENİR (kalıcı hiçbir şey kalmaz).
    await _advance(tester);
    expect(_tab(tester), 2);
    expect(find.text('Örnek rota'), findsOneWidget);
    expect(find.text('ÖRNEK'), findsOneWidget);
    expect(c.read(mapControllerProvider).route, isNull);

    // Adım 8 (Teknem, v2.0): sekme 3 + tekne kimlik kartı (tekne yok →
    // dürüst tanımlama daveti görünür).
    await _advance(tester);
    expect(_tab(tester), 3);
    expect(find.text('Tekneni tanımla'), findsOneWidget);

    // → adım 9 (Hazırsın): Keşfet'e dönülür, kapanış kartı.
    await _advance(tester);
    expect(_tab(tester), 0);
    expect(find.text('Hazırsın, kaptan!'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget); // premium kapanış düğmesi

    // Son dokunuş turu bitirir; Keşfet'te kalınır, örnekler geride kalmaz.
    await _advance(tester);
    expect(find.text('Hazırsın, kaptan!'), findsNothing);
    expect(_tab(tester), 0);
    expect(c.read(mapControllerProvider).route, isNull);
    expect(c.read(mapControllerProvider).selectedPinId, isNull);
  });

  testWidgets('SAYFADAYKEN ATLA (v3): Teknem adımında Atla → tur kapanır ve '
      'Keşfet\'e dönülür', (WidgetTester tester) async {
    await tester.pumpWidget(
        _app(FakeOnboardingStore(data: const OnboardingData())));
    await tester.pumpAndSettle();

    for (int i = 0; i < 8; i++) {
      await _advance(tester); // adım 8 = Teknem (sekme 3)
    }
    expect(_tab(tester), 3);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byKey(_spotKey), findsNothing);
    expect(find.byKey(const ValueKey<String>('onb-tour-step-8')), findsNothing);
    expect(_tab(tester), 0); // ana ekrana dönüldü
    // Örnekler geride kalmaz (Atla ile de temizlik).
    final ProviderContainer c = ProviderScope.containerOf(
        tester.element(find.byType(DocklyShell)));
    expect(c.read(mapControllerProvider).route, isNull);
    expect(c.read(mapControllerProvider).selectedPinId, isNull);
  });

  testWidgets('İPUCU: ilk pin dokunuşunda koy kartı balonu; "Anladım" bir daha göstermez',
      (WidgetTester tester) async {
    final FakeOnboardingStore store = FakeOnboardingStore(
        data: const OnboardingData(welcomeDone: true)); // kartlar kapalı
    await tester.pumpWidget(_mapOnly(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsOneWidget);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
    expect(store.data!.seenHints, contains(kHintBottomCard)); // kalıcı

    // Kartı kapatıp yeniden aç — balon geri gelmez.
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
  });

  testWidgets('tanıtım görülmüşse hiçbir kaplama çıkmaz (mevcut akış bozulmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(doneOnboardingStore()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-tour-step-0')), findsNothing);
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('onb-hint-$kHintBottomCard')),
        findsNothing);
  });

  testWidgets('TELEFON DÜZENİ (kullanıcı isteği 2026-08): kart anlatılan yeri '
      'KAPATMAZ; tur baştan sona taşmadan yürür', (WidgetTester tester) async {
    // 390×844 mantıksal nokta (×3 piksel) — yaygın telefon ekranı.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        _app(FakeOnboardingStore(data: const OnboardingData())));
    await tester.pumpAndSettle();

    Future<void> next() async {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }

    // Adım 3'e ilerle (filtre çipleri — ekranın ÜSTÜNDE vurgulanır).
    await next();
    await next();
    expect(find.byKey(_spotKey), findsOneWidget);
    // Telefonda kart hedefin dibine yapışmaz, uzak uca kıyılanır —
    // vurgulanan çip şeridiyle ASLA çakışmaz.
    final Rect card = tester
        .getRect(find.byKey(const ValueKey<String>('onb-tour-card')));
    final Rect target = tester.getRect(find.byKey(tourKeyChips));
    expect(card.overlaps(target.inflate(9)), isFalse,
        reason: 'kart, ışıkla gösterilen bölgeyi kapatmamalı');

    // Kalan adımlar İleri düğmesiyle taşma/hata olmadan biter (taşma olsa
    // test kendiliğinden kırmızı olurdu).
    for (int i = 2; i < kTourStepCount - 1; i++) {
      await next();
    }
    expect(find.text('Hazırsın, kaptan!'), findsOneWidget);
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();
    expect(find.text('Hazırsın, kaptan!'), findsNothing);
  });
}
