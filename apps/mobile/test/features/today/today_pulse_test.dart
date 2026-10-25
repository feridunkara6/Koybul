import 'package:dockly_api/dockly_api.dart'
    show
        EventView,
        MarinaBoat,
        MarinaCommunity,
        MyMarinaBoat,
        QaFeed,
        QaQuestionSummary;
// CI dersi (2026-10-23, marina testleriyle aynı): authRepositoryProvider
// auth_controller'da tanımlı — import zincirleme GEÇMEZ, burada da gerekir.
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/maintenance.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/events/application/events_controller.dart';
import 'package:dockly_mobile/features/events/presentation/event_detail_screen.dart';
import 'package:dockly_mobile/features/marina/application/marina_controller.dart';
import 'package:dockly_mobile/features/marina/domain/marina_gateway.dart';
import 'package:dockly_mobile/features/qa/application/qa_controller.dart';
import 'package:dockly_mobile/features/qa/presentation/qa_list_screen.dart';
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
import 'package:dockly_mobile/features/today/presentation/today_screen.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/checklist_fakes.dart';
import '../../support/community_fakes.dart';
import '../../support/events_feed_fakes.dart';
import '../../support/maintenance_fakes.dart';
import '../../support/qa_feed_fakes.dart';
import '../../support/weather_fakes.dart';
import '../../support/welcome_fakes.dart' show FakeBoatStorage;

/// GÜNÜN NABZI köprü kartları (K2 DENGELİ — kurucu onayı 2026-10-23).
/// Kural (docs/15): ağ yok — bütün geçitler sahte. Dürüstlük: verisi olmayan
/// köprü kendini HİÇ çizmez; sayılar yalnız sunucu sahtesinden gelir.

/// Yalnız topluluk SAYISI okuyan köprü için sahte marina geçidi.
class _FakeMarinaGateway implements MarinaGateway {
  _FakeMarinaGateway(this.communityResult);

  final MarinaCommunity communityResult;

  @override
  Future<MyMarinaBoat?> myBoat() async => null;

  @override
  Future<MarinaCommunity> community(String locationId) async =>
      communityResult;

  @override
  // CI DERSİ (2026-10-25): arayüze eklenen her yeni parametre TÜM sahte
  // geçitlere de eklenmeli — Hafta 2'de model/buildYear eklenince burası
  // invalid_override ile kırılmıştı.
  Future<MyMarinaBoat> upsertMyBoat({
    required String name,
    required String boatTypeCode,
    required double lengthM,
    String? brand,
    String? model,
    int? buildYear,
    required String marinaLocationId,
    required bool visible,
    required bool shareSpecs,
  }) =>
      throw UnimplementedError('köprü kartı yazmaz');
}

const MyBoat _boatWithMarina = MyBoat(
  lengthM: 10.4,
  name: 'Martı',
  homeMarina:
      HomeMarina(id: 'loc-marti', name: 'Martı Marina', lat: 36.77, lon: 28.12),
);

QaQuestionSummary _question({int answersCount = 7}) => QaQuestionSummary(
      id: 'q1',
      category: 'demirleme',
      title: 'Poyrazda hangi yakaya demir atmalı?',
      preview: 'Hafta sonu Boynuz planı var…',
      authorName: 'Kaptan M.',
      authorPremium: true,
      featured: true,
      likeCount: 12,
      answersCount: answersCount,
      createdAt: DateTime.utc(2026, 10, 22, 9),
    );

Widget _app({
  bool signedIn = false,
  MyBoat? boat,
  MarinaCommunity? community,
  QaFeed? qaFeed,
  List<Override> extra = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      boatStorageProvider.overrideWithValue(FakeBoatStorage(boat: boat)),
      qaGatewayProvider
          .overrideWithValue(FakeQaFeedGateway(feedResult: qaFeed)),
      if (community != null)
        marinaGatewayProvider.overrideWithValue(_FakeMarinaGateway(community)),
      if (signedIn) ...<Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        signedInAuthOverride(),
      ],
      ...extra,
    ],
    child: const MaterialApp(home: TodayScreen()),
  );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
      listen: false,
    );

