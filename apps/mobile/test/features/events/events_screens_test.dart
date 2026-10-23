import 'package:dockly_api/dockly_api.dart' show DealView, EventView;
import 'package:dockly_mobile/features/events/application/events_controller.dart';
import 'package:dockly_mobile/features/events/domain/events_gateway.dart';
import 'package:dockly_mobile/features/events/presentation/event_detail_screen.dart';
import 'package:dockly_mobile/features/events/presentation/events_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// ETKİNLİKLER ekran testleri (V1 — kurucu onayı 2026-10-23).
/// Kural (docs/15): ağ yok — geçit sahtedir; kilit/kontenjan kararları sahte
/// sunucu yanıtlarıyla taklit edilir.

EventView ev({
  String id = 'e1',
  int registeredCount = 18,
  int quota = 25,
  bool registered = false,
  String status = 'published',
  String audience = 'all',
}) =>
    EventView(
      id: id,
      title: 'Göcek Koy Buluşması',
      body: 'Sonbahar buluşması — koyda demirleyip tanışıyoruz.',
      startsAt: DateTime.utc(2026, 11, 7, 11),
      endsAt: null,
      locationText: 'Göcek, Boynuz Koyu',
      quota: quota,
      registeredCount: registeredCount,
      remaining: quota - registeredCount,
      registrationDeadline: DateTime.utc(2026, 11, 5, 21),
      priceNote: 'Ücretsiz',
      conditions: null,
      organizer: 'Koybul',
      audience: audience,
      status: status,
      registered: registered,
      full: registeredCount >= quota,
    );

DealView deal({
  String id = 'd1',
  String? code = 'KOYBUL15',
  bool locked = false,
  String audience = 'all',
  bool expired = false,
}) =>
    DealView(
      id: id,
      title: 'Hafta içi kiralama fırsatı',
      partner: 'Örnek Tekne Kiralama',
      benefit: '%15 indirim',
      code: code,
      locked: locked,
      audience: audience,
      validUntil: DateTime.utc(2026, 11, 30),
      terms: null,
      place: null,
      expired: expired,
    );

class FakeEventsGateway implements EventsGateway {
  FakeEventsGateway({
    this.eventRows = const <EventView>[],
    this.dealRows = const <DealView>[],
  });

  List<EventView> eventRows;
  List<DealView> dealRows;
  final List<String> registerCalls = <String>[];
  final List<String> cancelCalls = <String>[];
  int remainingAfterRegister = 6;

  @override
  Future<List<DealView>> deals() async => dealRows;

  @override
  Future<List<EventView>> events() async => eventRows;

  @override
  Future<EventView> event(String eventId) async =>
      eventRows.firstWhere((EventView e) => e.id == eventId);

  @override
  Future<({bool registered, int remaining})> register(String eventId) async {
    registerCalls.add(eventId);
    return (registered: true, remaining: remainingAfterRegister);
  }

  @override
  Future<void> cancel(String eventId) async => cancelCalls.add(eventId);
}

Widget _app(FakeEventsGateway gw, Widget home) => ProviderScope(
      overrides: <Override>[eventsGatewayProvider.overrideWithValue(gw)],
      child: MaterialApp(home: home),
    );

void main() {
  testWidgets('liste: kontenjan çubuğu, iptal rozeti ve kayıtlı durumu çizilir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeEventsGateway gw = FakeEventsGateway(eventRows: <EventView>[
      ev(),
      ev(id: 'e-dolu', registeredCount: 25),
      ev(id: 'e-iptal', status: 'cancelled'),
      ev(id: 'e-benim', registered: true),
    ]);
    await tester.pumpWidget(_app(gw, const EventsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ev-item-e1')), findsOneWidget);
    expect(find.textContaining('18 / 25 kayıt'), findsOneWidget);
    expect(find.textContaining('KONTENJAN DOLDU'), findsOneWidget);
    expect(find.text('İPTAL'), findsOneWidget);
    expect(find.text('Kayıtlısın ✓'), findsOneWidget);
  });

  testWidgets('fırsatlar: açık kod kopyalanabilir, kilitli kod görünmez',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeEventsGateway gw = FakeEventsGateway(dealRows: <DealView>[
      deal(),
      deal(id: 'd-prem', code: null, locked: true, audience: 'premium'),
    ]);
    await tester.pumpWidget(_app(gw, const EventsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fırsatlar'));
    await tester.pumpAndSettle();

    expect(find.text('KOYBUL15'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deal-copy-d1')), findsOneWidget);
    // Kilitli kodda metin YOK — yalnız dürüst rozet + kilit düğmesi.
    expect(find.textContaining('Premium üyelere özel'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deal-unlock-d-prem')), findsOneWidget);
  });

  testWidgets('detay: kayıt düğmesi geçide ulaşır, onay mesajı görünür',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeEventsGateway gw = FakeEventsGateway(eventRows: <EventView>[ev()]);
    await tester.pumpWidget(_app(gw, const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ev-register')));
    await tester.pumpAndSettle();

    expect(gw.registerCalls, <String>['e1']);
    expect(find.textContaining('Kayıt tamam'), findsOneWidget);
  });

  testWidgets('detay: kayıtlıyken iptal akışı çalışır', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeEventsGateway gw =
        FakeEventsGateway(eventRows: <EventView>[ev(registered: true)]);
    await tester.pumpWidget(_app(gw, const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ev-registered')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('ev-cancel')));
    await tester.pumpAndSettle();
    expect(gw.cancelCalls, <String>['e1']);
    expect(find.textContaining('iptal edildi'), findsOneWidget);
  });

  testWidgets('detay: dolu etkinlikte düğme pasif + dürüst not; iptalde şerit',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeEventsGateway dolu =
        FakeEventsGateway(eventRows: <EventView>[ev(registeredCount: 25)]);
    await tester.pumpWidget(_app(dolu, const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();
    final FilledButton btn = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('ev-register')));
    expect(btn.onPressed, isNull); // pasif
    expect(find.textContaining('İptal eden olursa'), findsOneWidget);
    expect(dolu.registerCalls, isEmpty);

    final FakeEventsGateway iptal =
        FakeEventsGateway(eventRows: <EventView>[ev(status: 'cancelled')]);
    await tester.pumpWidget(_app(iptal, const EventDetailScreen(eventId: 'e1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('ev-cancelled')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ev-register')), findsNothing);
  });
}
