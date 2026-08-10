import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/badges_screen.dart';
import 'package:dockly_mobile/features/community/presentation/contribution_points_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';

/// ROZETLER + KATKI PUANI ekranları. İki ilke test edilir:
/// (1) kazanılmayan rozet GİZLENMEZ, nerede kalındığı yazar;
/// (2) altyapısı olmayan rozet "yakında" der — sahte ilerleme göstermez.
void main() {
  Widget wrap(Widget child, FakeReputationGateway gw) => ProviderScope(
        overrides: <Override>[
          signedInAuthOverride(),
          reputationGatewayProvider.overrideWithValue(gw),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('kazanılan rozet bölge adıyla, kazanılmayan ilerlemeyle çizilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const BadgesScreen(),
      FakeReputationGateway(
        summary: makeSummary(badges: <BadgeProgress>[
          makeBadge(
            code: 'area_expert',
            earned: true,
            current: 22,
            target: 15,
            scopeId: 'a1',
            scopeName: 'Fethiye',
          ),
          makeBadge(code: 'safety_watch', current: 4, target: 5),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fethiye Bilirkişisi'), findsOneWidget);
    expect(find.text('Henüz kazanılmayan'), findsOneWidget);
    expect(find.text('Emniyet Gözcüsü'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    // Koşul metni eşiği SUNUCUDAN alır, gömmez.
    expect(find.text('5 uyarı notun doğrulandı'), findsOneWidget);
  });

  testWidgets('altyapısı olmayan rozet "yakında" der ve ilerleme çubuğu ÇİZMEZ',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const BadgesScreen(),
      FakeReputationGateway(
        summary: makeSummary(badges: <BadgeProgress>[
          makeBadge(code: 'verified_boat', current: 0, target: 1, automatic: false),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Doğrulanmış Tekne'), findsOneWidget);
    expect(find.text('yakında'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('0/1'), findsNothing);
  });

  testWidgets('hiç rozet yoksa açıklama gösterilir, ekran boş kalmaz',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const BadgesScreen(),
      FakeReputationGateway(summary: makeSummary(badges: <BadgeProgress>[])),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Henüz rozetin yok'), findsOneWidget);
  });

  testWidgets('KATKI PUANI: olaylar Türkçe etiketle ve işaretli puanla listelenir',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const ContributionPointsScreen(),
      FakeReputationGateway(
        contributions: const <ContributionItem>[
          ContributionItem(
            id: '1',
            type: 'note_approved',
            points: 12,
            createdAt: '2026-08-06T09:00:00.000Z',
          ),
          ContributionItem(
            id: '2',
            type: 'content_rejected',
            points: -10,
            createdAt: '2026-08-05T09:00:00.000Z',
          ),
          // Tavan dolduğunda olay YİNE kaydedilir, puanı 0 olur.
          ContributionItem(
            id: '3',
            type: 'occupancy_reported',
            points: 0,
            createdAt: '2026-08-04T09:00:00.000Z',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kaptan notu'), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(find.text('Reddedilen içerik'), findsOneWidget);
    expect(find.text('-10'), findsOneWidget);
    expect(find.text('Yer durumu'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    // Güven katsayısı iki basamakla yazılır (0,00–1,50 aralığı).
    expect(find.text('Güven katsayısı 1.20'), findsOneWidget);
  });

  testWidgets('KATKI PUANI: hiç katkı yoksa dürüst boş metin',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const ContributionPointsScreen(),
      FakeReputationGateway(contributions: <ContributionItem>[]),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Henüz puan kazandıran'), findsOneWidget);
  });
}
