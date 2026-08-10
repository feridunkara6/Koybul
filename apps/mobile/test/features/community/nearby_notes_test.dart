import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/core/l10n/l10n_strings.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/community/presentation/nearby_notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';

/// BUGÜN'ün "Yakında paylaşılanlar" kartı. Not yoksa kart HİÇ ÇİZİLMEZ;
/// okuma anonimdir (misafir de görür).
void main() {
  const GeoPoint pos = GeoPoint(lat: 36.62, lon: 29.12);

  Widget wrap(FakeCommunityGateway gw) => ProviderScope(
        overrides: <Override>[communityGatewayProvider.overrideWithValue(gw)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NearbyNotesSection(position: pos)),
          ),
        ),
      );

  testWidgets('yakında not yoksa kart hiç çizilmez', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(FakeCommunityGateway()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('nearby-notes')), findsNothing);
  });

  testWidgets('notlar nokta adı, gövde ve mesafeyle listelenir',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(FakeCommunityGateway(nearby: <NearbyNote>[
      makeNearbyNote(distanceNm: 4),
      makeNearbyNote(
        id: 'nb2',
        kind: NoteKind.status,
        body: 'Şamandıra ücreti 450 TL oldu.',
        locationName: 'Göcek Bedri Rahmi',
        distanceNm: 12.4,
      ),
    ])));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('nearby-notes')), findsOneWidget);
    expect(find.text('Yakında paylaşılanlar'), findsOneWidget);
    expect(find.text('Kızılada'), findsOneWidget);
    expect(find.text('Göcek Bedri Rahmi'), findsOneWidget);
    expect(find.textContaining('Şamandıra ücreti'), findsOneWidget);
    // Mesafe biçimi kartlarla AYNI kuralı izler: 4.0 → "4", 12.4 → "12".
    expect(find.textContaining('4 NM'), findsOneWidget);
    expect(find.textContaining('12 NM'), findsOneWidget);
  });

  testWidgets('en fazla 3 not gösterilir — Bugün bir akış değil, özettir',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(FakeCommunityGateway(nearby: <NearbyNote>[
      for (int i = 0; i < 6; i++) makeNearbyNote(id: 'nb$i', locationName: 'Koy $i'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Koy 0'), findsOneWidget);
    expect(find.text('Koy 2'), findsOneWidget);
    expect(find.text('Koy 3'), findsNothing);
  });

  group('relativeTime', () {
    final L10n t = l10nOf(AppLocale.tr);
    final DateTime now = DateTime.utc(2026, 8, 1, 12);

    String at(Duration ago) =>
        now.subtract(ago).toUtc().toIso8601String();

    test('bir dakikadan yeni → "az önce"',
        () => expect(relativeTime(t, at(const Duration(seconds: 20)), now: now), 'az önce'));
    test('dakika', () => expect(relativeTime(t, at(const Duration(minutes: 12)), now: now), '12 dk önce'));
    test('saat', () => expect(relativeTime(t, at(const Duration(hours: 6)), now: now), '6 sa önce'));
    test('48 saatten eski → gün',
        () => expect(relativeTime(t, at(const Duration(days: 3)), now: now), '3 gün önce'));
    test('bozuk tarih ekranı çökertmez, boş döner',
        () => expect(relativeTime(t, 'öyle böyle', now: now), ''));
  });

  group('nearbyNotesKeyFor', () {
    test('koordinat yuvarlanır: aynı bölgede aynı anahtar (sonsuz istek yok)', () {
      expect(nearbyNotesKeyFor(36.6234, 29.1201), nearbyNotesKeyFor(36.6489, 29.1499));
    });

    test('uzak konum farklı anahtar üretir', () {
      expect(nearbyNotesKeyFor(36.62, 29.12) == nearbyNotesKeyFor(37.62, 29.12), isFalse);
    });
  });
}
