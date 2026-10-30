import 'package:dockly_api/dockly_api.dart' show FavoriteBoatRef;
import 'package:dockly_mobile/features/boat/application/favorites_controller.dart';
import 'package:dockly_mobile/features/boat/domain/favorites_gateway.dart';
import 'package:dockly_mobile/features/boat/presentation/favorite_boats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// FAVORİ TEKNELERİM testleri (TK-5, kurucu onayı 2026-10-30).
/// Kural (docs/15): ağ yok — geçit sahtedir. Misafir kuralı sınanır:
/// hesapsızken sunucuya HİÇ gidilmez, boş durum metni görünür.

class FakeFavoritesGateway implements FavoritesGateway {
  FakeFavoritesGateway(this.list);

  final List<FavoriteBoatRef> list;
  int favoritesCalls = 0;

  @override
  Future<List<FavoriteBoatRef>> favorites() async {
    favoritesCalls++;
    return list;
  }

  @override
  Future<void> favorite(String boatId) async {}

  @override
  Future<void> unfavorite(String boatId) async {}
}

Widget _app(FakeFavoritesGateway gw, {bool signedIn = true}) => ProviderScope(
      overrides: <Override>[
        favoritesGatewayProvider.overrideWithValue(gw),
        if (signedIn) signedInAuthOverride(),
      ],
      child: const MaterialApp(home: FavoriteBoatsScreen()),
    );

void main() {
  testWidgets('üye: favori tekneler listelenir; rıza kapalıysa marka inmez',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeFavoritesGateway gw = FakeFavoritesGateway(<FavoriteBoatRef>[
      const FavoriteBoatRef(
        id: 'b1',
        name: 'Martı',
        boatTypeCode: 'sailboat',
        brand: 'Beneteau',
        model: 'Oceanis 38.1',
        marinaName: 'D-Marin Göcek',
      ),
      // Teknik rıza kapalı: marka/model null — satır yalnız ad + marina.
      const FavoriteBoatRef(
        id: 'b2',
        name: 'Derin',
        boatTypeCode: 'sailboat',
        brand: null,
        model: null,
        marinaName: 'Didim Marina',
      ),
    ]);
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('fav-boat-row-b1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fav-boat-row-b2')), findsOneWidget);
    expect(find.textContaining('Beneteau Oceanis 38.1'), findsOneWidget);
    expect(find.textContaining('Didim Marina'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fav-boats-empty')), findsNothing);
  });

  testWidgets('hesapsız: sunucuya gidilmez, boş durum metni görünür',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeFavoritesGateway gw =
        FakeFavoritesGateway(const <FavoriteBoatRef>[]);
    await tester.pumpWidget(_app(gw, signedIn: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('fav-boats-empty')), findsOneWidget);
    expect(gw.favoritesCalls, 0); // misafir kuralı: geçide HİÇ dokunulmadı
  });
}
