import 'geo.dart';
import 'location_summary.dart' show CoverMedia;
import 'occupancy.dart';

/// Liman detayı — S-09 tam veri seti (docs/23 §11.3).
class LocationDetail {
  const LocationDetail({
    required this.id,
    required this.slug,
    required this.type,
    required this.status,
    required this.name,
    required this.description,
    required this.position,
    required this.geo,
    required this.dimensions,
    required this.priceTier,
    required this.is24h,
    required this.verifiedAt,
    required this.rating,
    required this.amenities,
    required this.services,
    required this.contacts,
    required this.hours,
    required this.seasons,
    required this.typeDetails,
    required this.media,
    required this.counts,
    this.occupancy,
    this.windExposedDirs,
    this.seabed,
  });

  final String id;
  final String slug;
  final String type;
  final String status;
  final String name;
  final String? description;
  final GeoPoint position;
  final GeoInfo geo;
  final Dimensions dimensions;
  final String priceTier;
  final bool is24h;
  final String? verifiedAt;
  final Rating rating;
  final List<AmenityLabeled> amenities;
  final List<ServiceLabeled> services;
  final List<Contact> contacts;
  final List<Hour> hours;
  final List<Season> seasons;
  final TypeDetails? typeDetails;
  final MediaInfo media;
  final Counts counts;

  /// Son 6 saatte doluluk bildirimi varsa özet; yoksa null (geriye uyumlu).
  final OccupancySummary? occupancy;

  /// Rüzgâra AÇIK yönler (TR pusula kodları, virgüllü: 'G,GD'); yoksa null.
  /// Uyarı rozeti bu alanla canlı tahmini birleştirir (geriye uyumlu).
  final String? windExposedDirs;

  /// Deniz dibi tutuş cinsi ('sand'|'mud'|'weed'|'rock'|'mixed'); yoksa null.
  /// TİPTEN BAĞIMSIZ: balıkçı barınağında ve belediye limanında da dolabilir,
  /// çünkü kaptan oralarda da demir atar (geriye uyumlu — eski sunucu null).
  final String? seabed;

  factory LocationDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) fromJson) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList(growable: false);

    return LocationDetail(
      id: json['id'] as String,
      slug: json['slug'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      position: GeoPoint.fromJson(json['position'] as Map<String, dynamic>),
      geo: GeoInfo.fromJson(json['geo'] as Map<String, dynamic>),
      dimensions: Dimensions.fromJson(json['dimensions'] as Map<String, dynamic>),
      priceTier: json['priceTier'] as String,
      is24h: json['is24h'] as bool? ?? false,
      verifiedAt: json['verifiedAt'] as String?,
      rating: Rating.fromJson(json['rating'] as Map<String, dynamic>),
      amenities: list('amenities', AmenityLabeled.fromJson),
      services: list('services', ServiceLabeled.fromJson),
      contacts: list('contacts', Contact.fromJson),
      hours: list('hours', Hour.fromJson),
      seasons: list('seasons', Season.fromJson),
      typeDetails: json['typeDetails'] == null
          ? null
          : TypeDetails.fromJson(json['typeDetails'] as Map<String, dynamic>),
      media: MediaInfo.fromJson(json['media'] as Map<String, dynamic>),
      counts: Counts.fromJson(json['counts'] as Map<String, dynamic>),
      occupancy: OccupancySummary.fromJsonNullable(json['occupancy']),
      windExposedDirs: json['windExposedDirs'] as String?,
      seabed: json['seabed'] as String?,
    );
  }
}

class GeoInfo {
  const GeoInfo({required this.countryCode, required this.adminArea, required this.waterBody});

  final String countryCode;
  final AdminAreaRef? adminArea;
  final WaterBodyRef? waterBody;

  factory GeoInfo.fromJson(Map<String, dynamic> json) => GeoInfo(
        countryCode: json['countryCode'] as String,
        adminArea: json['adminArea'] == null
            ? null
            : AdminAreaRef.fromJson(json['adminArea'] as Map<String, dynamic>),
        waterBody: json['waterBody'] == null
            ? null
            : WaterBodyRef.fromJson(json['waterBody'] as Map<String, dynamic>),
      );
}

class AdminAreaRef {
  const AdminAreaRef({required this.id, required this.name, required this.province});

  final String id;
  final String name;
  final String? province;

  factory AdminAreaRef.fromJson(Map<String, dynamic> json) => AdminAreaRef(
        id: json['id'] as String,
        name: json['name'] as String,
        province: json['province'] as String?,
      );
}

