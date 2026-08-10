import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/badges_screen.dart';
import 'package:dockly_mobile/features/community/presentation/contribution_points_screen.dart';
import 'package:dockly_mobile/features/community/presentation/contributions_block.dart';
import 'package:dockly_mobile/features/community/presentation/my_contributions_screen.dart';
import 'package:dockly_mobile/features/community/presentation/sailor_level_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';

/// HATA, BOŞLUKLA KARIŞTIRILMAZ.
///
/// Bu paketin sebebi: altı ekran da `valueOrNull ?? empty` yazıyordu, yani
/// sunucuya ulaşılamadığında 2.840 puanlı bir kaptan "Henüz katkın yok"
/// görüyordu. Aşağıdaki testler her ekranda hatayı ayrı bir şey olarak
/// gösterdiğimizi kilitler.
void main() {
  Override failingSummary() => reputationSummaryProvider
      .overrideWith((ref) => Future<ReputationSummary>.error(Exception('ağ yok')));

  Widget wrap(Widget child, List<Override> extra) => ProviderScope(
        overrides: <Override>[signedInAuthOverride(), ...extra],
        child: MaterialApp(home: child),
      );

  testWidgets('Denizci Seviyem: uyarı çıkar, "0 puan / Yeni Denizci" ÇIKMAZ',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const SailorLevelScreen(), <Override>[failingSummary()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('reputation-error')), findsOneWidget);
    expect(find.text('Yeni Denizci'), findsNothing);
    expect(find.text('En üst seviyedesin.'), findsNothing);
  });

  testWidgets('Rozetlerim: uyarı çıkar, "Henüz rozetin yok" ÇIKMAZ',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const BadgesScreen(), <Override>[failingSummary()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('reputation-error')), findsOneWidget);
    expect(find.textContaining('Henüz rozetin yok'), findsNothing);
  });

  testWidgets('Katkı puanı: puan yerine "—", boş metin ÇIKMAZ',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const ContributionPointsScreen(),
      <Override>[
        failingSummary(),
        // Döküm SAĞLAM, yalnız özet düştü: liste görünmeye devam etmeli.
        reputationGatewayProvider.overrideWithValue(
          FakeReputationGateway(
            contributions: const <ContributionItem>[
              ContributionItem(
                id: '1',
                type: 'note_approved',
                points: 12,
                createdAt: '2026-08-06T09:00:00.000Z',
              ),
            ],
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('reputation-error')), findsOneWidget);
    // Puan okunamadı → "0" değil "—".
    expect(find.text('—'), findsOneWidget);
    // Sağlam olan döküm GİZLENMEZ ve boş metni çıkmaz.
    expect(find.text('+12'), findsOneWidget);
    expect(find.textContaining('Henüz puan kazandıran'), findsNothing);
  });

  testWidgets('Profil bloğu: üç sayaç yerine uyarı çıkar (0/0/0 yazılmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const Scaffold(body: SingleChildScrollView(child: ContributionsBlock())),
      <Override>[failingSummary()],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('reputation-error')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('contrib-approved')), findsNothing);
  });

  testWidgets('Katkılarım: sayaç okunamazsa "—" yazar, liste yine görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      const MyContributionsScreen(),
      <Override>[
        failingSummary(),
        communityGatewayProvider.overrideWithValue(
          FakeCommunityGateway(notes: <Note>[makeNote(status: 'approved')]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Sayaç düştü ama LİSTE sağlam: not gizlenmez.
    expect(find.text('Yayında —'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note-n1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('contrib-empty')), findsNothing);
  });

  testWidgets('TEKRAR DENE düğmesi gerçekten yeniden dener ve ekran dolar',
      (WidgetTester tester) async {
    int calls = 0;
    await tester.pumpWidget(wrap(
      const BadgesScreen(),
      <Override>[
        reputationSummaryProvider.overrideWith((ref) async {
          calls++;
          if (calls == 1) throw Exception('ilk denemede ağ yok');
          return makeSummary(badges: <BadgeProgress>[makeBadge(code: 'lighthouse', earned: true)]);
        }),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('reputation-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('reputation-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(const ValueKey<String>('reputation-error')), findsNothing);
    expect(find.text('Fener'), findsOneWidget);
  });
}
