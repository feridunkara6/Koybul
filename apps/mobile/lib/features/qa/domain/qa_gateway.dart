import 'package:dockly_api/dockly_api.dart'
    show QaCreateResult, QaDetail, QaFeed;

/// SORU-CEVAP ağ geçidi arayüzü (Blog V1 — kurucu onayı 2026-10-23).
/// Gerçek implementasyon `data/api_qa_gateway.dart`; testlerde sahtesi
/// kullanılır (ağ yok). Erişim kuralları SUNUCUDADIR — bu arayüz yalnız taşır.
abstract interface class QaGateway {
  /// Ana akış: öne çıkan + kronolojik liste. [category] null = tümü.
  /// Akış — sayfalı + anahtar kelime aramalı (2026-10-30).
  Future<QaFeed> feed({String? category, String? query, int page});

  /// Detay — oturum varsa token'la sorulur (sahiplik/premium kararı için).
  Future<QaDetail> detail(String questionId);

  Future<QaCreateResult> createQuestion({
    required String category,
    required String title,
    required String body,
  });

  Future<QaCreateResult> createAnswer({
    required String questionId,
    required String body,
  });

  Future<({bool liked, int likeCount})> toggleLike(String questionId);

  Future<({bool helped, int helpfulCount})> toggleHelpful(String answerId);

  /// ⚑ Bildir — [entity]: 'question' | 'answer'.
  Future<void> report({required String entity, required String id});
}
