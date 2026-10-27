import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/admin_gateway.dart';

/// Gerçek sunucu ağ geçidi — topluluk ağ geçidiyle aynı desen: her çağrı
/// access token ister; token yoksa standart oturum hatası fırlatılır.
class ApiAdminGateway implements AdminGateway {
  ApiAdminGateway(this._api, this._tokenProvider);

  final AdminApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _token() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<AdminStats> stats() async => _api.stats(await _token());

  @override
  Future<AdminPremiumGrant> grantPremium({
    required String email,
    required int months,
  }) async =>
      _api.grantPremium(
        accessToken: await _token(),
        email: email,
        months: months,
      );

  @override
  Future<String> createEvent(AdminEventInput input) async =>
      _api.createEvent(accessToken: await _token(), input: input);

  @override
  Future<void> cancelEvent(String eventId) async =>
      _api.cancelEvent(accessToken: await _token(), eventId: eventId);

  @override
  Future<List<EventParticipantView>> participants(String eventId) async =>
      _api.participants(accessToken: await _token(), eventId: eventId);

  @override
  Future<String> createDeal(AdminDealInput input) async =>
      _api.createDeal(accessToken: await _token(), input: input);

  @override
  Future<void> setDealActive(String dealId, {required bool isActive}) async =>
      _api.setDealActive(accessToken: await _token(), dealId: dealId, isActive: isActive);

  @override
  Future<List<AdminContentItem>> listContent(String type) async =>
      _api.listContent(accessToken: await _token(), type: type);

  @override
  Future<void> deleteContent({required String type, required String id}) async =>
      _api.deleteContent(accessToken: await _token(), type: type, id: id);
}
