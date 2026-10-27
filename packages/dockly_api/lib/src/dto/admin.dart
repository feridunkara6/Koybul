/// YÖNETİM PANELİ veri sözleşmeleri (kurucu talebi 2026-09-25, docs/23 /admin).
/// Panel yalnız SUNUCUNUN bildiği sayıları taşır — indirme sayısı burada yok
/// (o veri App Store Connect'tedir; panel dürüst kalır).
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.guestUsers,
    required this.newUsers7d,
    required this.premiumActive,
    required this.pendingModeration,
    required this.totalReviews,
    required this.totalNotes,
  });

  final int totalUsers;
  final int guestUsers;
  final int newUsers7d;
  final int premiumActive;
  final int pendingModeration;
  final int totalReviews;
  final int totalNotes;

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        totalUsers: json['totalUsers'] as int,
        guestUsers: json['guestUsers'] as int,
        newUsers7d: json['newUsers7d'] as int,
        premiumActive: json['premiumActive'] as int,
        pendingModeration: json['pendingModeration'] as int,
        totalReviews: json['totalReviews'] as int,
        totalNotes: json['totalNotes'] as int,
      );
}

/// Elle premium tanımlama sonucu.
class AdminPremiumGrant {
  const AdminPremiumGrant({required this.email, required this.premiumUntil});

  final String email;
  final DateTime premiumUntil;

  factory AdminPremiumGrant.fromJson(Map<String, dynamic> json) => AdminPremiumGrant(
        email: json['email'] as String,
        premiumUntil: DateTime.parse(json['premiumUntil'] as String),
      );
}

/// Etkinlik oluşturma/düzenleme girdisi (yönetim paneli, V1 2026-10-23).
/// Tarihler UTC ISO olarak gider; sunucu zod ile yeniden doğrular.
class AdminEventInput {
  const AdminEventInput({
    required this.title,
    required this.body,
    required this.startsAt,
    required this.locationText,
    required this.quota,
    required this.audience,
    this.registrationDeadline,
    this.priceNote,
    this.conditions,
    this.organizer,
  });

  final String title;
  final String body;
  final DateTime startsAt;
  final String locationText;
  final int quota;
  final String audience;
  final DateTime? registrationDeadline;
  final String? priceNote;
  final String? conditions;
  final String? organizer;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'body': body,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'locationText': locationText,
        'quota': quota,
        'audience': audience,
        if (registrationDeadline != null)
          'registrationDeadline': registrationDeadline!.toUtc().toIso8601String(),
        if (priceNote != null && priceNote!.isNotEmpty) 'priceNote': priceNote,
        if (conditions != null && conditions!.isNotEmpty) 'conditions': conditions,
        if (organizer != null && organizer!.isNotEmpty) 'organizer': organizer,
      };
}

/// Fırsat oluşturma girdisi (yönetim paneli, V1 2026-10-23).
class AdminDealInput {
  const AdminDealInput({
    required this.title,
    required this.partner,
    required this.benefit,
    required this.audience,
    this.code,
    this.validUntil,
    this.terms,
    this.place,
  });

  final String title;
  final String partner;
  final String benefit;
  final String audience;
  final String? code;
  final DateTime? validUntil;
  final String? terms;
  final String? place;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'partner': partner,
        'benefit': benefit,
        'audience': audience,
        if (code != null && code!.isNotEmpty) 'code': code,
        if (validUntil != null) 'validUntil': validUntil!.toUtc().toIso8601String(),
        if (terms != null && terms!.isNotEmpty) 'terms': terms,
        if (place != null && place!.isNotEmpty) 'place': place,
      };
}

/// Etkinlik katılımcısı — yalnız panelde görünür (organizasyon amaçlı).
class EventParticipantView {
  const EventParticipantView({
    required this.displayName,
    required this.email,
    required this.registeredAt,
  });

  final String displayName;
  final String email;
  final DateTime registeredAt;

  factory EventParticipantView.fromJson(Map<String, dynamic> json) =>
      EventParticipantView(
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        registeredAt: DateTime.parse(json['registeredAt'] as String),
      );
}

/// İÇERİK YÖNETİMİ satırı (kurucu talebi 2026-10-27): yönetici uygulamadaki
/// içerikleri tür tür listeler ve yayından indirebilir (yumuşak silme).
class AdminContentItem {
  const AdminContentItem({
    required this.id,
    required this.title,
    required this.authorName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? authorName;

  /// 'approved' | 'pending' | 'rejected' | tekne için 'visible'/'hidden'.
  final String? status;
  final DateTime createdAt;

  factory AdminContentItem.fromJson(Map<String, dynamic> json) => AdminContentItem(
        id: json['id'] as String,
        title: json['title'] as String,
        authorName: json['authorName'] as String?,
        status: json['status'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
