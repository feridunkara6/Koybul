import 'package:dockly_api/dockly_api.dart'
    show
        AdminContentItem,
        AdminDealInput,
        AdminEventInput,
        AdminPremiumGrant,
        AdminStats,
        DealView,
        EventAttendee,
        EventParticipantView,
        EventView;
import 'package:dockly_mobile/features/admin/application/admin_controller.dart';
import 'package:dockly_mobile/features/admin/domain/admin_gateway.dart';
import 'package:dockly_mobile/features/admin/presentation/admin_deals_screen.dart';
import 'package:dockly_mobile/features/admin/presentation/admin_events_screen.dart';
import 'package:dockly_mobile/features/events/application/events_controller.dart';
import 'package:dockly_mobile/features/events/domain/events_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PANEL etkinlik/fırsat yönetimi testleri (V1 — kurucu onayı 2026-10-23).

EventView ev({String id = 'e1', String status = 'published'}) => EventView(
      id: id,
      title: 'Göcek Koy Buluşması',
      body: 'Sonbahar buluşması — koyda demirleyip tanışıyoruz.',
      startsAt: DateTime.utc(2026, 11, 7, 11),
      endsAt: null,
      locationText: 'Göcek, Boynuz Koyu',
      quota: 25,
      registeredCount: 18,
      remaining: 7,
      registrationDeadline: null,
      priceNote: null,
      conditions: null,
      organizer: 'Koybul',
      audience: 'all',
      status: status,
      registered: false,
      full: false,
    );

DealView deal({String id = 'd1'}) => DealView(
      id: id,
      title: 'Hafta içi kiralama fırsatı',
      partner: 'Örnek Tekne Kiralama',
      benefit: '%15 indirim',
      code: 'KOYBUL15',
      locked: false,
      audience: 'all',
      validUntil: null,
      terms: null,
      place: null,
      expired: false,
    );

class FakeAdminGw implements AdminGateway {
  final List<String> cancelled = <String>[];
  final List<AdminEventInput> createdEvents = <AdminEventInput>[];
  final List<AdminDealInput> createdDeals = <AdminDealInput>[];
  final List<(String, bool)> dealToggles = <(String, bool)>[];

  @override
  Future<AdminStats> stats() async => const AdminStats(
        totalUsers: 1,
        guestUsers: 0,
        newUsers7d: 0,
        premiumActive: 0,
        pendingModeration: 0,
        totalReviews: 0,
        totalNotes: 0,
      );

  @override
  Future<AdminPremiumGrant> grantPremium({
    required String email,
    required int months,
  }) async =>
      AdminPremiumGrant(email: email, premiumUntil: DateTime.utc(2027));

  @override
  Future<String> createEvent(AdminEventInput input) async {
    createdEvents.add(input);
    return 'e-new';
  }

  @override
  Future<void> cancelEvent(String eventId) async => cancelled.add(eventId);

  @override
  Future<List<EventParticipantView>> participants(String eventId) async =>
      <EventParticipantView>[
        EventParticipantView(
          displayName: 'Kaptan M.',
          email: 'kaptan@ornek.com',
          registeredAt: DateTime.utc(2026, 10, 23),
        ),
      ];

  @override
  Future<String> createDeal(AdminDealInput input) async {
    createdDeals.add(input);
    return 'd-new';
  }

  @override
  Future<void> setDealActive(String dealId, {required bool isActive}) async =>
      dealToggles.add((dealId, isActive));

  // İçerik yönetimi (2026-10-27) — bu dosyanın testleri kullanmaz.
  @override
  Future<List<AdminContentItem>> listContent(String type) async =>
      const <AdminContentItem>[];

  @override
  Future<void> deleteContent({required String type, required String id}) async {}
}

class FakeEventsGw implements EventsGateway {
  FakeEventsGw({this.eventRows = const <EventView>[], this.dealRows = const <DealView>[]});

  List<EventView> eventRows;
  List<DealView> dealRows;

  @override
  Future<List<DealView>> deals() async => dealRows;

  @override
  Future<List<EventView>> events() async => eventRows;

  @override
  Future<EventView> event(String eventId) async =>
      eventRows.firstWhere((EventView e) => e.id == eventId);

  @override
  Future<({bool registered, int remaining})> register(
    String eventId, {
    bool showName = false,
  }) async =>
      (registered: true, remaining: 0);

  @override
  Future<void> cancel(String eventId) async {}

  // --- SP-4 (2026-10-31): bu sahte yönetici ekranları içindir — sessiz. ---

