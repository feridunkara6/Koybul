import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/reputation_gateway.dart';

/// Gerçek sunucu ağ geçidi (topluluk ağ geçidiyle aynı desen): her çağrı
/// önce geçerli access token'ı ister, yoksa standart oturum hatası fırlatır.
class ApiReputationGateway implements ReputationGateway {
  ApiReputationGateway(this._api, this._tokenProvider);

  final ReputationApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _token() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<ReputationSummary> summary() async => _api.summary(await _token());

  @override
  Future<List<ContributionItem>> contributions() async =>
      _api.contributions(await _token());

  @override
  Future<Map<String, int>> moderationCounts() async =>
      _api.moderationCounts(await _token());

  @override
  Future<List<ModerationItem>> moderationQueue({String? entityType}) async =>
      _api.moderationQueue(await _token(), entityType: entityType);

  @override
  Future<void> decide({
    required String taskId,
    required bool approve,
    String? reason,
  }) async {
    await _api.decide(
      taskId: taskId,
      approve: approve,
      reason: reason,
      accessToken: await _token(),
    );
  }
}
