/// HERKESE AÇIK KAPTAN KARTI sözleşmesi (Sosyalleşme Hafta 1B, kurucu onayı
/// 2026-10-24) — `GET /v1/users/:id/public` yanıtı.
///
/// PII TAŞIMAZ: e-posta, telefon, gerçek ad, rol, premium, konum ve marina
/// bu modelde yoktur (sunucu da göndermez). Rozet etiket metinleri istemcide
/// yaşar; burada yalnız kod listesi gelir.
library;

class PublicCaptain {
  const PublicCaptain({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.experienceYears,
    required this.memberSince,
    required this.points,
    required this.levelCode,
    required this.approvedCount,
    required this.helpfulReceived,
    required this.badges,
  });

  final String id;
  final String displayName;
  final String? bio;
  final int? experienceYears;
  final DateTime memberSince;
  final int points;

  /// 'new' | 'coastal' | 'guide' | 'master' | 'pilot'.
  final String levelCode;
  final int approvedCount;
  final int helpfulReceived;
  final List<String> badges;

  /// Avatar baş harfleri: görünen adın ilk iki kelimesinden; ad boşsa boş
  /// döner (uydurma harf yok — itibar DTO'suyla aynı ilke).
  String get initials {
    final List<String> parts =
        displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final String a = parts.first[0];
    final String b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  factory PublicCaptain.fromJson(Map<String, dynamic> json) => PublicCaptain(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        bio: json['bio'] as String?,
        experienceYears: (json['experienceYears'] as num?)?.toInt(),
        memberSince: DateTime.parse(json['memberSince'] as String),
        points: json['points'] as int,
        levelCode: json['levelCode'] as String,
        approvedCount: json['approvedCount'] as int,
        helpfulReceived: json['helpfulReceived'] as int,
        badges: (json['badges'] as List<dynamic>).cast<String>(),
      );
}
