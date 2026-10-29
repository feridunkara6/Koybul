import 'package:dockly_api/dockly_api.dart'
    show DealView, EventAttendee, EventView;
import 'package:dockly_mobile/features/admin/application/admin_controller.dart';
import 'package:dockly_mobile/features/auth/presentation/account_gate.dart'
    show AccountRequiredSheetBody;
import 'package:dockly_mobile/features/events/application/events_controller.dart';
import 'package:dockly_mobile/features/events/domain/events_gateway.dart';
import 'package:dockly_mobile/features/events/presentation/event_create_screen.dart';
import 'package:dockly_mobile/features/events/presentation/event_detail_screen.dart';
import 'package:dockly_mobile/features/events/presentation/events_screen.dart';
import 'package:dockly_mobile/features/premium/application/premium_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// KULLANICI ETKİNLİKLERİ testleri (SP-4, kurucu onayı 2026-10-31).
/// Kurucu kuralları sınanır: düğme herkese görünür; misafirde hesap kapısı,
/// ücretsiz üyede Premium tanıtımı; rızalı katılımcı listesi varsayılan
/// KAPALI. Kural (docs/15): ağ yok — geçit sahtedir.

EventView ev({
  String id = 'e1',
  String status = 'published',
  bool mine = false,
  bool community = false,
  String? template,
}) =>
    EventView(
      id: id,
      title: 'Boynuz Koyu kahvaltı buluşması',
      body: 'Sabah koyda demirleyip kahvaltıda tanışalım.',
      startsAt: DateTime.now().add(const Duration(days: 7)),
      endsAt: null,
      locationText: 'Göcek, Boynuz Koyu',
      quota: 10,
      registeredCount: 3,
      remaining: 7,
      registrationDeadline: null,
      priceNote: null,
      conditions: null,
      organizer: 'Kaptan Levent',
      audience: 'members',
      status: status,
      registered: false,
      full: false,
      template: template,
      mine: mine,
      community: community,
    );

class FakeGw implements EventsGateway {
  FakeGw({this.eventRows = const <EventView>[]});

  List<EventView> eventRows;
  final List<Map<String, Object?>> created = <Map<String, Object?>>[];
  final List<bool> showNames = <bool>[];
  final List<String> cancelOwnCalls = <String>[];
  List<EventAttendee> attendeeRows = const <EventAttendee>[];

  @override
  Future<List<DealView>> deals() async => const <DealView>[];

  @override
  Future<List<EventView>> events() async => eventRows;

  @override
  Future<EventView> event(String eventId) async =>
      eventRows.firstWhere((EventView e) => e.id == eventId);

  @override
  Future<({bool registered, int remaining})> register(
    String eventId, {
    bool showName = false,
  }) async {
    showNames.add(showName);
    return (registered: true, remaining: 6);
  }

  @override
  Future<void> cancel(String eventId) async {}

  @override
  Future<String> createEvent({
    required String template,
    required String title,
    required String body,
    required DateTime startsAt,
    required String locationText,
    required int quota,
  }) async {
    created.add(<String, Object?>{
      'template': template,
      'title': title,
      'quota': quota,
      'locationText': locationText,
    });
    return 'e-new';
  }

  @override
  Future<void> cancelOwnEvent(String eventId) async =>
      cancelOwnCalls.add(eventId);

  @override
  Future<List<EventAttendee>> attendees(String eventId) async => attendeeRows;
}

