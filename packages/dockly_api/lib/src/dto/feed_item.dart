/// TAKİP AKIŞI satırı (SP-3b, kurucu onayı 2026-10-31) —
/// `GET /v1/feed` yanıtındaki tek kart.
///
/// Düz model: tür dışı alanlar null gelir (sunucu sözleşmesiyle birebir).
/// PII TAŞIMAZ — yazar yalnız id + görünen ad + seviye kodudur.
library;

class FeedItem {
  const FeedItem({
    required this.kind,
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.levelCode,
    required this.createdAt,
    this.startName,
    this.endName,
    this.distanceNm,
    this.durationMin,
    this.stopCount,
    this.sailedOn,
    this.pruvaCount,
    this.myPruva,
    this.locationId,
    this.locationName,
    this.noteKind,
    this.body,
    this.routeName,
    this.saveCount,
  });

  /// 'trip' | 'note' | 'route' — bilinmeyen tür istemcide çizilmez.
  final String kind;
  final String id;
  final String authorId;
  final String authorName;
  final String levelCode;
  final String createdAt;

  // --- trip ---
  final String? startName;
  final String? endName;
  final double? distanceNm;
  final int? durationMin;
  final int? stopCount;
  /// 'YYYY-MM-DD'.
  final String? sailedOn;
  final int? pruvaCount;
  final bool? myPruva;

  // --- note ---
  final String? locationId;
  final String? locationName;
  final String? noteKind;
  /// Sunucuda kırpılmış özet — tam metin koy sayfasında.
  final String? body;

  // --- route ---
  final String? routeName;
  final int? saveCount;

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
        kind: json['kind'] as String,
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        authorName: (json['authorName'] as String?) ?? '',
        levelCode: (json['levelCode'] as String?) ?? 'new',
        createdAt: json['createdAt'] as String,
        startName: json['startName'] as String?,
        endName: json['endName'] as String?,
        distanceNm: (json['distanceNm'] as num?)?.toDouble(),
        durationMin: (json['durationMin'] as num?)?.toInt(),
        stopCount: (json['stopCount'] as num?)?.toInt(),
        sailedOn: json['sailedOn'] as String?,
        pruvaCount: (json['pruvaCount'] as num?)?.toInt(),
        myPruva: json['myPruva'] as bool?,
        locationId: json['locationId'] as String?,
        locationName: json['locationName'] as String?,
        noteKind: json['noteKind'] as String?,
        body: json['body'] as String?,
        routeName: json['routeName'] as String?,
        saveCount: (json['saveCount'] as num?)?.toInt(),
      );

  /// Tepki sonrası yerel kopya — yalnız trip kartında kullanılır.
  FeedItem withPruva({required bool reacted, required int count}) => FeedItem(
        kind: kind,
        id: id,
        authorId: authorId,
        authorName: authorName,
        levelCode: levelCode,
        createdAt: createdAt,
        startName: startName,
        endName: endName,
        distanceNm: distanceNm,
        durationMin: durationMin,
        stopCount: stopCount,
        sailedOn: sailedOn,
        pruvaCount: count,
        myPruva: reacted,
        locationId: locationId,
        locationName: locationName,
        noteKind: noteKind,
        body: body,
        routeName: routeName,
        saveCount: saveCount,
      );
}
