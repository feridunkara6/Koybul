import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/search/application/search_controller.dart';
import 'package:dockly_mobile/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/search_fakes.dart';

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

/// Çip şeridi YATAY kaydırılabilir (CI dersi: hedef çip ekran dışında
/// kurulmamış bile olabilir) — dokunmadan önce şeridi kaydırıp çipi görünür
/// konuma getirir, sonra dokunur.
Future<void> _tapChip(WidgetTester tester, String label) async {
  final Finder chipRow = find.descendant(
    of: find.byKey(const ValueKey<String>('search-filter-row')),
    matching: find.byType(Scrollable),
  );
  // ŞERİDİ BAŞA SAR (CI dersi 2): scrollUntilVisible yalnız İLERİ kaydırır —
  // hedef çip o anki görünümün SOLUNDA kaldıysa asla bulunamazdı. Baştan
  // ileri arama her çip için belirlenimcidir.
  tester.state<ScrollableState>(chipRow).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(find.text(label), 80, scrollable: chipRow);
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
}

Widget _app(FakeSearchGateway gateway, {MyBoat? boat}) {
  return ProviderScope(
    overrides: <Override>[
      searchGatewayProvider.overrideWithValue(gateway),
      searchDebounceProvider.overrideWithValue(Duration.zero),
      // HESAP KAPISI (2026-10-26): "Teknem sığar" çipi tekne sayfası açmadan
      // önce hesap ister — bu dosyanın konusu kapı değil; oturum açık koşar.
      signedInAuthOverride(),
      if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
    ],
    child: const MaterialApp(home: SearchScreen()),
  );
}

void main() {
  testWidgets('boş sorguda "en az 2 harf" ipucu gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeSearchGateway()));
    await tester.pumpAndSettle();
    expect(find.textContaining('en az 2 harf'), findsOneWidget);
  });

  testWidgets('kısa sorgu (1 harf) → ipucu kalır, sonuç aranmaz', (WidgetTester tester) async {
    final FakeSearchGateway gateway =
        FakeSearchGateway(results: <LocationSummary>[sampleSummary('loc-1', 'Alfa Marina')]);
    await tester.pumpWidget(_app(gateway));
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(find.textContaining('en az 2 harf'), findsOneWidget);
    expect(gateway.queries, isEmpty);
  });

  testWidgets('yeterli sorgu → sonuç listelenir', (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-1', 'D-Marin Göcek', ratingAvg: 4.8)],
    );
    await tester.pumpWidget(_app(gateway));
    await tester.enterText(find.byType(TextField), 'göcek');
    await tester.pumpAndSettle();
    expect(find.text('D-Marin Göcek'), findsOneWidget);
    expect(gateway.queries, <String>['göcek']);
  });

  testWidgets('tür çipine dokununca filtre uygulanır', (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-1', 'D-Marin Göcek')],
    );
    await tester.pumpWidget(_app(gateway));
    await tester.enterText(find.byType(TextField), 'göcek');
    await tester.pumpAndSettle();
    await _tapChip(tester, 'Özel Marina');
    await tester.pumpAndSettle();
    expect(gateway.typeArgs.last, contains('private_marina'));
  });

  testWidgets('tekne yokken "Teknem sığar" çipi tekne tanımlama sayfasını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeSearchGateway()));
    await tester.tap(find.widgetWithText(FilterChip, 'Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.text('Tekneni tanımla'), findsOneWidget); // alt sayfa başlığı
  });

  testWidgets('"Teknem sığar" açıkken tekneye sığmayanlar gizlenir',
      (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[
        sampleSummary('fits', 'Sığan Marina', maxBoatLengthM: 40, maxDraftM: 5),
        sampleSummary('big', 'Küçük İskele', maxBoatLengthM: 8, maxDraftM: 1),
      ],
    );
    await tester.pumpWidget(_app(gateway, boat: const MyBoat(lengthM: 15, draftM: 2)));
    await tester.enterText(find.byType(TextField), 'liman');
    await tester.pumpAndSettle();
    expect(find.text('Sığan Marina'), findsOneWidget);
    expect(find.text('Küçük İskele'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.text('Sığan Marina'), findsOneWidget);
    expect(find.text('Küçük İskele'), findsNothing); // 15 m tekne 8 m limite sığmaz
  });

  testWidgets('tekne tanımlıysa her sonuçta uygunluk rozeti görünür',
      (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[
        sampleSummary('fits', 'Sığan Marina', maxBoatLengthM: 40, maxDraftM: 5),
        sampleSummary('big', 'Küçük İskele', maxBoatLengthM: 8, maxDraftM: 1),
      ],
    );
    await tester.pumpWidget(_app(gateway, boat: const MyBoat(lengthM: 15, draftM: 2)));
    await tester.enterText(find.byType(TextField), 'liman');
    await tester.pumpAndSettle();
    // 15 m tekne: 40 m marinaya sığar, 8 m iskeleye sığmaz → iki farklı rozet.
    expect(find.text('Teknen sığar'), findsOneWidget);
    expect(find.text('Teknen sığmayabilir'), findsOneWidget);
  });

  testWidgets('tekne tanımsızsa sonuçlarda uygunluk rozeti çıkmaz',
      (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[
        sampleSummary('fits', 'Sığan Marina', maxBoatLengthM: 40, maxDraftM: 5),
      ],
    );
    await tester.pumpWidget(_app(gateway)); // tekne yok
    await tester.enterText(find.byType(TextField), 'liman');
    await tester.pumpAndSettle();
    expect(find.text('Teknen sığar'), findsNothing);
    expect(find.text('Teknen sığmayabilir'), findsNothing);
  });

  testWidgets('olanak çipi: metin YOKKEN de arar; amenity parametresi gider',
      (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-1', 'Netsel Marmaris')],
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await _tapChip(tester, 'Yakıt');
    await tester.pumpAndSettle();

    expect(gateway.queries, <String>['']); // keşif modu: boş metin
    expect(gateway.amenityArgs.single, <String>['fuel']);
    expect(find.text('Netsel Marmaris'), findsOneWidget);
  });

  testWidgets('olanak çipleri AND birleşir; kapatınca parametreden düşer',
      (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-1', 'Alfa Marina')],
    );
    await tester.pumpWidget(_app(gateway));
    await tester.enterText(find.byType(TextField), 'marina');
    await tester.pumpAndSettle();

    await _tapChip(tester, 'Duş');
    await tester.pumpAndSettle();
    await _tapChip(tester, 'Su');
    await tester.pumpAndSettle();
    expect(gateway.amenityArgs.last, containsAll(<String>['shower', 'water']));

    await _tapChip(tester, 'Duş');
    await tester.pumpAndSettle();
    expect(gateway.amenityArgs.last, <String>['water']);
    expect(gateway.queries.last, 'marina');
  });

  testWidgets('son olanak çipi kapanınca (metin de kısa) ipucuya dönülür',
      (WidgetTester tester) async {
    final FakeSearchGateway gateway = FakeSearchGateway(
      results: <LocationSummary>[sampleSummary('loc-1', 'Alfa Marina')],
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await _tapChip(tester, 'Yakıt');
    await tester.pumpAndSettle();
    expect(find.text('Alfa Marina'), findsOneWidget);

    await _tapChip(tester, 'Yakıt');
    await tester.pumpAndSettle();
    expect(find.text('Alfa Marina'), findsNothing);
    expect(find.textContaining('en az 2 harf'), findsOneWidget);
  });
}
