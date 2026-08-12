import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_screen.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/badges_screen.dart';
import 'package:dockly_mobile/features/community/presentation/sailor_profile_card.dart';
import 'package:dockly_mobile/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';
import '../../support/maintenance_fakes.dart';
import '../../support/trip_fakes.dart';

/// "Denizci Profilim" kartı — YENİ EVİ PROFİL (Teknem Konsept A, kullanıcı
/// onayı 2026-08): kart kaptanın kimliğidir, teknenin değil. Hesap yoksa HİÇ
/// çizilmez; varsa seviye + puan + bölgesel uzmanlık gösterir.
void main() {
  // Kartın kendi davranış testleri İZOLE pompalanır (Profil'in diğer
  // blokları — katkı sayaçları vb. — aynı özet sayılarını gösterebilir;
  // izole yüzey, bulguları karta kilitler).
  Widget card(List<Override> extra) => ProviderScope(
        overrides: <Override>[
          tripStoreProvider.overrideWithValue(FakeTripStore()),
          ...extra,
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SailorProfileCard()),
          ),
        ),
      );

  Widget profile(List<Override> extra) => ProviderScope(
        overrides: <Override>[
          tripStoreProvider.overrideWithValue(FakeTripStore()),
          communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          ...extra,
        ],
        child: const MaterialApp(home: ProfileScreen()),
      );

  testWidgets('YENİ EV: kart PROFİL sekmesinde (hesap varken) çizilir',
      (WidgetTester tester) async {
    // Profil listesi uzun; tembel liste görünmeyen çocuğu kurmaz — yüzey
    // büyütülür (yasal-satır testlerindeki desen).
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(profile(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')),
        findsOneWidget);
    expect(find.text('Feridun Kara'), findsOneWidget);
  });

  testWidgets('MİSAFİR: Profil\'de kart hiç çizilmez',
      (WidgetTester tester) async {
    await tester.pumpWidget(profile(<Override>[]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')),
        findsNothing);
  });

  testWidgets('ESKİ EV BOŞALDI: Teknem\'de kart artık YOK (hesaplıyken bile) '
      '— tek ev ilkesi', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
        tripStoreProvider.overrideWithValue(FakeTripStore()),
        signedInAuthOverride(),
        reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
      ],
      child: const MaterialApp(home: BoatScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')),
        findsNothing);
    // Teknem'in kendi parçaları yerli yerinde.
    expect(find.byKey(const ValueKey<String>('boat-edit')), findsOneWidget);
    expect(find.text('Bakım takibi'), findsOneWidget);
  });

  testWidgets('HESAP VAR: seviye, puan ve bölge çipi görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(card(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('sailor-profile-card')), findsOneWidget);
    // Kartın başlığı KAPTANIN ADI; baş harfler avatar olarak çizilir.
    expect(find.text('Feridun Kara'), findsOneWidget);
    expect(find.text('FK'), findsOneWidget);
    expect(find.text('Usta Kaptan'), findsOneWidget);
    // Binlik ayraç: 2840 değil 2.840.
    expect(find.text('2.840'), findsOneWidget);
    expect(find.text('Fethiye · 22 katkı'), findsOneWidget);
  });

  testWidgets('KATKI YOK: kart çizilir ama davet metni gösterir, sayı uydurmaz',
      (WidgetTester tester) async {
    await tester.pumpWidget(card(<Override>[
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

  testWidgets('ÖZET YÜKLENEMEZSE "katkın yok" DEĞİL, dürüst uyarı gösterilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(card(<Override>[
      signedInAuthOverride(),
      reputationSummaryProvider.overrideWith(
        (ref) => Future<ReputationSummary>.error(Exception('ağ yok')),
      ),
    ]));
    await tester.pumpAndSettle();

    // Kart ÇİZİLMEYE DEVAM EDER: seyir ve NM telefonda duruyor, ağ hatası
    // onları gizlememeli. Yalnız sunucudan gelen kısım "—" olur ve seviye
    // satırı yerine dürüst uyarı yazar.
    expect(find.byKey(const ValueKey<String>('sailor-profile-card')), findsOneWidget);
    expect(find.textContaining('yüklenemedi'), findsOneWidget);
    expect(find.textContaining('Henüz katkın yok'), findsNothing);
    expect(find.text('Usta Kaptan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('karttan ROZETLERİM doğrudan açılır (tasarımda karttan açılıyor)',
      (WidgetTester tester) async {
    await tester.pumpWidget(card(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('sailor-badges')));
    await tester.pumpAndSettle();

    // Kartın kendi düğmesi de 'Rozetlerim' yazıyor: metne değil EKRANA bakılır,
    // yoksa dokunuş ıskalasa bile test yeşil kalırdı.
    expect(find.byType(BadgesScreen), findsOneWidget);
    expect(find.text('Denizci Seviyem'), findsNothing);
  });

  testWidgets('karta dokunmak Denizci Seviyem ekranını açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(card(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
    ]));
    await tester.pumpAndSettle();

    // Kartın ADINA dokunulur: kartın merkezinde artık "Rozetlerim" düğmesi
    // var, merkeze dokunmak yanlış ekranı açardı.
    await tester.tap(find.text('Feridun Kara'));
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
    await tester.pumpWidget(card(<Override>[
      signedInAuthOverride(),
      reputationGatewayProvider.overrideWithValue(
        FakeReputationGateway(summary: makeSummary(levelCode: 'guide', points: 700)),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Yol Gösteren'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
  });
}
