/// TEKNE KARTI sözleşmesi (Sosyalleşme Hafta 2, kurucu onayı 2026-10-24) —
/// `GET /v1/boats/:id/public` yanıtı.
///
/// Kart yalnız sahibi "Marinada görün"ü açtıysa VARDIR; teknik alanlar
/// (marka/model/boy/yıl) shareSpecs rızasına bağlıdır — kapalıysa istemciye
/// hiç inmez. Konum, bağlama yeri, sicil no ve iletişim bu modelde YOKTUR.
/// Çizim istemcide üretilir (marka+model → çizim kütüphanesi).
library;

class PublicBoatCard {
  const PublicBoatCard({
    required this.id,
    required this.name,
    required this.boatTypeCode,
    required this.brand,
    required this.model,
    required this.lengthM,
    required this.buildYear,
    required this.marinaId,
    required this.marinaName,
    required this.captainUserId,
    required this.captainName,
    required this.captainLevelCode,
    // 0024 (kurucu onayı 2026-10-30): hikâye + istatistik + rotalar —
    // eski sunucu yanıtlarıyla uyum için varsayılanlı.
    this.story,
    this.sharedTrips = 0,
    this.sharedRoutes = 0,
    this.pruvaTotal = 0,
    this.routes = const <PublicBoatRouteRef>[],
    // TK-5 (0025, kurucu onayı 2026-10-30): favori + takipçi + kardeşler.
    this.favoriteCount = 0,
    this.captainFollowers = 0,
    this.sisters = const <PublicBoatSisterRef>[],
  });

  final String id;
  final String name;
  final String boatTypeCode;

  /// shareSpecs kapalıysa dördü birden null gelir.
  final String? brand;
  final String? model;
  final double? lengthM;
  final int? buildYear;

  final String? marinaId;
  final String? marinaName;

  /// Kaptan kartı köprüsü (Hafta 1B ekranına geçiş).
  final String captainUserId;
  final String captainName;
  final String captainLevelCode;

  /// TEKNENİN HİKÂYESİ (0024) — yalnız moderasyon ONAYLI metin iner.
  final String? story;

  /// Kart istatistikleri (0024) — paylaşılmış içerikten türetilir.
  final int sharedTrips;
  final int sharedRoutes;
  final int pruvaTotal;

  /// Kaptanın ONAYLI rotaları (en yeni 5) — rota detayına köprü.
  final List<PublicBoatRouteRef> routes;

  /// FAVORİLE (TK-5): toplam sayı — kimlerin favorilediği İNMEZ (gizlilik).
  final int favoriteCount;

  /// Kaptanın takipçi sayısı (kurucu isteği 2026-10-30).
  final int captainFollowers;

  /// KARDEŞ TEKNELER (TK-5): aynı marka+model, çifte rızalı tekneler.
  final List<PublicBoatSisterRef> sisters;

  factory PublicBoatCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? marina = json['marina'] as Map<String, dynamic>?;
    final Map<String, dynamic> captain = json['captain'] as Map<String, dynamic>;
    return PublicBoatCard(
      id: json['id'] as String,
      name: json['name'] as String,
      boatTypeCode: json['boatTypeCode'] as String,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      lengthM: (json['lengthM'] as num?)?.toDouble(),
      buildYear: (json['buildYear'] as num?)?.toInt(),
      marinaId: marina?['id'] as String?,
      marinaName: marina?['name'] as String?,
      captainUserId: captain['userId'] as String,
      captainName: captain['displayName'] as String,
      captainLevelCode: captain['levelCode'] as String,
      story: json['story'] as String?,
      sharedTrips:
          ((json['stats'] as Map<String, dynamic>?)?['sharedTrips'] as num?)
                  ?.toInt() ??
              0,
      sharedRoutes:
          ((json['stats'] as Map<String, dynamic>?)?['sharedRoutes'] as num?)
                  ?.toInt() ??
              0,
      pruvaTotal:
          ((json['stats'] as Map<String, dynamic>?)?['pruvaTotal'] as num?)
                  ?.toInt() ??
              0,
      routes: ((json['routes'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) =>
              PublicBoatRouteRef.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      captainFollowers: (json['captainFollowers'] as num?)?.toInt() ?? 0,
      sisters: ((json['sisters'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) =>
              PublicBoatSisterRef.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Karttaki tek kardeş tekne satırı (TK-5) — herkese açık asgari alanlar.
class PublicBoatSisterRef {
  const PublicBoatSisterRef({
    required this.id,
    required this.name,
    required this.boatTypeCode,
    required this.marinaName,
  });

  final String id;
  final String name;
  final String boatTypeCode;
  final String? marinaName;

  factory PublicBoatSisterRef.fromJson(Map<String, dynamic> json) =>
      PublicBoatSisterRef(
        id: json['id'] as String,
        name: json['name'] as String,
        boatTypeCode: json['boatTypeCode'] as String? ?? 'other',
        marinaName: json['marinaName'] as String?,
      );
}

/// `GET /v1/boats/favorites` satırı — kişinin kendi favori listesi (TK-5).
class FavoriteBoatRef {
  const FavoriteBoatRef({
    required this.id,
    required this.name,
    required this.boatTypeCode,
    required this.brand,
    required this.model,
    required this.marinaName,
  });

  final String id;
  final String name;
  final String boatTypeCode;

  /// Teknik rıza kapalıysa ikisi birden null.
  final String? brand;
  final String? model;
  final String? marinaName;

  factory FavoriteBoatRef.fromJson(Map<String, dynamic> json) =>
      FavoriteBoatRef(
        id: json['id'] as String,
        name: json['name'] as String,
        boatTypeCode: json['boatTypeCode'] as String? ?? 'other',
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        marinaName: json['marinaName'] as String?,
      );
}

/// Karttaki tek rota satırı (0024) — rota detayına köprü.
class PublicBoatRouteRef {
  const PublicBoatRouteRef({
    required this.id,
    required this.name,
    required this.distanceNm,
    required this.saveCount,
  });

  final String id;
  final String name;
  final double distanceNm;
  final int saveCount;

  factory PublicBoatRouteRef.fromJson(Map<String, dynamic> json) =>
      PublicBoatRouteRef(
        id: json['id'] as String,
        name: json['name'] as String,
        distanceNm: (json['distanceNm'] as num?)?.toDouble() ?? 0,
        saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      );
}
