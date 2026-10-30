/// MARİNA TOPLULUĞU veri sözleşmeleri (V1 — kurucu onayı 2026-10-23).
///
/// Gizlilik sözleşmede görünür: topluluk yanıtında `access='counts'` ise
/// tekne listesi BOŞTUR (istemciye hiç inmemiştir); `lengthM`/`brand` yalnız
/// sahibi "tip/boy/marka paylaş" rızasını açmışsa doludur. Sayılar beyana
/// dayalıdır ve canlı sorgudan gelir.
library;

/// Topluluk listesindeki tek tekne — yalnız sahibinin paylaştığı alanlar.
class MarinaBoat {
  const MarinaBoat({
    this.boatId,
    required this.name,
    required this.boatTypeCode,
    required this.lengthM,
    required this.brand,
    required this.captainName,
  });

  /// Tekne Kartı köprüsü (Hafta 2) — eski sunucuda yoktur, null ise
  /// satır dokunulabilir olmaz (kırılmaz).
  final String? boatId;
  final String name;
  final String boatTypeCode;
  final double? lengthM;
  final String? brand;
  final String captainName;

  factory MarinaBoat.fromJson(Map<String, dynamic> json) => MarinaBoat(
        boatId: json['boatId'] as String?,
        name: json['name'] as String,
        boatTypeCode: json['boatTypeCode'] as String,
        lengthM: (json['lengthM'] as num?)?.toDouble(),
        brand: json['brand'] as String?,
        captainName: json['captainName'] as String,
      );
}

class MarinaCommunity {
  const MarinaCommunity({
    required this.marinaId,
    required this.marinaName,
    required this.total,
    required this.visibleCount,
    required this.access,
    required this.boats,
  });

  final String marinaId;
  final String marinaName;

  /// Bu marinayı seçmiş toplam Koybul teknesi (gizliler dâhil, isimsiz).
  final int total;
  final int visibleCount;

  /// 'full' = liste dolu; 'counts' = yalnız sayılar.
  final String access;
  final List<MarinaBoat> boats;

  bool get full => access == 'full';
  int get hiddenCount => total - visibleCount;

  factory MarinaCommunity.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> marina = json['marina'] as Map<String, dynamic>;
    return MarinaCommunity(
      marinaId: marina['id'] as String,
      marinaName: marina['name'] as String,
      total: json['total'] as int,
      visibleCount: json['visibleCount'] as int,
      access: json['access'] as String,
      boats: (json['boats'] as List<dynamic>)
          .map((dynamic e) => MarinaBoat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Kullanıcının sunucuya kayıtlı teknesi + topluluk tercihleri.
class MyMarinaBoat {
  const MyMarinaBoat({
    required this.boatId,
    required this.name,
    required this.boatTypeCode,
    required this.lengthM,
    required this.brand,
    this.model,
    this.buildYear,
    required this.marinaId,
    required this.marinaName,
    required this.visible,
    required this.shareSpecs,
    // 0024: teknenin hikâyesi — eski sunucu yanıtlarıyla uyum için varsayılanlı.
    this.story,
    this.storyStatus = 'approved',
  });

  final String boatId;
  final String name;
  final String boatTypeCode;
  final double lengthM;
  final String? brand;

  /// Hafta 2 (Tekne Kartı): modele özel çizim bu alanla seçilir.
  final String? model;
  final int? buildYear;
  final String? marinaId;
  final String? marinaName;
  final bool visible;
  final bool shareSpecs;

  /// TEKNENİN HİKÂYESİ (0024) — sahibin gördüğü güncel metin.
  final String? story;

  /// 'pending' | 'approved' | 'rejected' — durum sahibine dürüstçe söylenir.
  final String storyStatus;

  factory MyMarinaBoat.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? marina = json['marina'] as Map<String, dynamic>?;
    return MyMarinaBoat(
      boatId: json['boatId'] as String,
      name: json['name'] as String,
      boatTypeCode: json['boatTypeCode'] as String,
      lengthM: (json['lengthM'] as num).toDouble(),
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      buildYear: (json['buildYear'] as num?)?.toInt(),
      marinaId: marina?['id'] as String?,
      marinaName: marina?['name'] as String?,
      visible: json['visible'] as bool,
      shareSpecs: json['shareSpecs'] as bool,
      story: json['story'] as String?,
      storyStatus: (json['storyStatus'] as String?) ?? 'approved',
    );
  }
}
