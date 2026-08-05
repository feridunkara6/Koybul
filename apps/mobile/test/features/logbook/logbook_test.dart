import 'package:dockly_mobile/features/logbook/application/logbook_controller.dart';
import 'package:dockly_mobile/features/logbook/domain/log_entry.dart';
import 'package:dockly_mobile/features/logbook/presentation/logbook_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/logbook_fakes.dart';

const LogEntry _sample = LogEntry(
  id: 'l1',
  dateMs: 1754300000000, // 2026 içinde sabit bir an
  text: 'Gökova poyrazı sertti, Kille Koyu sakin bir liman oldu.',
  title: 'İlk seyir',
  ctxRoute: 'Bodrum → Kille Koyu',
  ctxNm: 26.4,
  ctxStops: 1,
);

Widget _app(FakeLogbookStore store, {LogContext? ctx}) => ProviderScope(
      overrides: <Override>[
        logbookStoreProvider.overrideWithValue(store),
        // Harita sahtelerine gerek kalmasın: bağlam doğrudan verilir.
        logContextProvider.overrideWithValue(ctx),
      ],
      child: const MaterialApp(home: LogbookScreen()),
    );

/// KAPTANIN GÜNLÜĞÜ testleri (kullanıcı onayı 2026-08): JSON gidiş-dönüş,
/// yarış koruması, ekran akışı ve otomatik bağlam.
void main() {
  test('JSON gidiş-dönüş kayıpsız; bozuk kayıt null (çökme yok)', () {
    final LogEntry? back = LogEntry.fromJson(_sample.toJson());
    expect(back, isNotNull);
    expect(back!.title, 'İlk seyir');
    expect(back.ctxRoute, 'Bodrum → Kille Koyu');
    expect(back.ctxNm, 26.4);
    expect(back.ctxStops, 1);
    expect(LogEntry.fromJson('çöp'), isNull);
    expect(LogEntry.fromJson(<String, dynamic>{'id': 'x'}), isNull);
  });

  test('YARIŞ KORUMASI: yükleme bitmeden eklenen giriş kaybolmaz', () async {
    final FakeLogbookStore store = FakeLogbookStore()
      ..data = <LogEntry>[_sample];
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[logbookStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    const LogEntry fresh =
        LogEntry(id: 'l2', dateMs: 1754400000000, text: 'Yeni not');
    await c.read(logbookProvider.notifier).add(fresh);
    final List<String> ids =
        c.read(logbookProvider).map((LogEntry e) => e.id).toList();
    expect(ids, containsAll(<String>['l1', 'l2']));
    expect(ids.first, 'l2'); // en yeni başta
    expect(store.data.map((LogEntry e) => e.id), containsAll(<String>['l1', 'l2']));
  });

  testWidgets('liste: giriş kartı tarih + başlık + bağlam + notla görünür; '
      'çöp kutusu siler', (WidgetTester tester) async {
    final FakeLogbookStore store = FakeLogbookStore()
      ..data = <LogEntry>[_sample];
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('İlk seyir'), findsOneWidget);
    expect(find.textContaining('Bodrum → Kille Koyu'), findsOneWidget);
    expect(find.textContaining('Gökova poyrazı'), findsOneWidget);

    await tester.tap(find.byTooltip('Girişi sil'));
    await tester.pumpAndSettle();
    expect(find.text('İlk seyir'), findsNothing);
    expect(store.data, isEmpty);
    expect(find.textContaining('Henüz günlük girişi yok'), findsOneWidget);
  });

  testWidgets('YENİ KAYIT: aktif rota bağlamı kendiliğinden gelir, ✕ ile '
      'kaldırılabilir; boş metin kaydedilmez', (WidgetTester tester) async {
    final FakeLogbookStore store = FakeLogbookStore();
    await tester.pumpWidget(_app(
      store,
      ctx: const LogContext(
          routeName: 'Konumum → Göcek', distanceNm: 12.5, stops: 2),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('logbook-new')));
    await tester.pumpAndSettle();
    expect(find.text('Konumum → Göcek'), findsOneWidget); // otomatik bağlam

    // Boş metinle kaydetme denemesi → kayıt YOK (sayfa açık kalır).
    await tester.tap(find.byKey(const ValueKey<String>('logbook-save')));
    await tester.pumpAndSettle();
    expect(store.data, isEmpty);

    await tester.enterText(
        find.widgetWithText(TextField, 'Bugünün seyri nasıldı, kaptan?'),
        'Rüzgar tam kıçtan, keyifli seyir.');
    await tester.tap(find.byKey(const ValueKey<String>('logbook-save')));
    await tester.pumpAndSettle();

    expect(store.data, hasLength(1));
    expect(store.data.single.ctxRoute, 'Konumum → Göcek');
    expect(store.data.single.ctxStops, 2);
    expect(find.textContaining('Rüzgar tam kıçtan'), findsOneWidget); // listede
  });

  testWidgets('bağlam ✕ ile kaldırılırsa giriş bağlamsız kaydedilir', (
    WidgetTester tester,
  ) async {
    final FakeLogbookStore store = FakeLogbookStore();
    await tester.pumpWidget(_app(
      store,
      ctx: const LogContext(routeName: 'Konumum → Göcek'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('logbook-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('logbook-ctx-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Konumum → Göcek'), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, 'Bugünün seyri nasıldı, kaptan?'),
        'Bağlamsız not.');
    await tester.tap(find.byKey(const ValueKey<String>('logbook-save')));
    await tester.pumpAndSettle();
    expect(store.data.single.ctxRoute, isNull);
  });
}