class WaterBodyRef {
  const WaterBodyRef({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final String type;

  factory WaterBodyRef.fromJson(Map<String, dynamic> json) => WaterBodyRef(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
      );
}

class Dimensions {
  const Dimensions({
    required this.maxBoatLengthM,
    required this.maxDraftM,
    required this.depthMinM,
    required this.depthMaxM,
    required this.capacity,
  });

  final double? maxBoatLengthM;
  final double? maxDraftM;
  final double? depthMinM;
  final double? depthMaxM;
  final int? capacity;

  factory Dimensions.fromJson(Map<String, dynamic> json) => Dimensions(
        maxBoatLengthM: (json['maxBoatLengthM'] as num?)?.toDouble(),
        maxDraftM: (json['maxDraftM'] as num?)?.toDouble(),
        depthMinM: (json['depthMinM'] as num?)?.toDouble(),
        depthMaxM: (json['depthMaxM'] as num?)?.toDouble(),
        capacity: (json['capacity'] as num?)?.toInt(),
      );
}

class Rating {
  const Rating({required this.avg, required this.count, required this.dimensions});

  final double? avg;
  final int count;
  final List<RatingDimension> dimensions;

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
        avg: (json['avg'] as num?)?.toDouble(),
        count: (json['count'] as num?)?.toInt() ?? 0,
        dimensions: (json['dimensions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(RatingDimension.fromJson)
            .toList(growable: false),
      );
}

class RatingDimension {
  const RatingDimension({required this.code, required this.avg});

  final String code;
  final double avg;

  factory RatingDimension.fromJson(Map<String, dynamic> json) => RatingDimension(
        code: json['code'] as String,
        avg: (json['avg'] as num).toDouble(),
      );
}

class AmenityLabeled {
  const AmenityLabeled({required this.code, required this.label, required this.category});

  final String code;
  final String label;
  final String? category;

  factory AmenityLabeled.fromJson(Map<String, dynamic> json) => AmenityLabeled(
        code: json['code'] as String,
        label: json['label'] as String,
        category: json['category'] as String?,
      );
}

class ServiceLabeled {
  const ServiceLabeled({required this.code, required this.label});

  final String code;
  final String label;

  factory ServiceLabeled.fromJson(Map<String, dynamic> json) => ServiceLabeled(
        code: json['code'] as String,
        label: json['label'] as String,
      );
}

class Contact {
  const Contact({
    required this.type,
    required this.value,
    required this.isPrimary,
    this.label,
  });

  final String type;
  final String value;
  final bool isPrimary;

  /// İnsan-okur etiket (ör. "Marina Ofisi", "Acil Durum", "Online Rezervasyon").
  /// Geriye uyumlu: yoksa null (backend gönderene dek boş kalır).
  final String? label;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        type: json['type'] as String,
        value: json['value'] as String,
        isPrimary: json['isPrimary'] as bool? ?? false,
        label: json['label'] as String?,
      );
}

class Hour {
  const Hour({required this.dayOfWeek, required this.opensAt, required this.closesAt});

  final int dayOfWeek;
  final String? opensAt;
  final String? closesAt;

  factory Hour.fromJson(Map<String, dynamic> json) => Hour(
        dayOfWeek: (json['dayOfWeek'] as num).toInt(),
        opensAt: json['opensAt'] as String?,
        closesAt: json['closesAt'] as String?,
      );
}

class Season {
  const Season({required this.opensOn, required this.closesOn});

  final String? opensOn;
  final String? closesOn;

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        opensOn: json['opensOn'] as String?,
        closesOn: json['closesOn'] as String?,
      );
}

class MediaInfo {
  const MediaInfo({required this.cover, required this.count});

  final CoverMedia? cover;
  final int count;

