import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/favorites/application/favorites_controller.dart';
import 'package:dockly_mobile/features/favorites/domain/favorite_location.dart';
import 'package:dockly_mobile/features/favorites/presentation/favorites_screen.dart';
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/favorites_fakes.dart';
import '../../support/saved_routes_fakes.dart';

Widget _app(FakeFavoritesStorage storage, {FakeSavedRoutesStore? routes}) =>
    ProviderScope(
      overrides: <Override>[
        favoritesStorageProvider.overrideWithValue(storage),
        savedRoutesStoreProvider
            .overrideWithValue(routes ?? FakeSavedRoutesStore()),
      ],
      child: const MaterialApp(home: FavoritesScreen()),
    );

const SavedRoute _route = SavedRoute(
  id: 'r1',
  name: 'Datça → Kille Koyu',
  origin: RouteOrigin(pos: GeoPoint(lat: 36.70, lon: 27.70), name: 'Datça'),
  waypoints: <RouteWaypoint>[
    RouteWaypoint(
        pos: GeoPoint(lat: 36.74, lon: 28.10), id: 'kille', name: 'Kille Koyu'),
  ],
  distanceNm: 26.4,
  savedAtMs: 1000,
);

void main() {
  testWidgets('boşsa "Henüz favori yok" ipucu gösterir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeFavoritesStorage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz favori yok'), findsOneWidget);
  });

  testWidgets('favoriler listelenir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeFavoritesStorage(<FavoriteLocation>[favA, favB])));
    await tester.pumpAndSettle();
    expect(find.text('Aliman'), findsOneWidget);
    expect(find.text('Bkoy'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('çıkar düğmesi favoriyi kaldırır', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeFavoritesStorage(<FavoriteLocation>[favA])));
    await tester.pumpAndSettle();
    expect(find.text('Aliman'), findsOneWidget);

    await tester.tap(find.byTooltip('Favorilerden çıkar'));
    await tester.pumpAndSettle();

    expect(find.text('Aliman'), findsNothing);
    expect(find.textContaining('Henüz favori yok'), findsOneWidget);
  });
  testWidgets('KAYITLI ROTALAR Favoriler\'de AYRI BÖLÜM (kullanıcı isteği '
      '2026-08): başlıklar + rota kartı görünür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeFavoritesStorage(<FavoriteLocation>[favA]),
      routes: FakeSavedRoutesStore()..data = <SavedRoute>[_route],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kayıtlı Rotalar'), findsOneWidget); // bölüm başlığı
    expect(find.text('Datça → Kille Koyu'), findsOneWidget); // rota kartı
    expect(find.text('Haritada aç'), findsOneWidget); // kartın eylemi
    expect(find.text('Favori yerler'), findsOneWidget); // ikinci bölüm
    expect(find.text('Aliman'), findsOneWidget);
  });

  testWidgets('yalnız rota varken: rota bölümü görünür, "Henüz favori yok" '
      'kaplaması ÇIKMAZ', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeFavoritesStorage(),
      routes: FakeSavedRoutesStore()..data = <SavedRoute>[_route],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Datça → Kille Koyu'), findsOneWidget);
    expect(find.textContaining('Henüz favori yok'), findsNothing);
    expect(find.text('Favori yerler'), findsNothing); // boş bölüm başlıksız
  });
}
