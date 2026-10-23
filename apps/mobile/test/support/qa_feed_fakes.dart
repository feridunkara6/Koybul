import 'package:dockly_api/dockly_api.dart'
    show QaCreateResult, QaDetail, QaFeed, QaQuestionSummary;
import 'package:dockly_mobile/features/qa/domain/qa_gateway.dart';

/// Yalnız AKIŞ okuyan ekranlar için sahte Soru-Cevap geçidi (docs/15: ağ yok).
/// Bugün sekmesi köprü kartı ve liste ekranı feed'den beslenir; yazma/detay
/// uçları bu sahtede kullanılmaz ve bilinçli olarak desteklenmez.
class FakeQaFeedGateway implements QaGateway {
  FakeQaFeedGateway({QaFeed? feedResult})
      : feedResult = feedResult ??
            const QaFeed(
                featured: <QaQuestionSummary>[], items: <QaQuestionSummary>[]);

  QaFeed feedResult;

  @override
  Future<QaFeed> feed({String? category}) async => feedResult;

  @override
  Future<QaDetail> detail(String questionId) =>
      throw UnimplementedError('feed sahtesi detay taşımaz');

  @override
  Future<QaCreateResult> createQuestion({
    required String category,
    required String title,
    required String body,
  }) =>
      throw UnimplementedError();

  @override
  Future<QaCreateResult> createAnswer({
    required String questionId,
    required String body,
  }) =>
      throw UnimplementedError();

  @override
  Future<({bool liked, int likeCount})> toggleLike(String questionId) =>
      throw UnimplementedError();

  @override
  Future<({bool helped, int helpfulCount})> toggleHelpful(String answerId) =>
      throw UnimplementedError();

  @override
  Future<void> report({required String entity, required String id}) =>
      throw UnimplementedError();
}