  factory MediaInfo.fromJson(Map<String, dynamic> json) => MediaInfo(
        cover: json['cover'] == null
            ? null
            : CoverMedia.fromJson(json['cover'] as Map<String, dynamic>),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class Counts {
  const Counts({required this.reviews, required this.photos});

  final int reviews;
  final int photos;

  factory Counts.fromJson(Map<String, dynamic> json) => Counts(
        reviews: (json['reviews'] as num?)?.toInt() ?? 0,
        photos: (json['photos'] as num?)?.toInt() ?? 0,
      );
}

/// Türe özel detaylar — ayrık birleşim (docs/23 §11.3). `kind` ayırt eder.
sealed class TypeDetails {
  const TypeDetails();

  factory TypeDetails.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'marina':
        return MarinaTypeDetails.fromJson(json);
      case 'fuelDock':
        return FuelDockTypeDetails.fromJson(json);
      case 'restaurantDock':
        return RestaurantDockTypeDetails.fromJson(json);
      case 'anchorage':
        return AnchorageTypeDetails.fromJson(json);
      default:
        return UnknownTypeDetails(kind);
    }
  }
}

class MarinaTypeDetails extends TypeDetails {
  const MarinaTypeDetails({
    required this.berthCount,
    required this.vhfChannel,
    required this.hasBlueFlag,
    required this.travelLiftCapacityTons,
    required this.craneCapacityTons,
    required this.winterStorage,
  });

  final int? berthCount;
  final String? vhfChannel;
  final bool? hasBlueFlag;
  final double? travelLiftCapacityTons;
  final double? craneCapacityTons;
  final bool? winterStorage;

  factory MarinaTypeDetails.fromJson(Map<String, dynamic> json) => MarinaTypeDetails(
        berthCount: (json['berthCount'] as num?)?.toInt(),
        vhfChannel: json['vhfChannel'] as String?,
        hasBlueFlag: json['hasBlueFlag'] as bool?,
        travelLiftCapacityTons: (json['travelLiftCapacityTons'] as num?)?.toDouble(),
        craneCapacityTons: (json['craneCapacityTons'] as num?)?.toDouble(),
        winterStorage: json['winterStorage'] as bool?,
      );
}

class FuelDockTypeDetails extends TypeDetails {
  const FuelDockTypeDetails({
    required this.hasDiesel,
    required this.hasGasoline,
    required this.hasAdblue,
    required this.minDepthM,
    required this.paymentNote,
  });

  final bool? hasDiesel;
  final bool? hasGasoline;
  final bool? hasAdblue;
  final double? minDepthM;
  final String? paymentNote;

  factory FuelDockTypeDetails.fromJson(Map<String, dynamic> json) => FuelDockTypeDetails(
        hasDiesel: json['hasDiesel'] as bool?,
        hasGasoline: json['hasGasoline'] as bool?,
        hasAdblue: json['hasAdblue'] as bool?,
        minDepthM: (json['minDepthM'] as num?)?.toDouble(),
        paymentNote: json['paymentNote'] as String?,
      );
}

class RestaurantDockTypeDetails extends TypeDetails {
  const RestaurantDockTypeDetails({
    required this.cuisine,
    required this.berthCountFree,
    required this.minSpendPolicy,
    required this.reservationRecommended,
  });

  final String? cuisine;
  final int? berthCountFree;
  final String? minSpendPolicy;
  final bool? reservationRecommended;

  factory RestaurantDockTypeDetails.fromJson(Map<String, dynamic> json) =>
      RestaurantDockTypeDetails(
        cuisine: json['cuisine'] as String?,
        berthCountFree: (json['berthCountFree'] as num?)?.toInt(),
        minSpendPolicy: json['minSpendPolicy'] as String?,
        reservationRecommended: json['reservationRecommended'] as bool?,
      );
}

class AnchorageTypeDetails extends TypeDetails {
  const AnchorageTypeDetails({
    required this.holdingType,
    required this.protectionN,
    required this.protectionS,
    required this.protectionE,
    required this.protectionW,
    required this.swellExposure,
    required this.isFree,
  });

  final String? holdingType;
  final int? protectionN;
  final int? protectionS;
  final int? protectionE;
  final int? protectionW;
  final String? swellExposure;
  final bool isFree;

  factory AnchorageTypeDetails.fromJson(Map<String, dynamic> json) => AnchorageTypeDetails(
        holdingType: json['holdingType'] as String?,
        protectionN: (json['protectionN'] as num?)?.toInt(),
        protectionS: (json['protectionS'] as num?)?.toInt(),
        protectionE: (json['protectionE'] as num?)?.toInt(),
        protectionW: (json['protectionW'] as num?)?.toInt(),
        swellExposure: json['swellExposure'] as String?,
        isFree: json['isFree'] as bool? ?? true,
      );
}

/// İleri uyumluluk: sunucu yeni bir `kind` eklerse istemci çökmez.
class UnknownTypeDetails extends TypeDetails {
  const UnknownTypeDetails(this.kind);

  final String kind;
}
