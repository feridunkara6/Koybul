import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_screen.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/deck/presentation/deck_screen.dart';
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/logbook/application/logbook_controller.dart';
import 'package:dockly_mobile/features/logbook/presentation/logbook_screen.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/shell/presentation/dockly_shell.dart';
import 'package:dockly_mobile/features/today/presentation/today_screen.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:dockly_mobile/features/welcome/presentation/welcome_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';
import '../../support/detail_fakes.dart';
import '../../support/fake_map_surface.dart';
import '../../support/logbook_fakes.dart';
import '../../support/maintenance_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/saved_routes_fakes.dart';
import '../../support/trip_fakes.dart';
import '../../support/weather_fakes.dart';
import '../../support/welcome_fakes.dart';

Widget _app() {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      welcomeStoreProvider.overrideWithValue(FakeWelcomeStore(shown: true)),
      onboardingStoreProvider.overrideWithValue(doneOnboardingStore()),
      // v2.0 sekmeleri: gerçek depolar/ağ yerine bellek içi sahteler.
      savedRoutesStoreProvider.overrideWithValue(FakeSavedRoutesStore()),
      logbookStoreProvider.overrideWithValue(FakeLogbookStore()),
      tripStoreProvider.overrideWithValue(FakeTripStore()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      // Bugün sekmesi: harita açılışta origin yazdığı için akıllı öneri
      // bölümü kurulur — motor asla gerçek ağa çıkmasın (inceleme dersi).
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      locationDetailGatewayProvider.overrideWithValue(FakeLocationDetailGateway()),
      // Bugün sekmesi: "Yakında paylaşılanlar" da ağ geçidi ister.
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      // Teknem sekmesi: bakım kayıtları bellek içi sahte depodan gelir.
      maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
    ],
    child: const MaterialApp(home: DocklyShell()),
  );
}

/// v2.0 KABUK testleri (kurucu onayı 2026-08): 5 sekme —
/// Keşfet · Bugün · Defter · Teknem · Profil.
void main() {
  testWidgets('5 sekmeli alt menü; açılışta Keşfet (harita) aktif',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.byKey(const ValueKey<String>('pin-loc-1')), findsOneWidget);
  });

  testWidgets('BUGÜN sekmesi: kontrol listesi kartı gelir '
      '(hava kartı veri yoksa kendini gizler)', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Bugün')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('today-checklist')), findsOneWidget);
  });

  testWidgets('BUGÜN → KEŞFET dönüşü: harita KAYBOLMAZ (beyaz ekran '
      'regresyonu, saha hatası 2026-08)', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // Ölçüm HARİTA YÜZEYİNDEN alınır: hata tam olarak yüzeyi 0×0'a
    // düşürüyordu (Scaffold'un boyu değişmiyordu — o yüzden Scaffold'u
    // ölçmek hatayı YAKALAMAZ, inceleme dersi).
    expect(tester.getSize(find.byType(FakeMapSurface)).height,
        greaterThan(100));

    // Bugün'e git (haritadaki davet kartı emekli olur) ve geri dön.
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Bugün')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Keşfet')),
    );
    await tester.pumpAndSettle();

    // Harita yüzeyi hâlâ EKRANI KAPLIYOR olmalı. (Hata: Stack'e eklenen
    // konumlandırılmamış boş bir çocuk, yığını 0×0'a düşürüp haritayı
    // tamamen gizliyordu.)
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.byKey(const ValueKey<String>('pin-loc-1')), findsOneWidget);
    final Size surface = tester.getSize(find.byType(FakeMapSurface));
    expect(surface.height, greaterThan(100));
    expect(surface.width, greaterThan(100));
    // Davet kartı Bugün'e gidildikten sonra emekli olur (ısrar etmez).
    expect(find.byKey(const ValueKey<String>('today-invite')), findsNothing);
  });

  testWidgets('DEFTER sekmesi: Seyirler açılır; Rotalarım ve Notlar '
      'segmentleri çalışır', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Defter')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    expect(find.byType(DeckScreen), findsOneWidget);
    // Seyir yok → dürüst boş durum (varsayılan segment Seyirler; metin
    // v2.1 "Planla → Gerçekleşti" akışını anlatır).
    expect(find.textContaining('Henüz sefer yok'), findsOneWidget);

    await tester.tap(find.text('Rotalarım'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz kayıtlı rota yok'), findsOneWidget);

    await tester.tap(find.text('Notlar'));
    await tester.pumpAndSettle();
    expect(find.byType(LogbookBody), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deck-note-new')), findsOneWidget);
  });

  testWidgets('TEKNEM sekmesi: tekne yokken tanımlama daveti',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Teknem')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    expect(find.byType(BoatScreen), findsOneWidget);
    expect(find.text('Tekneni tanımla'), findsOneWidget);

    // Profil son sırada (dizin 4).
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Profil')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 4);
  });
}
