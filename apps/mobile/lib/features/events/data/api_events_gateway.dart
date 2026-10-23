import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/events_gateway.dart';

/// Gerçek sunucu ağ geçidi — soru-cevap/marina geçitleriyle aynı desen:
/// okuma esnek (token varsa eklenir — kitle kilidi ve "kayıtlı mıyım" için),
/// yazma katı (token şart).
class ApiEventsGateway implements EventsGateway {
  ApiEventsGateway(this._api, this._tokenProvider);

  final EventsApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _requiredToken() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<List<DealView>> deals() async => _api.deals(accessToken: await _tokenProvider());

  @override
  Future<List<EventView>> events() async =>
      _api.events(accessToken: await _tokenProvider());

  @override
  Future<EventView> event(String eventId) async =>
      _api.event(eventId, accessToken: await _tokenProvider());

  @override
  Future<({bool registered, int remaining})> register(String eventId) async =>
      _api.register(accessToken: await _requiredToken(), eventId: eventId);

  @override
  Future<void> cancel(String eventId) async =>
      _api.cancel(accessToken: await _requiredToken(), eventId: eventId);
}