Widget _app(
  FakeGw gw,
  Widget home, {
  bool signedIn = false,
  bool premium = false,
}) =>
    ProviderScope(
      overrides: <Override>[
        eventsGatewayProvider.overrideWithValue(gw),
        isPremiumActiveProvider.overrideWithValue(premium),
        isAdminProvider.overrideWithValue(false),
        if (signedIn) signedInAuthOverride(),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  testWidgets('düğme herkese görünür; misafir dokununca HESAP kapısı açılır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw();
    await tester.pumpWidget(_app(gw, const EventsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ev-create-btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('ev-create-btn')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountRequiredSheetBody), findsOneWidget);
    expect(gw.created, isEmpty);
  });

  testWidgets('ücretsiz üye dokununca PREMIUM tanıtımı açılır (sıkmadan, tek sayfa)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw();
    await tester.pumpWidget(_app(gw, const EventsScreen(), signedIn: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ev-create-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Etkinlik kurma Premium ayrıcalığı'), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('ev-create-premium-cta')), findsOneWidget);
    expect(gw.created, isEmpty);
  });

  testWidgets('premium üye: form açılır, doldurup gönderince geçide ulaşır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw();
    await tester.pumpWidget(
        _app(gw, const EventsScreen(), signedIn: true, premium: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ev-create-btn')));
    await tester.pumpAndSettle();
    expect(find.byType(EventCreateScreen), findsOneWidget);

    // Şablon değiştir: birlikte seyir.
    await tester.tap(find.byKey(const ValueKey<String>('evc-tpl-joint_sail')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey<String>('evc-title')),
        'Gökova batısına beraber inelim');
    await tester.enterText(find.byKey(const ValueKey<String>('evc-body')),
        'Sabah 09:00 çıkış; akşam Sarsala demiri. VHF 72.');
    await tester.enterText(
        find.byKey(const ValueKey<String>('evc-place')), 'Göcek önü');
    await tester.ensureVisible(find.byKey(const ValueKey<String>('evc-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('evc-send')));
    await tester.pumpAndSettle();

    expect(gw.created, hasLength(1));
    expect(gw.created.single['template'], 'joint_sail');
    expect(gw.created.single['quota'], 10);
    expect(find.textContaining('onaya gönderildi'), findsOneWidget);
  });

  testWidgets('detay: rıza kutusu VARSAYILAN kapalı; işaretlenince kayıtla gider',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw(eventRows: <EventView>[ev()]);
    await tester.pumpWidget(
        _app(gw, const EventDetailScreen(eventId: 'e1'), signedIn: true));
    await tester.pumpAndSettle();

    // Önce işaretlemeden kaydol → false gider (gizlilik önce).
    await tester.tap(find.byKey(const ValueKey<String>('ev-register')));
    await tester.pumpAndSettle();
    expect(gw.showNames, <bool>[false]);
  });

  testWidgets('detay: rıza kutusu işaretlenince showName=true gider',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw(eventRows: <EventView>[ev()]);
    await tester.pumpWidget(
        _app(gw, const EventDetailScreen(eventId: 'e1'), signedIn: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ev-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ev-register')));
    await tester.pumpAndSettle();
    expect(gw.showNames, <bool>[true]);
  });

  testWidgets('detay: rızalı katılımcılar listelenir (yalnız izin verenler)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw(eventRows: <EventView>[ev(community: true)])
      ..attendeeRows = const <EventAttendee>[
        EventAttendee(displayName: 'Kaptan Aylin', levelCode: 'guide'),
      ];
    await tester.pumpWidget(
        _app(gw, const EventDetailScreen(eventId: 'e1'), signedIn: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kaptan Aylin'), findsOneWidget);
    expect(find.textContaining('Yalnız izin veren'), findsOneWidget);
  });

  testWidgets('detay: kendi bekleyen etkinliğim — rozet + kurucu iptali akışı',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeGw gw = FakeGw(eventRows: <EventView>[
      ev(status: 'pending', mine: true, community: true, template: 'bay_meetup'),
    ]);
    await tester.pumpWidget(
        _app(gw, const EventDetailScreen(eventId: 'e1'), signedIn: true));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey<String>('ev-pending-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ev-register')), findsNothing);

    await tester
        .ensureVisible(find.byKey(const ValueKey<String>('ev-cancel-own')));
    await tester.tap(find.byKey(const ValueKey<String>('ev-cancel-own')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey<String>('ev-cancel-own-confirm')));
    await tester.pumpAndSettle();

    expect(gw.cancelOwnCalls, <String>['e1']);
  });
}
