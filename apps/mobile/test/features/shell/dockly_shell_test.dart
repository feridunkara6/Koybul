import 'package:dockly_mobile/features/logbook/application/logbook_controller.dart';
import 'package:dockly_mobile/features/logbook/presentation/logbook_screen.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:dockly_mobile/features/search/presentation/search_screen.dart';
import 'package:dockly_mobile/features/shell/presentation/dockly_shell.dart';
import 'package:dockly_mobile/features/welcome/presentation/welcome_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_map_surface.dart';
import '../../support/logbook_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/welcome_fakes.dart';

Widget _app() {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      // Karşılama sorusu bu testlerin konusu değil — "soruldu" kabul edilir.
      welcomeStoreProvider.overrideWithValue(FakeWelcomeStore(shown: true)),
      // Tanıtım (2026-08) da konu dışı — "görüldü" kabul edilir.
      onboardingStoreProvider.overrideWithValue(doneOnboardingStore()),
      // Günlük sekmesi (2026-08): gerçek SharedPreferences yerine bellek içi.
      logbookStoreProvider.overrideWithValue(FakeLogbookStore()),
    ],
    child: const MaterialApp(home: DocklyShell()),
  );
}

void main() {
  testWidgets('6 sekmeli alt menü; açılışta Keşfet (harita) aktif',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(6));
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    // Keşfet açık → sahte harita yüzeyi pin çizer.
    expect(find.byKey(const ValueKey<String>('pin-loc-1')), findsOneWidget);
  });

  testWidgets('sekmeye dokununca seçili sekme değişir', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Kayıtlarım')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
  });

  testWidgets('GÜNLÜK sekmesi (kullanıcı isteği 2026-08): Kayıtlarım\'ın '
      'yanından tek dokunuşla Kaptanın Günlüğü açılır', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Günlük')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    expect(find.byType(LogbookScreen), findsOneWidget);

    // Kayan sekmeler yerli yerinde: Profil artık 5. dizinde.
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Profil')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 5);
  });

  testWidgets('PERF: sekmeler ilk ziyarete kadar KURULMAZ; ziyaretten sonra canlı kalır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Açılışta yalnız Keşfet kurulu — Arama ekranı ağaçta yok.
    expect(find.byType(SearchScreen, skipOffstage: false), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Arama')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen, skipOffstage: false), findsOneWidget);

    // Keşfet'e dönünce Arama KURULU kalır (durumu korunur).
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Keşfet')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen, skipOffstage: false), findsOneWidget);
  });
}
