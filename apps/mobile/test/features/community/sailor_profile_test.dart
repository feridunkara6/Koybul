import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_screen.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/sailor_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';
import '../../support/maintenance_fakes.dart';
import '../../support/trip_fakes.dart';

/// TEKNEM'deki "Denizci Profilim" kartı: hesap yoksa HİÇ çizilmez, varsa
/// seviye + puan + bölgesel uzmanlık gösterir. Bakım takibine dokunmaz.
void main() {
  Widget boat(List<Override> extra) => ProviderScope(
        overrides: <Override>[
          maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
          tripStoreProvider.overrideWithValue(FakeTripStore()),
          ...extra,
        ],
        child: const MaterialApp(home: BoatScreen()),
      );

  testWidgets('MİSAFİR: kart hiç çizilmez, bakım takibi yerinde durur',
      (WidgetTester tester) async {
    await tester.pumpWidget(boat(<Override>[]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')), findsNothing);
    expect(find.byKey(const ValueKey<String>('boat-edit')), findsOneWidget);
    expect(find.text('Bakım takibi'), findsOneWidget);
  });

  testWidgets('HESAP VAR: seviye, puan ve bölge çipi görünür; bakım korunur',
      (WidgetTester tester) async {
    await tester.pumpWidget(boat(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')), findsOneWidget);
    expect(find.text('Usta Kaptan'), findsOneWidget);
    expect(find.text('2840'), findsOneWidget);
    expect(find.text('Fethiye · 22 katkı'), findsOneWidget);
    // Mevcut ekranın hiçbir parçası kaybolmadı.
    expect(find.byKey(const ValueKey<String>('boat-edit')), findsOneWidget);
    expect(find.text('Bakım takibi'), findsOneWidget);
  });

  testWidgets('KATKI YOK: kart çizilir ama davet metni gösterir, sayı uydurmaz',
      (WidgetTester tester) async {
    await tester.pumpWidget(boat(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(
        FakeReputationGateway(
          summary: makeSummary(
            points: 0,
            levelCode: 'new',
            approvedCount: 0,
            pendingCount: 0,
            rejectedCount: 0,
            areas: <AreaExpertise>[],
          ),
        ),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Henüz katkın yok'), findsOneWidget);
    expect(find.text('Yeni Denizci'), findsOneWidget);
    // Seyir kaydı yokken NM alanı sayı UYDURMAZ.
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('ÖZET YÜKLENEMEZSE kart çökmez: boş özetle çizilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(boat(<Override>[
      signedInAuthOverride(),
      reputationSummaryProvider.overrideWith(
        (ref) => Future<ReputationSummary>.error(Exception('ağ yok')),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')), findsOneWidget);
    expect(find.text('Bakım takibi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('karta dokunmak Denizci Seviyem ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(boat(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('sailor-profile-card')));
    await tester.pumpAndSettle();

    expect(find.text('Denizci Seviyem'), findsOneWidget);
    expect(find.text('Seviye ne işe yarar?'), findsOneWidget);
    // Beklenti yönetimi: ekranda "ayrıcalık vermez" cümlesi MUTLAKA olmalı.
    expect(find.textContaining('Ayrıcalık ya da ödül vermez'), findsOneWidget);
    // Seviye listesi 5 satır; bulunulan seviyede eşik yerine "şu an" yazar.
    expect(find.text('şu an'), findsOneWidget);
    expect(find.text('Deniz Rehberi'), findsWidgets);
  });

  testWidgets('kart yalnızca SailorProfileCard olarak da çalışır (izole)',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        signedInAuthOverride(),
        tripStoreProvider.overrideWithValue(FakeTripStore()),
        reputationGatewayProvider.overrideWithValue(
          FakeReputationGateway(summary: makeSummary(levelCode: 'guide', points: 700)),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SailorProfileCard())),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Yol Gösteren'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
  });
}
