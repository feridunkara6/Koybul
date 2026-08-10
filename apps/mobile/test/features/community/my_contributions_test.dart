import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/contributions_block.dart';
import 'package:dockly_mobile/features/community/presentation/my_contributions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';

const SessionUser moderator =
    SessionUser(id: 'm1', role: 'moderator', isGuest: false, locale: 'tr');

/// PROFİL'deki katkı bloğu ve "Katkılarım" ekranı.
void main() {
  Widget block(List<Override> extra) => ProviderScope(
        overrides: extra,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: <Widget>[ContributionsBlock(), ModerationRow()]),
            ),
          ),
        ),
      );

  testWidgets('MİSAFİR: ne katkı bloğu ne moderasyon satırı çizilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(block(<Override>[]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('contributions-block')), findsNothing);
    expect(find.byKey(const ValueKey<String>('profile-moderation')), findsNothing);
  });

  testWidgets('HESAP VAR: üç sayaç görünür, moderasyon satırı GÖRÜNMEZ',
      (WidgetTester tester) async {
    await tester.pumpWidget(block(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('contrib-approved')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('contrib-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('contrib-rejected')), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('profile-moderation')), findsNothing);
  });

  testWidgets('MODERATÖR: moderasyon satırı bekleyen sayısıyla görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(block(<Override>[
      signedInAuthOverride(user: moderator),
      reputationGatewayProvider.overrideWithValue(
        FakeReputationGateway(counts: <String, int>{'note': 6, 'review': 3}),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('profile-moderation')), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('sayaca dokunmak Katkılarım ekranını DOĞRU sekmede açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(block(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
      communityGatewayProvider.overrideWithValue(
        FakeCommunityGateway(notes: <Note>[makeNote(status: 'pending')]),
      ),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('contrib-pending')));
    await tester.pumpAndSettle();

    expect(find.text('Katkılarım'), findsOneWidget);
    expect(find.textContaining('24 saat içinde'), findsOneWidget);
    // Kendi katkısına oy verilemez: eylem düğmeleri çizilmez.
    expect(find.byKey(const ValueKey<String>('note-helpful-n1')), findsNothing);
  });

  testWidgets('Katkılarım: liste boşsa dürüst boş metin',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        signedInAuthOverride(),
        reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
        communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      ],
      child: const MaterialApp(home: MyContributionsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('contrib-empty')), findsOneWidget);
  });
}
