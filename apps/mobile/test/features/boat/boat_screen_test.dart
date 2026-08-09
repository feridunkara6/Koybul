import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/domain/maintenance.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/maintenance_fakes.dart';

Widget _app(FakeMaintenanceStore store) => ProviderScope(
      overrides: <Override>[
        maintenanceStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: BoatScreen()),
    );

/// TEKNEM testleri (v2.0): kimlik kartı + BAKIM TAKİBİ.
void main() {
  testWidgets('tekne yok → kimlik kartında tanımlama daveti; bakım listesi '
      'kayıt yokken hiçbir şey İDDİA ETMEZ', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMaintenanceStore()));
    await tester.pumpAndSettle();

    expect(find.text('Tekneni tanımla'), findsOneWidget);
    expect(find.text('Bakım takibi'), findsOneWidget);
    // Kayıt girilmedikçe kalemler "Kayıt yok" der; "Güncel" DEMEZ.
    expect(find.text('Motor yağı ve filtresi'), findsOneWidget);
    expect(find.text('Kayıt yok'), findsWidgets);
    expect(find.text('Güncel'), findsNothing);
    // İlgi bekleyen kalem yok → özet rozeti de yok (uydurma uyarı olmaz).
    expect(find.byKey(const ValueKey<String>('maint-summary')), findsNothing);
  });

  testWidgets('süresi geçmiş kayıt: kırmızı durum + gecikme + özet rozeti',
      (WidgetTester tester) async {
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

    expect(find.text('Zamanı geçti'), findsOneWidget);
    expect(find.textContaining('35 gün gecikti'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('maint-summary')), findsOneWidget);
    expect(find.textContaining('1 kalem ilgi bekliyor'), findsOneWidget);
  });

  testWidgets('"Bugün yaptım": kalem güncel olur ve kayıt cihaza yazılır',
      (WidgetTester tester) async {
    final FakeMaintenanceStore store = FakeMaintenanceStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('maint-engine_oil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('maint-done-today')));
    await tester.pumpAndSettle();

    expect(find.text('Güncel'), findsOneWidget);
    expect(store.data, hasLength(1));
    expect(store.data.first.taskId, 'engine_oil');
  });
}
