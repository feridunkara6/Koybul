import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart' show ForbiddenFailure;
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/moderation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';

const SessionUser moderatorUser =
    SessionUser(id: 'm1', role: 'moderator', isGuest: false, locale: 'tr');

/// MODERASYON ekranı — yalnız moderatör; karar verilen kart listeden düşer;
/// RED SEBEPSİZ GÖNDERİLMEZ (sunucu sebepsiz reddi 422 ile geri çevirir).
void main() {
  Widget wrap(FakeReputationGateway gw, {SessionUser user = moderatorUser}) => ProviderScope(
        overrides: <Override>[
          signedInAuthOverride(user: user),
          reputationGatewayProvider.overrideWithValue(gw),
        ],
        child: const MaterialApp(home: ModerationScreen()),
      );

  testWidgets('kuyruk çizilir: içerik, yazar bağlamı ve onay oranı görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(FakeReputationGateway(
      queue: <ModerationItem>[makeModerationItem()],
      counts: <String, int>{'note': 6, 'review': 3},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('mod-t1')), findsOneWidget);
    expect(find.text('Kızılada'), findsOneWidget);
    expect(find.textContaining('onay oranı %96'), findsOneWidget);
    expect(find.text('Not 6'), findsOneWidget);
    expect(find.text('Yorum 3'), findsOneWidget);
  });

  testWidgets('ONAYLA: karar gönderilir ve kart listeden DÜŞER',
      (WidgetTester tester) async {
    final FakeReputationGateway gw = FakeReputationGateway(
      queue: <ModerationItem>[makeModerationItem(), makeModerationItem(taskId: 't2')],
    );
    await tester.pumpWidget(wrap(gw));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mod-approve-t1')));
    await tester.pumpAndSettle();

    expect(gw.decisions, hasLength(1));
    expect(gw.decisions.first.taskId, 't1');
    expect(gw.decisions.first.approve, isTrue);
    expect(find.byKey(const ValueKey<String>('mod-t1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('mod-t2')), findsOneWidget);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('REDDET: önce sebep sorulur; sebep seçilmeden karar GÖNDERİLMEZ',
      (WidgetTester tester) async {
    final FakeReputationGateway gw =
        FakeReputationGateway(queue: <ModerationItem>[makeModerationItem()]);
    await tester.pumpWidget(wrap(gw));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mod-reject-t1')));
    await tester.pumpAndSettle();
    expect(find.text('Red sebebi'), findsOneWidget);
    expect(gw.decisions, isEmpty);

    // Sayfa sebepsiz kapatılırsa hiçbir şey gönderilmez.
    Navigator.of(tester.element(find.text('Red sebebi'))).pop();
    await tester.pumpAndSettle();
    expect(gw.decisions, isEmpty);
    expect(find.byKey(const ValueKey<String>('mod-t1')), findsOneWidget);

    // Sebep seçilince karar sebebiyle birlikte gider.
    await tester.tap(find.byKey(const ValueKey<String>('mod-reject-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('reason-personal_data')));
    await tester.pumpAndSettle();

    expect(gw.decisions, hasLength(1));
    expect(gw.decisions.first.approve, isFalse);
    expect(gw.decisions.first.reason, 'personal_data');
    expect(find.byKey(const ValueKey<String>('mod-t1')), findsNothing);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('karar düşerse kart LİSTEDE KALIR ve ham istisna metni sızmaz',
      (WidgetTester tester) async {
    final FakeReputationGateway gw =
        FakeReputationGateway(queue: <ModerationItem>[makeModerationItem()]);
    gw.failWith = const ForbiddenFailure('Bu işlem için yetkin yok.');
    await tester.pumpWidget(wrap(gw));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mod-approve-t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('mod-t1')), findsOneWidget);
    expect(find.text('Bu işlem için yetkin yok.'), findsOneWidget);
    expect(find.textContaining('ForbiddenFailure'), findsNothing);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('MODERATÖR DEĞİLSE kuyruk hiç istenmez, ekran boş görünür',
      (WidgetTester tester) async {
    final FakeReputationGateway gw =
        FakeReputationGateway(queue: <ModerationItem>[makeModerationItem()]);
    await tester.pumpWidget(wrap(gw, user: testUser));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('moderation-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mod-t1')), findsNothing);
  });

  testWidgets('kuyruk boşsa teşekkür metni gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(FakeReputationGateway()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kuyruk boş'), findsOneWidget);
  });
}
