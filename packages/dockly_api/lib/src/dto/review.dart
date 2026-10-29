/// Yayınlanmış (onaylı) yorum — misafir okuma (docs/23 §11.3).
class Review {
  const Review({
    required this.id,
    required this.authorName,
    this.authorId,
    required this.rating,
    required this.title,
    required this.body,
    required this.visitedOn,
    required this.createdAt,
    required this.helpfulCount,
  });

  final String id;

  /// Yazarın görünen adı; profil yoksa sunucu anonim fallback verir.
  final String authorName;

  /// Yazarın kullanıcı kimliği — kaptan kartı bağlantısı (SP-1 Kimlik,
  /// 2026-10-29). Eski sunucu/silinmiş yazar için null (bağlantı çizilmez).
  final String? authorId;

  /// Genel puan 1..5.
  final int rating;
  final String? title;
  final String? body;

  /// Ziyaret tarihi "YYYY-MM-DD" ya da null.
  final String? visitedOn;

  /// Oluşturulma zamanı (ISO 8601).
  final String createdAt;
  final int helpfulCount;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        authorName: json['authorName'] as String,
        authorId: json['authorId'] as String?,
        rating: (json['rating'] as num).toInt(),
        title: json['title'] as String?,
        body: json['body'] as String?,
        visitedOn: json['visitedOn'] as String?,
        createdAt: json['createdAt'] as String,
        helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
      );
}
