import 'package:dockly_api/dockly_api.dart'
    show PublicBoatCard, PublicBoatRouteRef, PublicCaptain;
import 'package:dockly_mobile/features/boat/application/boat_card_controller.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_card_screen.dart';
import 'package:dockly_mobile/features/profile/application/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _app(PublicBoatCard c) => ProviderScope(
      overrides: <Override>[
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

  testWidgets('0024: hikâye + istatistik + rota bölümleri çizilir; boşsa çizilmez',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Boş kart: yeni bölümlerin HİÇBİRİ çizilmez (0-uydurma).
    await tester.pumpWidget(_app(card()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('bc-story')), findsNothing);
    expect(find.text('PAYLAŞILAN SEYİR'), findsNothing);

    // Dolu kart: üç bölüm de çizilir, rota satırı dokunulabilir.
    final PublicBoatCard dolu = PublicBoatCard(
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
      routes: const <PublicBoatRouteRef>[
        PublicBoatRouteRef(
            id: 'r1', name: '12 Adalar klasiği', distanceNm: 14, saveCount: 23),
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
  });

}
