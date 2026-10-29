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
    // SP-1 Kimlik (2026-10-29): vitrin — eski sunucu yanıtlarıyla uyum için
    // isteğe bağlı; alan gelmezse boş liste (bölüm çizilmez).
    this.recentContributions = const <CaptainContribution>[],
    // SP-3a Takip (2026-10-31): takipçi sayısı — alan gelmezse 0.
    this.followerCount = 0,
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

  /// Son ONAYLI katkılar (vitrin): not (koy adıyla) + paylaşılan rota.
  final List<CaptainContribution> recentContributions;

  /// Takipçi sayısı (SP-3a) — herkese açık; eski sunucuda alan yoksa 0.
  final int followerCount;

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
        recentContributions: ((json['recentContributions'] as List<dynamic>?) ??
                const <dynamic>[])
            .map((dynamic e) =>
                CaptainContribution.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      );
}

/// Kaptan kartı vitrinindeki tek satır (SP-1 Kimlik, 2026-10-29).
class CaptainContribution {
  const CaptainContribution({
    required this.kind,
    required this.title,
    required this.noteKind,
    required this.savedCount,
    required this.createdAt,
  });

  /// 'note' | 'route'.
  final String kind;

  /// Not için koy adı; rota için rota adı. Koy silinmişse null olabilir.
  final String? title;

  /// Not türü kodu ('hazard'|'status'|'experience'|'passage') — etiket istemcide.
  final String? noteKind;

  /// Rota için kaydedilme sayısı; not için null.
  final int? savedCount;

  /// ISO 8601 oluşturulma zamanı.
  final String createdAt;

  factory CaptainContribution.fromJson(Map<String, dynamic> json) =>
      CaptainContribution(
        kind: json['kind'] as String,
        title: json['title'] as String?,
        noteKind: json['noteKind'] as String?,
        savedCount: (json['savedCount'] as num?)?.toInt(),
        createdAt: json['createdAt'] as String,
      );
}
