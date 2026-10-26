import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/favorites/application/favorites_controller.dart';
import 'package:dockly_mobile/features/favorites/domain/favorite_location.dart';
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
import 'package:dockly_mobile/features/today/application/getting_started_controller.dart';
import 'package:dockly_mobile/features/today/presentation/getting_started_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/favorites_fakes.dart';
import '../../support/getting_started_fakes.dart';
import '../../support/saved_routes_fakes.dart';
import '../../support/welcome_fakes.dart' show FakeBoatStorage;

/// BAŞLANGIÇ GÖREVLERİ kartı testleri (Hoş Geldin Paketi B, kurucu onayı
/// 2026-10-25). Dürüstlük sözleşmesi: durumlar GERÇEK depolardan okunur
/// (0-uydurma), hepsi bitince ya da "Gizle" denince kart kendini çizmez.
const MyBoat _boatOnly = MyBoat(lengthM: 10.4, name: 'Martı');

const MyBoat _boatWithMarina = MyBoat(
  lengthM: 10.4,
  name: 'Martı',
  homeMarina:
      HomeMarina(id: 'loc-marti', name: 'Martı Marina', lat: 36.77, lon: 28.12),
);

// CI DERSİ (2026-10-25): bütün alanları sabit olan nesne `const` kurulmalı —
// prefer_const_constructors INFO bile olsa CI'da kırmızı sayılır.
const SavedRoute _route = SavedRoute(
  id: 'r1',
  name: 'Göcek → Bedri Rahmi',
  origin: RouteOrigin(pos: GeoPoint(lat: 36.74, lon: 28.93), name: 'Göcek'),
  waypoints: <RouteWaypoint>[
    RouteWaypoint(pos: GeoPoint(lat: 36.69, lon: 28.88), name: 'Bedri Rahmi'),
  ],
  distanceNm: 5.2,
  savedAtMs: 1,
);

Widget _app({
  FakeGettingStartedStore? store,
  MyBoat? boat,
  List<FavoriteLocation> favorites = const <FavoriteLocation>[],
  List<SavedRoute> routes = const <SavedRoute>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      gettingStartedStoreProvider
          .overrideWithValue(store ?? FakeGettingStartedStore()),
      boatStorageProvider.overrideWithValue(FakeBoatStorage(boat: boat)),
      // HESAP KAPISI (2026-10-26): tekne hesapla gezer — görev durumu
      // "tekne tanımlandı" GERÇEK veriden okunsun diye oturum açık koşar.
      signedInAuthOverride(),
      favoritesStorageProvider.overrideWithValue(FakeFavoritesStorage(favorites)),
      savedRoutesStoreProvider
          .overrideWithValue(FakeSavedRoutesStore()..data = routes),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: GettingStartedCard()),
      ),
    ),
  );
}

int _tab(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(GettingStartedCard)),
      listen: false,
    ).read(shellTabProvider);

void main() {
  testWidgets('yeni kullanıcı: kart 0/4 ile görünür; satır dokunuşu ilgili '
      'sekmeye götürür', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('gs-card')), findsOneWidget);
    expect(find.text('Başlangıç görevleri'), findsOneWidget);
    expect(find.text('0/4 tamam'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('gs-task-boat')), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('gs-task-marina')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('gs-task-fav')), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('gs-task-route')), findsOneWidget);

    // Tekne görevi → Teknem sekmesi (3); favori görevi → Keşfet (0).
    await tester.tap(find.byKey(const ValueKey<String>('gs-task-boat')));
    await tester.pump();
    expect(_tab(tester), 3);
    await tester.tap(find.byKey(const ValueKey<String>('gs-task-fav')));
    await tester.pump();
    expect(_tab(tester), 0);
  });

  testWidgets('kısmi ilerleme GERÇEK veriden okunur: tekne + marina + favori '
      '→ 3/4; rota görevi bekliyor', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      boat: _boatWithMarina,
      favorites: const <FavoriteLocation>[favA],
    ));
    await tester.pumpAndSettle();

    expect(find.text('3/4 tamam'), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('gs-task-route')), findsOneWidget);
  });

  testWidgets('marinasız tekne: marina görevi bitmedi sayılır (1/4 + favori '
      '= 2/4)', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      boat: _boatOnly,
      favorites: const <FavoriteLocation>[favA],
    ));
    await tester.pumpAndSettle();

    expect(find.text('2/4 tamam'), findsOneWidget);
  });

  testWidgets('4 görev de bittiyse kart kendini EMEKLİ EDER (hiç çizilmez)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      boat: _boatWithMarina,
      favorites: const <FavoriteLocation>[favA],
      routes: <SavedRoute>[_route],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('gs-card')), findsNothing);
  });

  testWidgets('"Gizle": kart o an kapanır ve karar cihaza KALICI yazılır',
      (WidgetTester tester) async {
    final FakeGettingStartedStore store = FakeGettingStartedStore();
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('gs-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('gs-hide')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('gs-card')), findsNothing);
    expect(store.dismissed, isTrue);
    expect(store.saveCount, 1);
  });

  testWidgets('daha önce gizlenmişse kart bir daha kendiliğinden çıkmaz',
      (WidgetTester tester) async {
    await tester
        .pumpWidget(_app(store: FakeGettingStartedStore(dismissed: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('gs-card')), findsNothing);
  });
}
