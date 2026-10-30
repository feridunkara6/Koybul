import 'package:dockly_api/dockly_api.dart'
    show
        FavoriteBoatRef,
        PublicBoatCard,
        PublicBoatRouteRef,
        PublicBoatSisterRef,
        PublicCaptain,
        SessionUser;
import 'package:dockly_mobile/features/auth/presentation/account_gate.dart'
    show AccountRequiredSheetBody;
import 'package:dockly_mobile/features/boat/application/boat_card_controller.dart';
import 'package:dockly_mobile/features/boat/application/favorites_controller.dart';
import 'package:dockly_mobile/features/boat/domain/favorites_gateway.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_card_screen.dart';
import 'package:dockly_mobile/features/profile/application/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// TEKNE KARTI testleri (Sosyalleşme Hafta 2, kurucu onayı 2026-10-24).
/// Kural (docs/15): ağ yok — sağlayıcı aile sahtesiyle beslenir.
/// Çizim kuralları Teknem'dekiyle aynı olduğundan burada yalnız SEÇİMİN
/// doğru aktığı test edilir (katı eşleşmenin kendisi boat_model_art_test'te).

PublicBoatCard card({
  String? brand = 'Beneteau',
  String? model = 'Oceanis 38.1',
  double? lengthM = 11.5,
  int? buildYear = 2019,
}) =>
    PublicBoatCard(
      id: 'b-marti',
      name: 'Martı',
      boatTypeCode: 'sailboat',
      brand: brand,
      model: model,
      lengthM: lengthM,
      buildYear: buildYear,
      marinaId: 'loc-marti',
      marinaName: 'Martı Marina',
      captainUserId: 'u-1',
      captainName: 'Kaptan Levent',
      captainLevelCode: 'guide',
    );

/// Kayıt tutan sahte favori geçidi — ağ yok (docs/15).
class FakeFavoritesGateway implements FavoritesGateway {
  final List<String> favored = <String>[];
  final List<String> unfavored = <String>[];
  List<FavoriteBoatRef> list = <FavoriteBoatRef>[];

  @override
  Future<List<FavoriteBoatRef>> favorites() async => list;

  @override
  Future<void> favorite(String boatId) async {
    favored.add(boatId);
  }

  @override
  Future<void> unfavorite(String boatId) async {
    unfavored.add(boatId);
  }
}

Widget _app(PublicBoatCard c, {List<Override> extra = const <Override>[]}) =>
    ProviderScope(
      overrides: <Override>[
        ...extra,
        publicBoatCardProvider.overrideWith((ref, String id) async => c),
        publicCaptainProvider.overrideWith((ref, String id) async => PublicCaptain(
              id: id,
              displayName: 'Kaptan Levent',
              bio: null,
              experienceYears: 14,
              memberSince: DateTime.utc(2026, 7, 7),
              points: 840,
              levelCode: 'guide',
              approvedCount: 46,
              helpfulReceived: 120,
              badges: const <String>[],
            )),
      ],
      child: const MaterialApp(home: BoatCardScreen(boatId: 'b-marti')),
    );

