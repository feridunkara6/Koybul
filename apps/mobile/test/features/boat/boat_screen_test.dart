import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/maintenance.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_screen.dart';
import 'package:dockly_mobile/features/boat/presentation/maintenance_screen.dart';
import 'package:dockly_mobile/features/deck/presentation/deck_screen.dart'
    show deckSegmentProvider;
import 'package:dockly_mobile/features/map/application/map_controller.dart'
    show mapFocusProvider;
import 'package:dockly_mobile/features/map/domain/map_viewport.dart'
    show MapFocusRequest;
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/maintenance_fakes.dart';

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

Widget _app(FakeMaintenanceStore store, {MyBoat? boat}) => ProviderScope(
      overrides: <Override>[
        maintenanceStoreProvider.overrideWithValue(store),
        if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
      ],
      child: const MaterialApp(home: BoatScreen()),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(BoatScreen)),
      listen: false,
    );

/// TEKNEM testleri — KONSEPT A (kullanıcı onayı 2026-08): kimlik kartı +
/// tek satırlık bakım özeti (tam liste kendi ekranında) + Defter köprüsü.
void main() {
  testWidgets('KONSEPT A: ilk bakış üç kart — kimlik + bakım özeti + Defter '
      'köprüsü; 10 kalem artık ilk ekranda DEĞİL', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMaintenanceStore()));
    await tester.pumpAndSettle();

    expect(find.text('Tekneni tanımla'), findsOneWidget); // boş durum CTA'sı
    expect(find.byKey(const ValueKey<String>('maint-open')), findsOneWidget);
    expect(find.text('Bakım takibi'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('boat-deck-bridge')), findsOneWidget);
    // Kalem listesi ilk ekranda durmaz (özet yeter)…
    expect(find.text('Motor yağı ve filtresi'), findsNothing);
    // …ve ilgi bekleyen yokken özet rozeti de yok (uydurma uyarı olmaz).
    expect(find.byKey(const ValueKey<String>('maint-summary')), findsNothing);
  });

  testWidgets('bakım özetine dokun → tam liste kendi ekranında; kayıt yokken '
      'hiçbir şey İDDİA ETMEZ', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMaintenanceStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('maint-open')));
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    // Kayıt girilmedikçe kalemler "Kayıt yok" der; "Güncel" DEMEZ.
    expect(find.text('Motor yağı ve filtresi'), findsOneWidget);
    expect(find.text('Kayıt yok'), findsWidgets);
    expect(find.text('Güncel'), findsNothing);
  });

  testWidgets('süresi geçmiş kayıt: özet rozeti Teknem\'de; listede kırmızı '
      'durum + gecikme', (WidgetTester tester) async {
    // TAKVİM ARİTMETİĞİ (inceleme dersi): Duration mutlak süredir; yaz saati
    // uygulayan makinede 400 gün geri gitmek tarihi bir gün kaydırabilirdi.
    // Gün alanından çıkarmak (DateTime yapıcısı taşmayı düzeltir) kesindir.
    final DateTime t = DateTime.now();
    final DateTime old = DateTime(t.year, t.month, t.day - 400);
    final FakeMaintenanceStore store = FakeMaintenanceStore()
      ..data = <MaintenanceRecord>[
        MaintenanceRecord(
          taskId: 'engine_oil',
          lastDoneMs: old.millisecondsSinceEpoch,
        ),
      ];
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Özet rozeti Teknem'in ilk ekranında uyarır…
    expect(find.byKey(const ValueKey<String>('maint-summary')), findsOneWidget);
    expect(find.textContaining('1 kalem ilgi bekliyor'), findsOneWidget);

    // …ayrıntı listede.
    await tester.tap(find.byKey(const ValueKey<String>('maint-open')));
    await tester.pumpAndSettle();
    expect(find.text('Zamanı geçti'), findsOneWidget);
    expect(find.textContaining('35 gün gecikti'), findsOneWidget);
  });

  testWidgets('"Bugün yaptım": kalem güncel olur ve kayıt cihaza yazılır',
      (WidgetTester tester) async {
    final FakeMaintenanceStore store = FakeMaintenanceStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('maint-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('maint-engine_oil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('maint-done-today')));
    await tester.pumpAndSettle();

    expect(find.text('Güncel'), findsOneWidget);
    expect(store.data, hasLength(1));
    expect(store.data.first.taskId, 'engine_oil');
  });

  testWidgets('DEFTER KÖPRÜSÜ: istatistik Teknem\'de kopyalanmaz; köprü '
      'Defter/Seyirler\'e geçirir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMaintenanceStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('boat-deck-bridge')));
    await tester.pump();

    final ProviderContainer c = _containerOf(tester);
    expect(c.read(shellTabProvider), 2);
    expect(c.read(deckSegmentProvider), 0);
  });

  testWidgets('KİMLİK KARTI: tekne varken düzenleme sağ üstte kalem ikonu; '
      'marina satırı haritayı marina çevresinde açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMaintenanceStore(),
      boat: const MyBoat(
        lengthM: 12,
        draftM: 1.8,
        name: 'Martı',
        homeMarina: HomeMarina(
          id: 'dm1',
          name: 'D-Marin Göcek',
          lat: 36.75,
          lon: 28.93,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Ad başlıkta, düzenleme ikonu var, boş-durum CTA'sı yok.
    expect(find.text('Martı'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('boat-edit')), findsOneWidget);
    expect(find.text('Tekneni tanımla'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('boat-marina-map')));
    await tester.pump();

    final ProviderContainer c = _containerOf(tester);
    expect(c.read(shellTabProvider), 0); // Keşfet'e dönüldü
    final MapFocusRequest? focus = c.read(mapFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.point.lat, 36.75);
    expect(focus.point.lon, 28.93);
    expect(focus.zoom, 11); // kHomeMarinaFocusZoom
  });
}
