/// TAKİP listesi satırı (SP-3a, kurucu onayı 2026-10-31) —
/// `GET /v1/users/me/following` yanıtındaki tek kaptan.
///
/// PII TAŞIMAZ: kaptan kartıyla aynı dil — id + görünen ad + seviye kodu.
library;

class FollowedCaptain {
  const FollowedCaptain({
    required this.id,
    required this.displayName,
    required this.levelCode,
  });

  final String id;
  final String displayName;

  /// 'new' | 'coastal' | 'guide' | 'master' | 'pilot'.
  final String levelCode;

  factory FollowedCaptain.fromJson(Map<String, dynamic> json) =>
      FollowedCaptain(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        levelCode: (json['levelCode'] as String?) ?? 'new',
      );
}
