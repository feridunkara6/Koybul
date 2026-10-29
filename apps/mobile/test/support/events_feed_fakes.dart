import 'package:dockly_api/dockly_api.dart'
    show DealView, EventAttendee, EventView;
import 'package:dockly_mobile/features/events/domain/events_gateway.dart';

/// Etkinlik LİSTESİ/DETAYI okuyan ekranlar için sahte geçit (docs/15: ağ yok).
class FakeEventsFeedGateway implements EventsGateway {
  FakeEventsFeedGateway({
    this.eventsResult = const <EventView>[],
    this.dealsResult = const <DealView>[],
  });

  List<EventView> eventsResult;
  List<DealView> dealsResult;

  @override
  Future<List<EventView>> events() async => eventsResult;

  @override
  Future<List<DealView>> deals() async => dealsResult;

  @override
  Future<EventView> event(String eventId) async =>
      eventsResult.firstWhere((EventView e) => e.id == eventId);

  @override
  Future<({bool registered, int remaining})> register(
    String eventId, {
    bool showName = false,
  }) =>
      throw UnimplementedError('feed sahtesi kayıt taşımaz');

  @override
  Future<void> cancel(String eventId) => throw UnimplementedError();

  // --- SP-4 (2026-10-31): bu sahte okuma ekranları içindir — boş/sessiz. ---

  @override
  Future<String> createEvent({
    required String template,
    required String title,
    required String body,
    required DateTime startsAt,
    required String locationText,
    required int quota,
  }) =>
      throw UnimplementedError('feed sahtesi etkinlik kurmaz');

  @override
  Future<void> cancelOwnEvent(String eventId) => throw UnimplementedError();

  @override
  Future<List<EventAttendee>> attendees(String eventId) async =>
      const <EventAttendee>[];
}

/// Hazır örnek etkinlik — testlerin kurduğu teknik yer tutucu (ÖRNEK VERİ).
EventView sampleEvent({
  String id = 'ev1',
  String title = 'Koybul Kaptan Buluşması',
  DateTime? startsAt,
  String status = 'published',
}) {
  return EventView(
    id: id,
    title: title,
    body: 'Sezon kapanışı sohbeti.',
    startsAt: startsAt ?? DateTime.now().add(const Duration(days: 7)),
    endsAt: null,
    locationText: 'Göcek',
    quota: 25,
    registeredCount: 3,
    remaining: 22,
    registrationDeadline: null,
    priceNote: null,
    conditions: null,
    organizer: 'Koybul',
    audience: 'all',
    status: status,
    registered: false,
    full: false,
  );
}