  @override
  Future<String> createEvent({
    required String template,
    required String title,
    required String body,
    required DateTime startsAt,
    required String locationText,
    required int quota,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cancelOwnEvent(String eventId) => throw UnimplementedError();

  @override
  Future<List<EventAttendee>> attendees(String eventId) async =>
      const <EventAttendee>[];
}

/// Kök rotayı koruyan başlatıcı (composer pop güvenliği — marina testi dersi).
class _Launcher extends StatelessWidget {
  const _Launcher(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => child),
          ),
          child: const Text('aç'),
        ),
      ),
    );
  }
}

Widget _app({
  required FakeAdminGw admin,
  required FakeEventsGw events,
  required Widget home,
}) {
  return ProviderScope(
    overrides: <Override>[
      adminGatewayProvider.overrideWithValue(admin),
      eventsGatewayProvider.overrideWithValue(events),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('panel/etkinlik: iptal onay ister, onayda geçide ulaşır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeAdminGw admin = FakeAdminGw();
    final FakeEventsGw events = FakeEventsGw(eventRows: <EventView>[ev()]);
    await tester.pumpWidget(
        _app(admin: admin, events: events, home: const AdminEventsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('adm-ev-cancel-e1')));
    await tester.pumpAndSettle();
    expect(admin.cancelled, isEmpty); // onaysız iş yok
    await tester
        .tap(find.byKey(const ValueKey<String>('adm-ev-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(admin.cancelled, <String>['e1']);
  });

  testWidgets('panel/etkinlik: katılımcı listesi ad + e-posta gösterir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeAdminGw admin = FakeAdminGw();
    final FakeEventsGw events = FakeEventsGw(eventRows: <EventView>[ev()]);
    await tester.pumpWidget(
        _app(admin: admin, events: events, home: const AdminEventsScreen()));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('adm-ev-participants-e1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('kaptan@ornek.com'), findsOneWidget);
  });

  testWidgets('panel/etkinlik formu: eksikte geçit çağrılmaz; doluda oluşturur',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeAdminGw admin = FakeAdminGw();
    final FakeEventsGw events = FakeEventsGw();
    await tester.pumpWidget(_app(
        admin: admin,
        events: events,
        home: const _Launcher(AdminEventComposer())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('adm-ev-save')));
    await tester.pumpAndSettle();
    expect(admin.createdEvents, isEmpty);
    expect(find.textContaining('Zorunlu'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('adm-ev-title')),
        'Göcek Koy Buluşması');
    await tester.enterText(find.byKey(const ValueKey<String>('adm-ev-body')),
        'Sonbahar buluşması — koyda demirleyip tanışıyoruz.');
    await tester.enterText(
        find.byKey(const ValueKey<String>('adm-ev-location')), 'Göcek');
    await tester.tap(find.byKey(const ValueKey<String>('adm-ev-aud-premium')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('adm-ev-save')));
    await tester.tap(find.byKey(const ValueKey<String>('adm-ev-save')));
    await tester.pumpAndSettle();

    expect(admin.createdEvents, hasLength(1));
    expect(admin.createdEvents.single.quota, 25); // varsayılan kontenjan
    expect(admin.createdEvents.single.audience, 'premium');
  });

  testWidgets('panel/fırsat: anahtar pasifleştirir; form yeni fırsat oluşturur',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeAdminGw admin = FakeAdminGw();
    final FakeEventsGw events = FakeEventsGw(dealRows: <DealView>[deal()]);
    await tester.pumpWidget(
        _app(admin: admin, events: events, home: const AdminDealsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('adm-deal-active-d1')));
    await tester.pumpAndSettle();
    expect(admin.dealToggles, <(String, bool)>[('d1', false)]);

    // Form — başlatıcı üzerinden (pop güvenliği).
    await tester.pumpWidget(_app(
        admin: admin,
        events: events,
        home: const _Launcher(AdminDealComposer())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('adm-deal-partner')), 'Örnek Market');
    await tester.enterText(find.byKey(const ValueKey<String>('adm-deal-title')),
        'Emniyet ekipmanı fırsatı');
    await tester.enterText(
        find.byKey(const ValueKey<String>('adm-deal-benefit')), '%10 indirim');
    await tester.enterText(
        find.byKey(const ValueKey<String>('adm-deal-code')), 'DENIZ10');
    await tester
        .ensureVisible(find.byKey(const ValueKey<String>('adm-deal-save')));
    await tester.tap(find.byKey(const ValueKey<String>('adm-deal-save')));
    await tester.pumpAndSettle();

    expect(admin.createdDeals, hasLength(1));
    expect(admin.createdDeals.single.code, 'DENIZ10');
    expect(admin.createdDeals.single.audience, 'all');
  });
}
