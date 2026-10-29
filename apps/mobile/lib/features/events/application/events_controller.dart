import 'package:dockly_api/dockly_api.dart' show DealView, EventAttendee, EventView;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/api_events_gateway.dart';
import '../domain/events_gateway.dart';

/// ETKİNLİKLER & FIRSATLAR orkestrasyonu (V1 — kurucu onayı 2026-10-23).
/// Kilitler ve kontenjan SUNUCUDA; istemci yalnız sonucu çizer.

final Provider<EventsGateway> eventsGatewayProvider = Provider<EventsGateway>((ref) {
  return ApiEventsGateway(
    ref.watch(eventsApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Yaklaşan etkinlikler (iptal edilen gelecekler dâhil — dürüst liste).
final AutoDisposeFutureProvider<List<EventView>> eventsFeedProvider =
    FutureProvider.autoDispose<List<EventView>>((ref) {
  return ref.watch(eventsGatewayProvider).events();
});

/// Aktif fırsatlar — kilitli kodlar sunucudan null gelir.
final AutoDisposeFutureProvider<List<DealView>> dealsProvider =
    FutureProvider.autoDispose<List<DealView>>((ref) {
  return ref.watch(eventsGatewayProvider).deals();
});

/// Etkinlik detayı — kayıt/iptal sonrası invalidate ile tazelenir.
final AutoDisposeFutureProviderFamily<EventView, String> eventDetailProvider =
    FutureProvider.autoDispose.family<EventView, String>((ref, String id) {
  return ref.watch(eventsGatewayProvider).event(id);
});

/// RIZALI katılımcılar (SP-4) — hesapsızda sunucuya hiç gidilmez (boş liste;
/// zaten detaydaki bölüm misafire çizilmez). Tür BİLEREK çıkarımda bırakılır
/// (CI dersi, invalid_assignment).
final attendeesProvider =
    FutureProvider.autoDispose.family<List<EventAttendee>, String>(
        (ref, String id) async {
  final AuthState s = ref.watch(authControllerProvider);
  if (s is! Authenticated || s.isGuest) return const <EventAttendee>[];
  return ref.watch(eventsGatewayProvider).attendees(id);
});

/// Tarih biçimi: 07.11.2026 · 14:00 (yerel saat; ek paket gerekmez).
String formatEventMoment(DateTime utc) {
  final DateTime d = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} · ${two(d.hour)}:${two(d.minute)}';
}
