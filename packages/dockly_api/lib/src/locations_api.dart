import 'package:dio/dio.dart';

import 'dto/geo.dart';
import 'dto/location_detail.dart';
import 'dto/location_summary.dart';
import 'dto/map_result.dart';
import 'dto/occupancy.dart';
import 'dto/review.dart';
import 'problem_mapper.dart';

/// `/v1/locations*` istemcisi (docs/23 §9). Anonim uçlar; tüm hatalar `AppFailure`'a
/// eşlenir. `type` tekrarlı param = OR (docs/23 §9.2).
class LocationsApi {
  const LocationsApi(this._dio);

  final Dio _dio;

  /// Harita bbox sorgusu (docs/23 §9.5). zoom < 12 → cluster, ≥ 12 → pin.
  Future<MapResult> mapByBbox({
    required Bbox bbox,
    int? zoom,
    List<String>? types,
  }) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/locations',
        queryParameters: <String, dynamic>{
          'bbox': bbox.toParam(),
          if (zoom != null) 'zoom': zoom,
          if (types != null && types.isNotEmpty) 'type': types,
        },
        options: Options(listFormat: ListFormat.multi),
      );
      return MapResult.fromJson(res.data!);
    });
  }

  /// Yakınımdaki limanlar (docs/23 §9.6) — mesafeye göre sıralı.
  Future<List<LocationSummary>> nearby({
    required double lat,
    required double lon,
    double? radiusNm,
    List<String>? types,
    int? limit,
  }) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/locations/nearby',
        queryParameters: <String, dynamic>{
          'lat': lat,
          'lon': lon,
          if (radiusNm != null) 'radiusNm': radiusNm,
          if (limit != null) 'limit': limit,
          if (types != null && types.isNotEmpty) 'type': types,
        },
        options: Options(listFormat: ListFormat.multi),
      );
      final data = res.data!['data'] as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(LocationSummary.fromJson)
          .toList(growable: false);
    });
  }

  /// Metinle arama (docs/23 §9, S-07) — ad/şehir/su-alanı. Konum bağımsız;
  /// her öğede `distanceNm` = 0. Eşleşme yoksa boş liste.
  Future<List<LocationSummary>> search({
    required String q,
    List<String>? types,
    List<String>? amenities,
    int? limit,
  }) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/locations/search',
        queryParameters: <String, dynamic>{
          // q boş olabilir: yalnız olanak filtresiyle keşif (S-07 genişletme).
          if (q.isNotEmpty) 'q': q,
          if (types != null && types.isNotEmpty) 'type': types,
          if (amenities != null && amenities.isNotEmpty) 'amenity': amenities,
          if (limit != null) 'limit': limit,
        },
        options: Options(listFormat: ListFormat.multi),
      );
      final data = res.data!['data'] as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(LocationSummary.fromJson)
          .toList(growable: false);
    });
  }

  /// Bir lokasyonun onaylı yorumları (docs/23 §11.3). En yeni önce; boş olabilir.
  ///
  /// [accessToken] İSTEĞE BAĞLIDIR (P5, premium v3 §9): bayrak açıkken yorum
  /// metinleri kilitlidir — kimlikli istek (premium/keşif hakkı) tam listeyi
  /// alır; vitrin gören istek sunucudan 403 `premium-required` alır.
  Future<List<Review>> reviews(String idOrSlug, {int? limit, String? accessToken}) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/locations/${Uri.encodeComponent(idOrSlug)}/reviews',
        queryParameters: <String, dynamic>{
          if (limit != null) 'limit': limit,
        },
        options: accessToken == null
            ? null
            : Options(headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'}),
      );
      final data = res.data!['data'] as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList(growable: false);
    });
  }

  /// Liman detayı (docs/23 §10 #12, §11.3). id veya slug; bulunamazsa `NotFoundFailure`.
  ///
  /// [accessToken] İSTEĞE BAĞLIDIR (P4, premium v3 raporu §9): verilirse
  /// sunucu premium/keşif-hakkı kararını kimliğe göre verir (tam veri);
  /// verilmezse anonim vitrin yanıtı gelir (bayrak açıkken). Bozuk token
  /// sunucudan 401 döner — sessizce anonim SAYILMAZ.
  Future<LocationDetail> detail(String idOrSlug, {String? accessToken}) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/locations/${Uri.encodeComponent(idOrSlug)}',
        options: accessToken == null
            ? null
            : Options(
                headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
              ),
      );
      return LocationDetail.fromJson(res.data!);
    });
  }

  /// KEŞİF HAKKI (P4, premium v3 raporu K2): üye bu koyu bu ay için tam açar
  /// (ayda 3). HESAP ister. Dönen gövde TAM detay + kalan hak — ikinci istek
  /// gerekmez. Tavan doluysa sunucu 403 `quota-exceeded` döner (mapDioError
  /// bunu ForbiddenFailure'a çevirir; arayüz paywall açar).
  Future<({int remaining, LocationDetail detail})> unlock({
    required String idOrSlug,
    required String accessToken,
  }) async {
    return _call(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/locations/${Uri.encodeComponent(idOrSlug)}/unlock',
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      final Map<String, dynamic> body = res.data!;
      return (
        remaining: (body['remaining'] as num).toInt(),
        detail:
            LocationDetail.fromJson(body['detail'] as Map<String, dynamic>),
      );
    });
  }

  /// Koy doluluk bildirimi (2026-07 ayrıştırma paketi ①). HESAP ister —
  /// access token Authorization başlığıyla gider; misafir sunucudan
  /// guest-not-allowed alır. Dönen özet ekranı hemen tazeler.
  Future<OccupancySummary> reportOccupancy({
    required String idOrSlug,
    required String level,
    required GeoPoint position,
    required String accessToken,
  }) async {
    return _call(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/locations/$idOrSlug/occupancy',
        data: <String, dynamic>{
          'level': level,
          // KONUM DOĞRULAMASI: sunucu, bildirenin koya yakınlığını denetler.
          'position': <String, dynamic>{'lat': position.lat, 'lon': position.lon},
        },
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      return OccupancySummary.fromJson(
          res.data!['occupancy'] as Map<String, dynamic>);
    });
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
