/// ENGELLEDİKLERİM satırı (ENG-1, kurucu onayı 2026-11-03) —
/// `GET /v1/users/me/blocks` yanıtı. Liste YALNIZ sahibine iner;
/// engellenen kişi engellendiğini hiçbir uçtan öğrenemez.
library;

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.displayName,
    required this.levelCode,
    required this.blockedAt,
  });

  final String id;
  final String displayName;
  final String levelCode;
  final DateTime blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? 'Kaptan',
        levelCode: json['levelCode'] as String? ?? 'new',
        blockedAt: DateTime.tryParse(json['blockedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
