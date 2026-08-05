import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/checklist/domain/checklist_store.dart';
import 'package:dockly_mobile/features/checklist/presentation/checklist_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/checklist_fakes.dart';

ProviderContainer _container(FakeChecklistStore store) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      checklistStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// SEYİR ÖNCESİ KONTROL testleri (kullanıcı onayı 2026-08): günde bir nazik
/// şerit, günlük işaretler (dün bugünü aklamaz) ve alt sayfa akışı.
void main() {
  final DateTime day1 = DateTime(2026, 8, 5, 9);
  final DateTime day1Later = DateTime(2026, 8, 5, 17);
  final DateTime day2 = DateTime(2026, 8, 6, 8);

  test('şerit GÜNDE BİR kez: sorulunca aynı gün tekrar çıkmaz, ertesi gün çıkar',
      () async {
    final FakeChecklistStore store = FakeChecklistStore();
    final ProviderContainer c = _container(store);
    c.read(checklistProvider);
    await Future<void>.delayed(Duration.zero);

    c.read(checklistProvider.notifier).maybePrompt(now: day1);
    expect(c.read(checklistProvider).promptVisible, isTrue);
    c.read(checklistProvider.notifier).dismissPrompt(now: day1);
    expect(c.read(checklistProvider).promptVisible, isFalse);
    expect(store.askDay, checklistDayKey(day1)); // kalıcı

    c.read(checklistProvider.notifier).maybePrompt(now: day1Later);
    expect(c.read(checklistProvider).promptVisible, isFalse); // aynı gün: yok

    c.read(checklistProvider.notifier).maybePrompt(now: day2);
    expect(c.read(checklistProvider).promptVisible, isTrue); // yeni gün: var
  });

  test('açılışta bugün sorulmuşsa şerit çıkmaz (depodan okunur)', () async {
    final FakeChecklistStore store = FakeChecklistStore()
      ..askDay = checklistDayKey(day1);
    final ProviderContainer c = _container(store);
    c.read(checklistProvider);
    await Future<void>.delayed(Duration.zero);
    c.read(checklistProvider.notifier).maybePrompt(now: day1Later);
    expect(c.read(checklistProvider).promptVisible, isFalse);
  });

  test('işaretler GÜNLÜKTÜR: dünkü maske bugünü aklamaz', () async {
    final FakeChecklistStore store = FakeChecklistStore();
    final ProviderContainer c = _container(store);
    c.read(checklistProvider);
    await Future<void>.delayed(Duration.zero);

    c.read(checklistProvider.notifier).toggle(0, now: day1);
    c.read(checklistProvider.notifier).toggle(3, now: day1);
    expect(c.read(checklistProvider.notifier).maskFor(day1Later), 9); // bit 0+3
    expect(store.mask, 9);
    expect(store.day, checklistDayKey(day1));

    // Ertesi gün: görünüm sıfırdan başlar; yeni işaret dünküleri taşımaz.
    expect(c.read(checklistProvider.notifier).maskFor(day2), 0);
    c.read(checklistProvider.notifier).toggle(1, now: day2);
    expect(c.read(checklistProvider.notifier).maskFor(day2), 2);
    expect(store.day, checklistDayKey(day2));
  });

  testWidgets('alt sayfa: 10 madde listelenir, işaret depoya yazılır, sayaç işler',
      (WidgetTester tester) async {
    final FakeChecklistStore store = FakeChecklistStore();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        checklistStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showChecklistSheet(context),
              child: const Text('AC'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('AC'));
    await tester.pumpAndSettle();

    expect(find.text('Seyir Öncesi Kontrol'), findsOneWidget);
    expect(find.text('0/$kChecklistItemCount'), findsOneWidget);
    expect(find.text('Hava ve deniz tahminini kontrol ettim.'), findsOneWidget);
    // Dürüstlük notu ekranda.
    expect(find.textContaining('resmî güvenlik gereklerinin'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('checklist-0')));
    await tester.pumpAndSettle();
    expect(find.text('1/$kChecklistItemCount'), findsOneWidget);
    expect(store.mask & 1, 1); // depoya yazıldı
  });
}
