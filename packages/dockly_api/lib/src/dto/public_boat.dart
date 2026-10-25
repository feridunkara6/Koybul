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
    );
  }
}
