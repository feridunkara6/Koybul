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
