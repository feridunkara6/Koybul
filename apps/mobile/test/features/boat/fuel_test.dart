import 'package:dockly_mobile/features/boat/application/fuel_controller.dart';
import 'package:dockly_mobile/features/boat/domain/fuel.dart';
import 'package:dockly_mobile/features/boat/presentation/fuel_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// YAKIT TAKİBİ testleri (kurucu onayı 2026-10-30).
/// Kurucu kuralı sınanır: kayıtlar HESAPLA GELİR, çıkışta GÖRÜNMEZ olur
/// ama cihazdan silinmez. Hesap dönünce geri gelir (bakım deseni).

/// Bellek içi yakıt deposu — gerçek `shared_preferences`'a gitmez.
class FakeFuelStore implements FuelStore {
  List<FuelEntry> data = <FuelEntry>[];
  int saveCount = 0;

  @override
  Future<List<FuelEntry>> load() async => data;

  @override
  Future<void> save(List<FuelEntry> entries) async {
    saveCount++;
    data = entries;
  }
}

FuelEntry fill(
  String id,
  int dateMs,
  double liters, {
  double? hours,
  double? cost,
  String? owner,
}) =>
    FuelEntry(
      id: id,
      dateMs: dateMs,
      liters: liters,
      engineHours: hours,
      cost: cost,
      ownerUid: owner,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dürüst hesaplar (saf fonksiyonlar)', () {
    test('ortalama: yalnız motor saatli çiftlerden; saat yoksa null', () {
      // 578→601 saat arası 52 lt, 601→612 arası 46 lt → 98 lt / 34 sa ≈ 2,88.
      final List<FuelEntry> entries = <FuelEntry>[
        fill('a', 1, 48, hours: 578),
        fill('b', 2, 52, hours: 601),
        fill('c', 3, 38), // saatsiz — hesaba girmez
        fill('d', 4, 46, hours: 612),
      ];
      final double avg = fuelAvgPerHour(entries)!;
      expect(avg, closeTo(98 / 34, 0.001));
      // Tek saatli kayıt → çift yok → null (çizgi görünür, uydurma yok).
      expect(fuelAvgPerHour(<FuelEntry>[fill('a', 1, 48, hours: 578)]), isNull);
      expect(fuelAvgPerHour(const <FuelEntry>[]), isNull);
    });

    test('sezon toplamı yalnız bu yılın dolumlarını sayar', () {
      final int buYil =
          DateTime(DateTime.now().year, 6, 1).millisecondsSinceEpoch;
      final int gecenYil =
          DateTime(DateTime.now().year - 1, 6, 1).millisecondsSinceEpoch;
      final double total = fuelSeasonTotal(
        <FuelEntry>[fill('a', buYil, 46), fill('b', gecenYil, 99)],
        DateTime.now(),
      );
      expect(total, 46);
    });
  });

  group('HESAP KAPISI (kurucu kuralı: hesapla gelsin, çıkışta kaybolsun)', () {
    test('çıkışta liste BOŞ; giriş yapınca yalnız kendi + sahiplenilen kayıtlar',
        () async {
      final FakeFuelStore store = FakeFuelStore()
        ..data = <FuelEntry>[
          fill('mine', 1, 40, owner: 'u1'),
          fill('orphan', 2, 30), // kapıdan önce girilmiş — sahiplenilir
          fill('other', 3, 20, owner: 'u2'), // başka hesabın — görünmez
        ];
      final ProviderContainer c = ProviderContainer(overrides: <Override>[
        fuelStoreProvider.overrideWithValue(store),
        signedInAuthOverride(), // u1
      ]);
      addTearDown(c.dispose);
      c.read(fuelProvider); // tembel sağlayıcıyı kur
      await Future<void>.delayed(Duration.zero);
      final List<FuelEntry> mine = c.read(fuelProvider);
      expect(mine, hasLength(2)); // kendi + sahiplenilen
      expect(mine.every((FuelEntry e) => e.ownerUid == 'u1'), isTrue);
      // Başkasının kaydı GÖSTERİLMEZ ama diskte korunur.
      expect(store.data.where((FuelEntry e) => e.ownerUid == 'u2'), hasLength(1));
    });

    test('oturum yokken depoya dokunulmaz, liste boş kalır', () async {
      final FakeFuelStore store = FakeFuelStore()
        ..data = <FuelEntry>[fill('mine', 1, 40, owner: 'u1')];
      final ProviderContainer c = ProviderContainer(overrides: <Override>[
        fuelStoreProvider.overrideWithValue(store),
        // auth override YOK → AuthRestoring (hesapsız)
      ]);
      addTearDown(c.dispose);
      c.read(fuelProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(fuelProvider), isEmpty);
      expect(store.saveCount, 0); // çıkış veriyi SİLMEZ
    });
  });

  group('Yakıt sekmesi (widget)', () {
    Widget app(FakeFuelStore store) => ProviderScope(
          overrides: <Override>[
            fuelStoreProvider.overrideWithValue(store),
            signedInAuthOverride(),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: FuelTab())),
          ),
        );

    testWidgets('boş durum + dolum ekleme akışı: litre yaz, kaydet, listede gör',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final FakeFuelStore store = FakeFuelStore();
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('fuel-empty')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('fuel-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('fuel-liters')), '46');
      await tester.enterText(
          find.byKey(const ValueKey<String>('fuel-hours')), '612');
      await tester.tap(find.byKey(const ValueKey<String>('fuel-save')));
      await tester.pumpAndSettle();

      expect(store.data, hasLength(1));
      expect(store.data.single.liters, 46);
      expect(store.data.single.engineHours, 612);
      expect(store.data.single.ownerUid, 'u1'); // hesapla kaydedildi
      expect(find.textContaining('46 lt'), findsWidgets); // özet + satır
    });

    testWidgets('litresiz kayıt reddedilir (dürüst doğrulama)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final FakeFuelStore store = FakeFuelStore();
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('fuel-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('fuel-save')));
      await tester.pumpAndSettle();

      expect(store.data, isEmpty);
      expect(find.textContaining('litre değeri'), findsOneWidget);
    });
  });
}
