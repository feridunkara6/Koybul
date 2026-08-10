import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/community/presentation/note_card.dart';
import 'package:dockly_mobile/features/community/presentation/notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';

const GeoPoint _pos = GeoPoint(lat: 36.62, lon: 28.90);

Widget _app(FakeCommunityGateway gw, {bool signedIn = false}) {
  return ProviderScope(
    overrides: <Override>[
      communityGatewayProvider.overrideWithValue(gw),
      if (signedIn) signedInAuthOverride(),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NotesSection(
            locationId: 'loc-1',
            locationName: 'Boynuzbükü',
            position: _pos,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('not yoksa dürüst boş durum + davet düğmesi gösterilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeCommunityGateway()));
    await tester.pumpAndSettle();

    expect(find.textContaining('henüz not bırakılmamış'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note-add')), findsOneWidget);
  });

  testWidgets('notlar listelenir; başlıkta sayı görünür', (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[
      makeNote(id: 'a', body: 'Birinci notun gövdesi.'),
      makeNote(id: 'b', body: 'İkinci notun gövdesi.'),
    ]);
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    expect(find.byType(NoteCard), findsNWidgets(2));
    expect(find.textContaining('Kaptan Notları · 2'), findsOneWidget);
    expect(find.text('M. Kaya'), findsWidgets);
    // Seviye etiketi görünür ama SIRALAMAYI etkilemez (tasarım §8.4).
    expect(find.text('Usta Kaptan'), findsWidgets);
  });

  testWidgets('UYARI notu bölüm kartına GİRMEZ — ayrı şeride gider',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[
      makeNote(id: 'h', kind: NoteKind.hazard, body: 'Girişte batık kaya var.'),
      makeNote(id: 'e', body: 'Sıradan bir deneyim notu.'),
    ]);
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    // Kartın içinde yalnız uyarı OLMAYAN not var.
    expect(find.text('Girişte batık kaya var.'), findsNothing);
    expect(find.text('Sıradan bir deneyim notu.'), findsOneWidget);
    // Başlıktaki sayı TÜM notları kapsar (uyarı dahil) — "Tümü" de tümünü açar.
    expect(find.textContaining('Kaptan Notları · 2'), findsOneWidget);
  });

  testWidgets('yalnız UYARI varsa kart gövdesi çelişmez (yukarıda diye söyler)',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[
      makeNote(id: 'h', kind: NoteKind.hazard, body: 'Tek uyarı.'),
    ]);
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kaptan Notları · 1'), findsOneWidget);
    // "Henüz not yok" DEMEZ — sayı 1 iken bu bir çelişki olurdu.
    expect(find.textContaining('henüz not bırakılmamış'), findsNothing);
    expect(find.textContaining('uyarılar yukarıda'), findsOneWidget);
  });

  testWidgets('ikiden fazla not varsa "tümü" bağlantısı çıkar',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[
      for (int i = 0; i < 5; i++) makeNote(id: 'n$i', body: 'Not gövdesi $i'),
    ]);
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    expect(find.byType(NoteCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey<String>('notes-see-all')), findsOneWidget);
  });

  testWidgets('misafir "not bırak"a basınca ÜYELİK KAPISI çıkar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeCommunityGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('note-add')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ücretsiz bir hesap gerekir'), findsOneWidget);
  });

  testWidgets('faydalı oyu sayacı yerinde güncellenir (liste yeniden çekilmez)',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[
      makeNote(id: 'a', body: 'Faydalı bulunacak bir not.'),
    ]);
    await tester.pumpWidget(_app(gw, signedIn: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('note-helpful-a')));
    await tester.pumpAndSettle();

    expect(gw.reactions, hasLength(1));
    expect(gw.reactions.first.reaction, 'helpful');
    expect(find.textContaining('Faydalı · 1'), findsOneWidget);
  });

  testWidgets('doğrulama/çelişki düğmeleri YALNIZ uyarı notunda görünür',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[
      makeNote(id: 'h', kind: NoteKind.hazard, body: 'Batık kaya.', confirmCount: 3),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[communityGatewayProvider.overrideWithValue(gw)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HazardNotesBand(locationId: 'loc-1')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('note-confirm-h')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note-dispute-h')), findsOneWidget);
    expect(find.textContaining('3 denizci doğruladı'), findsOneWidget);
  });

  testWidgets('uyarı yoksa şerit HİÇ çizilmez', (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway(notes: <Note>[makeNote(id: 'e')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[communityGatewayProvider.overrideWithValue(gw)],
        child: const MaterialApp(
          home: Scaffold(body: HazardNotesBand(locationId: 'loc-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsNothing);
  });
}
