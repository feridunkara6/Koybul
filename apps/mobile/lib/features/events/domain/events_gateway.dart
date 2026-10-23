import 'package:dockly_api/dockly_api.dart' show DealView, EventView;

/// ETKİNLİKLER & FIRSATLAR ağ geçidi arayüzü (V1 — kurucu onayı 2026-10-23).
/// Gerçek implementasyon `data/api_events_gateway.dart`; testlerde sahtesi.
abstract interface class EventsGateway {
  Future<List<DealView>> deals();

  Future<List<EventView>> events();

  Future<EventView> event(String eventId);

  /// Kayıt — kontenjan/kitle kararı sunucunun; başarı kalan yeri döndürür.
  Future<({bool registered, int remaining})> register(String eventId);

  Future<void> cancel(String eventId);
}
