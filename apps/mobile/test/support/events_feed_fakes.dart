import 'package:dockly_api/dockly_api.dart' show DealView, EventView;
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
  Future<({bool registered, int remaining})> register(String eventId) =>
      throw UnimplementedError('feed sahtesi kayıt taşımaz');

  @override
  Future<void> cancel(String eventId) => throw UnimplementedError();
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
