import 'geo.dart';

/// Kart kapak görseli (docs/23 §11.2). Bugün `url` DIŞ görsel adresidir
/// (Wikimedia Commons, `external_url`); iç CDN varyantları medya yükleme
/// altyapısıyla (Faz 4) gelecek.
class CoverMedia {
  const CoverMedia({
    required this.url,
    required this.blurhash,
    this.credit,
    this.license,
    this.sourceUrl,
  });

  final String url;
  final String? blurhash;

  /// Atıf alanları — dış (CC/Commons) lisanslı görsellerde dolar. `credit` ve
  /// `license` varsa görselin altında GÖSTERİLMESİ zorunludur (CC şartı).
  final String? credit;
  final String? license;
  final String? sourceUrl;

  factory CoverMedia.fromJson(Map<String, dynamic> json) => CoverMedia(
        url: json['url'] as String,
        blurhash: json['blurhash'] as String?,
        credit: json['credit'] as String?,
        license: json['license'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
      );
}

/// Kart/liste öğesi (docs/23 §11.2) — nearby & koleksiyon raylarında kullanılır.
class LocationSummary {
  const LocationSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.slug,
    required this.coverMedia,
    required this.ratingAvg,
    required this.ratingCount,
    required this.priceTier,
    required this.city,
    required this.waterBodyName,
    required this.distanceNm,
    required this.amenityCodes,
    required this.maxBoatLengthM,
    required this.maxDraftM,
  });

  final String id;
  final String name;
  final String type;
  final GeoPoint position;
  final String slug;
  final CoverMedia? coverMedia;
  final double? ratingAvg;
  final int ratingCount;
  final String priceTier;
  final String? city;
  final String? waterBodyName;
  final double distanceNm;
  final List<String> amenityCodes;

  /// Kabul edilen maks. tekne boyu (m) — tekne-uygunluğu filtresi için (null = bilinmiyor).
  final double? maxBoatLengthM;

  /// Kabul edilen maks. su çekimi (m) — tekne-uygunluğu filtresi için (null = bilinmiyor).
  final double? maxDraftM;

  factory LocationSummary.fromJson(Map<String, dynamic> json) => LocationSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        position: GeoPoint.fromJson(json['position'] as Map<String, dynamic>),
        slug: json['slug'] as String,
        coverMedia: json['coverMedia'] == null
            ? null
            : CoverMedia.fromJson(json['coverMedia'] as Map<String, dynamic>),
        ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        priceTier: json['priceTier'] as String,
        city: json['city'] as String?,
        waterBodyName: json['waterBodyName'] as String?,
        distanceNm: (json['distanceNm'] as num?)?.toDouble() ?? 0,
        amenityCodes: (json['amenityCodes'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic e) => e as String)
            .toList(growable: false),
        maxBoatLengthM: (json['maxBoatLengthM'] as num?)?.toDouble(),
        maxDraftM: (json['maxDraftM'] as num?)?.toDouble(),
      );
}
