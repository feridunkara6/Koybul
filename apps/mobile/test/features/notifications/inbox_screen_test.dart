import 'package:dockly_api/dockly_api.dart' show InboxItem;
import 'package:dockly_mobile/features/notifications/application/inbox_controller.dart';
import 'package:dockly_mobile/features/notifications/presentation/notifications_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BİLDİRİM KUTUSU testleri (SP-2 Döngü, kurucu onayı 2026-10-31).
/// Kural (docs/15): ağ yok — sağlayıcı sahteyle beslenir; metinler tür+data
/// yükünden İSTEMCİDE üretilir, burada doğrulanır.
Widget _app(List<InboxItem> items) => ProviderScope(
      overrides: <Override>[
        inboxProvider.overrideWith((ref) async => items),
      ],
      child: const MaterialApp(home: NotificationsInboxScreen()),
    );

void main() {
  testWidgets('boş kutu: dürüst boş durum metni', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const <InboxItem>[]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz bildirim yok'), findsOneWidget);
  });

  testWidgets('satır metinleri tür+data yükünden kullanıcı dilinde üretilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(const <InboxItem>[
      InboxItem(
        id: 'i1',
        type: 'qa_answer',
        data: <String, String>{
          'kind': 'qa_answer',
          'id': 'q1',
          'title': 'Gökova sonbahar demiri',
        },
        readAt: null,
        createdAt: '2026-10-30T09:00:00.000Z',
      ),
      InboxItem(
        id: 'i2',
        type: 'helpful_received',
        data: <String, String>{
          'kind': 'helpful_received',
          'id': 'n1',
          'title': 'Kille Koyu',
          'count': '5',
        },
        readAt: '2026-10-30T10:00:00.000Z',
        createdAt: '2026-10-29T09:00:00.000Z',
      ),
      InboxItem(
        id: 'i3',
        type: 'level_up',
        data: <String, String>{'kind': 'level_up', 'level': 'guide'},
        readAt: null,
        createdAt: '2026-10-28T09:00:00.000Z',
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Soruna cevap geldi'), findsOneWidget);
    expect(find.textContaining('Gökova sonbahar demiri'), findsOneWidget);
    expect(find.textContaining('5 faydalı oyuna ulaştı'), findsOneWidget);
    // Seviye kodu istemcide yerel etikete çevrilir (levelLabel).
    expect(find.textContaining('Yol Gösteren'), findsOneWidget);
    // Gün hassasiyetli tarih görünür.
    expect(find.text('2026-10-30'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('inbox-i1')), findsOneWidget);
  });

  testWidgets('bilinmeyen tür çökmez — genel satıra düşer (ileri sürüm uyumu)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(const <InboxItem>[
      InboxItem(
        id: 'i9',
        type: 'yepyeni_tur',
        data: <String, String>{'kind': 'yepyeni_tur'},
        readAt: null,
        createdAt: '2026-10-30T09:00:00.000Z',
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Yeni bildirim'), findsOneWidget);
  });
}
