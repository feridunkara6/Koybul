/// SORU-CEVAP veri sözleşmeleri (Blog V1 — kurucu onayı 2026-10-23, docs/23 /qa).
///
/// Vitrin ilkesi sözleşmede görünür: liste özetinde GÖVDE ALANI YOKTUR —
/// ücretsiz üyeye tam metin hiç inmez; `preview` sunucuda kesilmiş 160
/// karakterdir. Detay iki biçimde gelir: `full` (gövde + cevaplar) ya da
/// `teaser` (özet + cevap SAYISI). Erişim kararı sunucunundur.
library;

/// Sabit kategori sözlüğü — sunucudaki DB CHECK ile birebir aynı.
const List<String> kQaCategories = <String>[
  'demirleme',
  'seyir',
  'ekipman',
  'marina',
  'uygulama',
  'genel',
];

/// Liste satırı — herkese açık alanlar.
class QaQuestionSummary {
  const QaQuestionSummary({
    required this.id,
    required this.category,
    required this.title,
    required this.preview,
    this.authorId,
    required this.authorName,
    required this.authorPremium,
    required this.featured,
    required this.likeCount,
    required this.answersCount,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String title;
  final String preview;

  /// Yazarın kimliği — kaptan kartı köprüsü (Hafta 1B). Eski sunucu
  /// yanıtlarında alan yoktur; null ise köprü çizilmez (kırılmaz).
  final String? authorId;
  final String authorName;

  /// Yazar ŞU AN Premium mu? (altın rozet — dinamik, dürüst).
  final bool authorPremium;

  /// "Öne çıkan" şeridinde mi? (onaydan sonraki 24 saat)
  final bool featured;
  final int likeCount;
  final int answersCount;
  final DateTime createdAt;

  factory QaQuestionSummary.fromJson(Map<String, dynamic> json) => QaQuestionSummary(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        preview: json['preview'] as String,
        authorId: json['authorId'] as String?,
        authorName: json['authorName'] as String,
        authorPremium: json['authorPremium'] as bool,
        featured: json['featured'] as bool,
        likeCount: json['likeCount'] as int,
        answersCount: json['answersCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Ana akış: "Öne çıkan" şeridi + kronolojik liste.
class QaFeed {
  const QaFeed({
    required this.featured,
    required this.items,
    // SAYFALI DÜZEN (2026-10-30): eski sunucu yanıtlarıyla uyum için
    // varsayılanlı — alan gelmezse tek sayfa varsayılır.
    this.total = 0,
    this.pageCount = 1,
    this.page = 1,
  });

  final List<QaQuestionSummary> featured;
  final List<QaQuestionSummary> items;

  /// Süzgece uyan toplam soru (sayfalama).
  final int total;

  /// Toplam sayfa sayısı — sayfa seçici bununla çizilir.
  final int pageCount;

  /// Dönen sayfa (1 tabanlı).
  final int page;

  factory QaFeed.fromJson(Map<String, dynamic> json) => QaFeed(
        featured: (json['featured'] as List<dynamic>)
            .map((dynamic e) => QaQuestionSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        items: (json['items'] as List<dynamic>)
            .map((dynamic e) => QaQuestionSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
        page: (json['page'] as num?)?.toInt() ?? 1,
      );
}

class QaAnswer {
  const QaAnswer({
    required this.id,
    required this.body,
    required this.status,
    this.authorId,
    required this.authorName,
    required this.authorPremium,
    required this.helpfulCount,
    required this.mine,
    required this.helpedByMe,
    required this.createdAt,
  });

  final String id;
  final String body;

  /// 'approved' ya da (yalnız kendi cevabında görünen) 'pending'.
  final String status;

  /// Kaptan kartı köprüsü — null ise köprü çizilmez (eski sunucu uyumu).
  final String? authorId;
  final String authorName;
  final bool authorPremium;
  final int helpfulCount;
  final bool mine;
  final bool helpedByMe;
  final DateTime createdAt;

  factory QaAnswer.fromJson(Map<String, dynamic> json) => QaAnswer(
        id: json['id'] as String,
        body: json['body'] as String,
        status: json['status'] as String,
        authorId: json['authorId'] as String?,
        authorName: json['authorName'] as String,
        authorPremium: json['authorPremium'] as bool,
        helpfulCount: json['helpfulCount'] as int,
        mine: json['mine'] as bool,
        helpedByMe: json['helpedByMe'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Detay — erişim kararıyla gelir. `full` değilse [body]/[answers] BOŞTUR
/// (istemciye hiç inmemiştir); vitrin kartı [answersCount] ile çizilir.
class QaDetail {
  const QaDetail({
    required this.access,
    required this.question,
    required this.answersCount,
    this.body,
    this.mine = false,
    this.likedByMe = false,
    this.answers = const <QaAnswer>[],
  });

  /// 'full' | 'teaser'.
  final String access;
  final QaQuestionSummary question;
  final int answersCount;
  final String? body;
  final bool mine;
  final bool likedByMe;
  final List<QaAnswer> answers;

  bool get full => access == 'full';

  factory QaDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> q = json['question'] as Map<String, dynamic>;
    final QaQuestionSummary summary = QaQuestionSummary.fromJson(q);
    if (json['access'] == 'teaser') {
      return QaDetail(
        access: 'teaser',
        question: summary,
        answersCount: json['answersCount'] as int,
      );
    }
    return QaDetail(
      access: 'full',
      question: summary,
      answersCount: summary.answersCount,
      body: q['body'] as String?,
      mine: q['mine'] as bool? ?? false,
      likedByMe: q['likedByMe'] as bool? ?? false,
      answers: (json['answers'] as List<dynamic>)
          .map((dynamic e) => QaAnswer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Soru/cevap oluşturma sonucu — karma moderasyonun dürüst yanıtı:
/// 'approved' = anında yayında; 'pending' = denetim kuyruğunda.
class QaCreateResult {
  const QaCreateResult({required this.id, required this.status});

  final String id;
  final String status;

  bool get pending => status == 'pending';

  factory QaCreateResult.fromJson(Map<String, dynamic> json) =>
      QaCreateResult(id: json['id'] as String, status: json['status'] as String);
}
