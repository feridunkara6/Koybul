import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/qa_gateway.dart';

/// Gerçek sunucu ağ geçidi — yönetim paneli ağ geçidiyle aynı desen.
///
/// OKUMA esnektir: akış token'sız gider; detayda token VARSA eklenir (sunucu
/// "kendi sorun mu / premium mısın" kararını verebilsin), yoksa misafir gibi
/// vitrin döner. YAZMA katıdır: token yoksa standart oturum hatası fırlar.
class ApiQaGateway implements QaGateway {
  ApiQaGateway(this._api, this._tokenProvider);

  final QaApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _requiredToken() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<QaFeed> feed({String? category}) => _api.feed(category: category);

  @override
  Future<QaDetail> detail(String questionId) async =>
      _api.detail(questionId, accessToken: await _tokenProvider());

  @override
  Future<QaCreateResult> createQuestion({
    required String category,
    required String title,
    required String body,
  }) async =>
      _api.createQuestion(
        accessToken: await _requiredToken(),
        category: category,
        title: title,
        body: body,
      );

  @override
  Future<QaCreateResult> createAnswer({
    required String questionId,
    required String body,
  }) async =>
      _api.createAnswer(
        accessToken: await _requiredToken(),
        questionId: questionId,
        body: body,
      );

  @override
  Future<({bool liked, int likeCount})> toggleLike(String questionId) async =>
      _api.toggleLike(accessToken: await _requiredToken(), questionId: questionId);

  @override
  Future<({bool helped, int helpfulCount})> toggleHelpful(String answerId) async =>
      _api.toggleHelpful(accessToken: await _requiredToken(), answerId: answerId);

  @override
  Future<void> report({required String entity, required String id}) async =>
      _api.report(accessToken: await _requiredToken(), entity: entity, id: id);
}