void main() {
  testWidgets('MODEL ÇİZİMİ: katı eşleşen tekne model çizimi + borda adı alır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(card()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('boat-card-model-oceanis_38')),
        findsOneWidget);
    expect(find.text('🖊️ MODEL ÇİZİMİ'), findsOneWidget);
    // Borda adı AYRI katmanda — kartta da aynı kural.
    expect(find.byKey(const ValueKey<String>('boat-art-name')), findsOneWidget);
    // Ad hem bordada hem başlıkta: en az 2 kez görünür.
    expect(find.text('Martı'), findsNWidgets(2));
    expect(find.textContaining('Beneteau Oceanis 38.1'), findsOneWidget);
    expect(find.textContaining('Martı Marina'), findsOneWidget);
  });

  testWidgets('TEKNİK GİZLİ: specs null ise TİP ÇİZİMİ + teknik satır yok',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(_app(card(brand: null, model: null, lengthM: null, buildYear: null)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('boat-card-sail')), findsOneWidget);
    expect(find.text('🎨 TİP ÇİZİMİ'), findsOneWidget);
    expect(find.textContaining('Beneteau'), findsNothing);
    expect(find.textContaining('11,5'), findsNothing);
  });

  testWidgets('KAPTAN KÖPRÜSÜ: kaptan satırına dokununca profili açılır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(card()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('bc-captain')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('cp-name')), findsOneWidget);
  });

  // CI dersi (2026-10-30): aynı ağaca ikinci kez farklı aile sahtesi vermek
  // önbellekteki eski veriyi YENİLEMEZ — boş/dolu kart iki AYRI testte sınanır.
  testWidgets('0024 BOŞ KART: hikâye/istatistik/rota bölümleri çizilmez',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Boş kart: yeni bölümlerin HİÇBİRİ çizilmez (0-uydurma).
    await tester.pumpWidget(_app(card()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('bc-story')), findsNothing);
    expect(find.text('PAYLAŞILAN SEYİR'), findsNothing);
    // TK-5: eşleşme yoksa KARDEŞ TEKNELER bölümü de çizilmez; kalp sayısız.
    expect(find.text('KARDEŞ TEKNELER'), findsNothing);
    expect(find.byKey(const ValueKey<String>('bc-fav-btn')), findsOneWidget);
    expect(find.textContaining('· 0'), findsNothing); // 0 sayı YAZILMAZ
  });

  testWidgets('0024 DOLU KART: hikâye + istatistik + rota bölümleri çizilir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // (const: CI dersi — analizör --fatal-infos ile info'yu da kırmızı sayar.)
    const PublicBoatCard dolu = PublicBoatCard(
      id: 'b-marti',
      name: 'Martı',
      boatTypeCode: 'sailboat',
      brand: 'Beneteau',
      model: 'Oceanis 38.1',
      lengthM: 11.5,
      buildYear: 2019,
      marinaId: 'loc-marti',
      marinaName: 'Martı Marina',
      captainUserId: 'u-1',
      captainName: 'Kaptan Levent',
      captainLevelCode: 'guide',
      story: "2019'da Göcek'te teslim aldık; adı direğe konan martıdan.",
      sharedTrips: 6,
      sharedRoutes: 3,
      pruvaTotal: 27,
      routes: <PublicBoatRouteRef>[
        PublicBoatRouteRef(
            id: 'r1', name: '12 Adalar klasiği', distanceNm: 14, saveCount: 23),
      ],
      // TK-5 (kurucu onayı 2026-10-30): favori + takipçi + kardeş tekneler.
      favoriteCount: 12,
      captainFollowers: 34,
      sisters: <PublicBoatSisterRef>[
        PublicBoatSisterRef(
            id: 's1',
            name: 'Poyraz',
            boatTypeCode: 'sailboat',
            marinaName: 'Yalıkavak Marina'),
      ],
    );
    await tester.pumpWidget(_app(dolu));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('bc-story')), findsOneWidget);
    expect(find.textContaining('direğe konan martıdan'), findsOneWidget);
    expect(find.text('PAYLAŞILAN SEYİR'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('bc-route-r1')), findsOneWidget);
    expect(find.text('12 Adalar klasiği'), findsOneWidget);
    // TK-5: kalp sayıyla, takipçi satırı ve kardeş tekne satırı.
    expect(find.textContaining('Favorile · 12'), findsOneWidget);
    expect(find.textContaining('34 takipçi'), findsOneWidget);
    expect(find.text('KARDEŞ TEKNELER'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('bc-sister-s1')), findsOneWidget);
    expect(find.text('Poyraz'), findsOneWidget);
  });

  testWidgets('TK-5 KENDİ TEKNESİ: sahibi kendi kartında kalbi GÖRMEZ',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      card(), // kaptan u-1
      extra: <Override>[
        signedInAuthOverride(
            user: const SessionUser(
                id: 'u-1', role: 'user', isGuest: false, locale: 'tr')),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('bc-fav-btn')), findsNothing);
  });

  testWidgets('TK-5 HESAP KAPISI: hesapsız dokunuş kalbe değil davete gider',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeFavoritesGateway gw = FakeFavoritesGateway();
    await tester.pumpWidget(_app(
      card(),
      extra: <Override>[favoritesGatewayProvider.overrideWithValue(gw)],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('bc-fav-btn')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountRequiredSheetBody), findsOneWidget);
    expect(gw.favored, isEmpty); // sunucuya hiç gidilmedi
  });

  testWidgets('TK-5 ÜYE FAVORİLER: dokunuş geçide gider (sessiz beğeni)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeFavoritesGateway gw = FakeFavoritesGateway();
    await tester.pumpWidget(_app(
      card(),
      extra: <Override>[
        favoritesGatewayProvider.overrideWithValue(gw),
        signedInAuthOverride(), // u1 — kaptan u-1 değil, kalp görünür
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('bc-fav-btn')));
    await tester.pumpAndSettle();
    expect(gw.favored, <String>['b-marti']);
    // Kapı AÇILMADI — üye doğrudan favoriler.
    expect(find.byType(AccountRequiredSheetBody), findsNothing);
  });
}
