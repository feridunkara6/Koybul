import 'package:dockly_api/dockly_api.dart' show DealView, EventAttendee, EventView;

/// ETKİNLİKLER & FIRSATLAR ağ geçidi arayüzü (V1 — kurucu onayı 2026-10-23).
/// Gerçek implementasyon `data/api_events_gateway.dart`; testlerde sahtesi.
abstract interface class EventsGateway {
  Future<List<DealView>> deals();

  Future<List<EventView>> events();

  Future<EventView> event(String eventId);

  /// Kayıt — kontenjan/kitle kararı sunucunun; başarı kalan yeri döndürür.
  /// [showName]: RIZALI katılımcı listesi (SP-4) — adım görünsün mü?
  Future<({bool registered, int remaining})> register(
    String eventId, {
    bool showName,
  });

  Future<void> cancel(String eventId);

  // --- KULLANICI ETKİNLİKLERİ (SP-4, kurucu onayı 2026-10-31) ---

  /// Etkinlik kurma — Premium kapısı SUNUCUDA; 'pending' doğar.
  Future<String> createEvent({
    required String template,
    required String title,
    required String body,
    required DateTime startsAt,
    required String locationText,
    required int quota,
  });

  /// Kurucunun kendi etkinliğini iptali.
  Future<void> cancelOwnEvent(String eventId);

  /// RIZALI katılımcılar — yalnız izin verenler (PII yok).
  Future<List<EventAttendee>> attendees(String eventId);
}