void main() {
  testWidgets('misafir: Marinam köprüsü hesap daveti; veri olmayan köprüler '
      'kendini çizmez (boş iskelet yok)', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(extra: <Override>[
      eventsGatewayProvider.overrideWithValue(FakeEventsFeedGateway()),
      maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('today-marinam-signin')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('today-qa')), findsNothing);
    expect(find.byKey(const ValueKey<String>('today-event')), findsNothing);
    expect(find.byKey(const ValueKey<String>('today-maint')), findsNothing);
  });

  testWidgets('marina bağlı üye: marina adı + kayıtlı tekne sayısı; dokunuş '
      'Teknem sekmesine geçirir', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      signedIn: true,
      boat: _boatWithMarina,
      community: const MarinaCommunity(
        marinaId: 'loc-marti',
        marinaName: 'Martı Marina',
        total: 12,
        visibleCount: 3,
        access: 'counts',
        boats: <MarinaBoat>[],
      ),
      extra: <Override>[
        eventsGatewayProvider.overrideWithValue(FakeEventsFeedGateway()),
        maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('today-marinam')), findsOneWidget);
    expect(find.text('Martı Marina'), findsOneWidget);
    expect(find.text('12 kayıtlı tekne'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('today-marinam')));
    await tester.pump();
    expect(_containerOf(tester).read(shellTabProvider), 3); // Teknem
  });

  testWidgets('Soru-Cevap köprüsü: öne çıkan soru + cevap sayısı; dokunuş '
      'listeyi açar', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      qaFeed: QaFeed(
        featured: <QaQuestionSummary>[_question()],
        items: const <QaQuestionSummary>[],
      ),
      extra: <Override>[
        eventsGatewayProvider.overrideWithValue(FakeEventsFeedGateway()),
        maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('today-qa')), findsOneWidget);
    expect(find.text('Poyrazda hangi yakaya demir atmalı?'), findsOneWidget);
    expect(find.text('7 cevap'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('today-qa')));
    await tester.pumpAndSettle();
    expect(find.byType(QaListScreen), findsOneWidget);
  });

  testWidgets('etkinlik köprüsü: iptal ve geçmiş elenir, EN YAKIN gelecek '
      'gösterilir; dokunuş detayı açar', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DateTime now = DateTime.now();
    await tester.pumpWidget(_app(extra: <Override>[
      maintenanceStoreProvider.overrideWithValue(FakeMaintenanceStore()),
      eventsGatewayProvider.overrideWithValue(FakeEventsFeedGateway(
        eventsResult: <EventView>[
          // İptal edilen yarın bile olsa köprüye çıkmaz (dürüst liste
          // Etkinlikler ekranında).
          sampleEvent(
            id: 'ev-iptal',
            title: 'İptal Buluşma',
            startsAt: now.add(const Duration(days: 1)),
            status: 'cancelled',
          ),
          sampleEvent(
            id: 'ev-uzak',
            title: 'Uzak Buluşma',
            startsAt: now.add(const Duration(days: 10)),
          ),
          sampleEvent(
            id: 'ev-yakin',
            title: 'Yakın Buluşma',
            startsAt: now.add(const Duration(days: 5)),
          ),
        ],
      )),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('today-event')), findsOneWidget);
    expect(find.text('Yakın Buluşma'), findsOneWidget);
    expect(find.text('Uzak Buluşma'), findsNothing);
    expect(find.text('İptal Buluşma'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('today-event')));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
  });

  testWidgets('bakım uyarı şeridi YALNIZ ilgi bekleyen varken; dokunuş '
      'Teknem sekmesine geçirir', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Takvim aritmetiği dersi: gün alanından çıkar (DST güvenli).
    final DateTime t0 = DateTime.now();
    final DateTime old = DateTime(t0.year, t0.month, t0.day - 400);
    final FakeMaintenanceStore store = FakeMaintenanceStore()
      ..data = <MaintenanceRecord>[
        MaintenanceRecord(
          taskId: 'engine_oil',
          lastDoneMs: old.millisecondsSinceEpoch,
        ),
      ];
    await tester.pumpWidget(_app(extra: <Override>[
      eventsGatewayProvider.overrideWithValue(FakeEventsFeedGateway()),
      maintenanceStoreProvider.overrideWithValue(store),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('today-maint')), findsOneWidget);
    expect(find.textContaining('1 kalem ilgi bekliyor'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('today-maint')));
    await tester.pump();
    expect(_containerOf(tester).read(shellTabProvider), 3); // Teknem
  });
}
