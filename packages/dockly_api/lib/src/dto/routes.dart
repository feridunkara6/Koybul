/// ROTA PAYLAŞIMI veri sözleşmeleri (Sosyalleşme Hafta 3, kurucu onayı
/// 2026-10-24) — `/v1/routes` yanıtları.
///
/// Çizgi gelmez: yalnız duraklar iner; çizgiyi istemci kendi rotalayıcısıyla
/// üretir. Mesafe/süre paylaşanın UYGULAMA HESABIDIR (beyan) — doğrulanmış
/// gibi sunulmaz. Her rota moderasyon onayından geçer.
library;

class SharedRouteStop {
  const SharedRouteStop({
    required this.seq,
    required this.locationId,
    required this.name,
    required this.typeCode,
    this.lat,
    this.lon,
  });

  final int seq;
  final String locationId;
  final String name;
  final String typeCode;

  /// Durak koordinatı — "Haritada aç" rotayı bununla kurar (saha hatası
  /// 2026-10-26). NULL kalabilir: eski sunucu sürümü koordinat göndermez;
  /// arayüz o durumda düğmeyi dürüstçe gizler (çizgi uydurulmaz).
  final double? lat;
  final double? lon;

  factory SharedRouteStop.fromJson(Map<String, dynamic> json) => SharedRouteStop(
        seq: json['seq'] as int,
        locationId: json['locationId'] as String,
        name: json['name'] as String,
        typeCode: json['typeCode'] as String,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );
}

class SharedRouteSummary {
  const SharedRouteSummary({
    required this.id,
    required this.name,
    required this.authorId,
    required this.authorName,
    required this.startName,
    required this.endName,
    required this.stopCount,
    required this.distanceNm,
    required this.durationHours,
    required this.season,
    required this.saveCount,
    required this.doneCount,
    required this.createdAt,
    this.status = 'approved',
  });

  final String id;
  final String name;
  final String authorId;
  final String authorName;
  final String startName;
  final String endName;
  final int stopCount;
  final double distanceNm;
  final double? durationHours;
  final String? season;
  final int saveCount;
  final int doneCount;
  final DateTime createdAt;

  /// 'approved' | 'pending' — liste artık bakanın KENDİ bekleyen rotalarını
  /// da taşır (saha isteği 2026-10-27); eski sunucu alanı göndermezse onaylı
  /// varsayılır (yanlış "bekliyor" rozeti basılmaz).
  final String status;

  factory SharedRouteSummary.fromJson(Map<String, dynamic> json) => SharedRouteSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        startName: json['startName'] as String,
        endName: json['endName'] as String,
        stopCount: json['stopCount'] as int,
        distanceNm: (json['distanceNm'] as num).toDouble(),
        durationHours: (json['durationHours'] as num?)?.toDouble(),
        season: json['season'] as String?,
        saveCount: json['saveCount'] as int,
        doneCount: json['doneCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: json['status'] as String? ?? 'approved',
      );
}

class SharedRouteDetail {
  const SharedRouteDetail({
    required this.summary,
    required this.body,
    required this.boatSuggestion,
    required this.status,
    required this.stops,
    required this.mine,
    required this.savedByMe,
    required this.doneByMe,
  });

  final SharedRouteSummary summary;
  final String body;
  final String? boatSuggestion;

  /// 'approved' ya da (yalnız sahibine görünen) 'pending'.
  final String status;
  final List<SharedRouteStop> stops;
  final bool mine;
  final bool savedByMe;
  final bool doneByMe;

  factory SharedRouteDetail.fromJson(Map<String, dynamic> json) => SharedRouteDetail(
        summary: SharedRouteSummary.fromJson(json),
        body: json['body'] as String,
        boatSuggestion: json['boatSuggestion'] as String?,
        status: json['status'] as String,
        stops: (json['stops'] as List<dynamic>)
            .map((dynamic e) => SharedRouteStop.fromJson(e as Map<String, dynamic>))
            .toList(),
        mine: json['mine'] as bool,
        savedByMe: json['savedByMe'] as bool,
        doneByMe: json['doneByMe'] as bool,
      );
}
