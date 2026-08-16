/// SEYİR KAYDI — alan modeli (v2.1 "Planla → Gerçekleşti", kurucu onayı
/// 2026-08; tasarım raporu: koybul-seyir-sistemi-tasarim).
///
/// ESKİ MODEL ("Seyri başlat/bitir") kaldırıldı: uygulama teknede açık
/// tutulmadığı için iki-dokunuşlu süre ölçümü sistematik olarak yanlış veri
/// üretiyordu (unutulan "bitir" → hayalet seyirler). YENİ MODEL tek kaydın
/// iki durumudur:
///
///   PLANLANDI  — kaptan rota çizip "Seyri planla" dedi (niyet).
///   GERÇEKLEŞTİ — kaptan seferi yaptı ve "Gerçekleşti"yi işaretledi (anı).
///
/// Sezon istatistiklerine YALNIZ gerçekleşen seferler sayılır (0-uydurma).
/// Mesafe her zaman rota PLANININ mesafesidir (≈ ile gösterilir); süre,
/// kaptan isterse elle girdiği değerdir — ölçüm iddiası yok, dürüstlük var.
/// GERİYE UYUM: eski başlat/bitir kayıtları GERÇEKLEŞTİ olarak, ölçülen
/// süreleri korunarak okunur — kimse veri kaybetmez.
///
/// v2.2 (rota birleştirme, kurucu onayı 2026-08): plan artık ROTAYI DA
/// TAŞIR — başlangıç + sıralı ara noktalar kayda gömülür; Defter'deki
/// PLANLANDI kartından "Haritada aç" rotayı aynı motorla yeniden kurar.
/// "Seyri planla" ile "Rotayı kaydet" karmaşası böyle çözüldü: tek ana
/// eylem planla; Rotalarım yalnız bilinçli eklenen şablonları tutar.
/// Rota verisi İSTEĞE BAĞLIDIR: eski plan kayıtları rotasız yaşamaya
/// devam eder (onlarda "Haritada aç" dürüstçe gösterilmez).
library;

import 'package:dockly_api/dockly_api.dart' show GeoPoint;

import '../../route/domain/sea_trip.dart' show RouteOrigin, RouteWaypoint;

/// Sefer durumu: planlanan niyet mi, gerçekleşen seyir mi?
enum TripStatus { planned, done }

/// Sefer kaydı — Defter'in Seyirler bölümündeki satır (her iki durumda).
class SeaTripLog {
  const SeaTripLog({
    required this.id,
    required this.name,
    required this.status,
    required this.dateMs,
    required this.distanceNm,
    this.stops = 0,
    this.durMin,
    this.routeOrigin,
    this.routeWaypoints,
  });

  final String id;

  /// Rota adı (kayıtlı rotanın adı ya da "A → B" önerisi).
  final String name;

  /// PLANLANDI ya da GERÇEKLEŞTİ.
  final TripStatus status;

  /// PLANLANDI: planın oluşturulduğu an. GERÇEKLEŞTİ: seferin yapıldığı
  /// tarih (kaptanın onayladığı gün). Liste sıralaması ve karttaki tarih
  /// bu alandan gelir.
  final int dateMs;

  /// Rota planının mesafesi (≈, bilgi amaçlı — ölçüm değil).
  final double distanceNm;

  /// Rotadaki durak sayısı (plan anında).
  final int stops;

  /// Denizde geçen süre (dakika) — İSTEĞE BAĞLI. Yeni akışta kaptan
  /// "Gerçekleşti" onayında girerse dolar; eski başlat/bitir kayıtlarında
  /// ölçülen süre buraya taşınır. null = süre bilinmiyor (dürüst boşluk).
  final int? durMin;

  /// Rotanın BAŞLANGICI (v2.2) — doluysa plan "Haritada aç" ile geri
  /// çağrılabilir. Eski kayıtlarda null (rota o zaman saklanmıyordu).
  final RouteOrigin? routeOrigin;

  /// Rotanın sıralı ara noktaları (duraklar + serbest noktalar, v2.2).
  final List<RouteWaypoint>? routeWaypoints;

  bool get isPlanned => status == TripStatus.planned;

  /// Bu kayıttan rota yeniden kurulabilir mi? (Başlangıç + en az bir nokta.)
  bool get hasRoute =>
      routeOrigin != null && (routeWaypoints?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'st': status == TripStatus.planned ? 'planned' : 'done',
        'date': dateMs,
        'nm': distanceNm,
        'stops': stops,
        if (durMin != null) 'dur': durMin,
        // v2.2 rota verisi (isteğe bağlı): başlangıç + sıralı noktalar.
        if (routeOrigin != null)
          'org': <String, dynamic>{
            'lat': routeOrigin!.pos.lat,
            'lon': routeOrigin!.pos.lon,
            if (routeOrigin!.name != null) 'name': routeOrigin!.name,
            if (routeOrigin!.isDevice) 'dev': true,
          },
        if (routeWaypoints != null && routeWaypoints!.isNotEmpty)
          'wps': <Map<String, dynamic>>[
            for (final RouteWaypoint w in routeWaypoints!)
              <String, dynamic>{
                'lat': w.pos.lat,
                'lon': w.pos.lon,
                if (w.id != null) 'id': w.id,
                if (w.name != null) 'name': w.name,
              },
          ],
      };

  /// Rota verisini okur; herhangi bir parça bozuksa (null, null) döner —
  /// kayıt yaşar, yalnız "Haritada aç" çıkmaz (çökme yerine dürüst eksik).
  static (RouteOrigin?, List<RouteWaypoint>?) _routeFromJson(
      Map<String, dynamic> raw) {
    final dynamic org = raw['org'];
    final dynamic wps = raw['wps'];
    if (org is! Map<String, dynamic> || wps is! List<dynamic>) {
      return (null, null);
    }
    final num? oLat = org['lat'] as num?;
    final num? oLon = org['lon'] as num?;
    if (oLat == null || oLon == null) return (null, null);
    final List<RouteWaypoint> out = <RouteWaypoint>[];
    for (final dynamic e in wps) {
      if (e is! Map<String, dynamic>) return (null, null);
      final num? lat = e['lat'] as num?;
      final num? lon = e['lon'] as num?;
      if (lat == null || lon == null) return (null, null);
      out.add(RouteWaypoint(
        pos: GeoPoint(lat: lat.toDouble(), lon: lon.toDouble()),
        id: e['id'] as String?,
        name: e['name'] as String?,
      ));
    }
    if (out.isEmpty) return (null, null);
    return (
      RouteOrigin(
        pos: GeoPoint(lat: oLat.toDouble(), lon: oLon.toDouble()),
        name: org['name'] as String?,
        isDevice: org['dev'] == true,
      ),
      List<RouteWaypoint>.unmodifiable(out),
    );
  }

  /// Bozuk kayıt → null (çökme yok; satır sessizce atlanır).
  ///
  /// İKİ BİÇİM OKUNUR:
  ///  * yeni: {id, name, st, date, nm, stops, dur?}
  ///  * eski (v2.0 başlat/bitir): {id, name, start, end, nm, stops} —
  ///    GERÇEKLEŞTİ sayılır; tarih = bitiş anı, süre = end-start (ölçülmüştü).
  static SeaTripLog? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? id = raw['id'] as String?;
    final String? name = raw['name'] as String?;
    if (id == null || name == null) return null;
    final num? nm = raw['nm'] as num?;
    final int stops = (raw['stops'] as int?) ?? 0;

    final String? st = raw['st'] as String?;
    if (st != null) {
      final int? date = raw['date'] as int?;
      if (date == null) return null;
      if (st != 'planned' && st != 'done') return null;
      final (RouteOrigin?, List<RouteWaypoint>?) route = _routeFromJson(raw);
      return SeaTripLog(
        id: id,
        name: name,
        status: st == 'planned' ? TripStatus.planned : TripStatus.done,
        dateMs: date,
        distanceNm: (nm ?? 0).toDouble(),
        stops: stops,
        durMin: raw['dur'] as int?,
        routeOrigin: route.$1,
        routeWaypoints: route.$2,
      );
    }

    // Eski biçim (start/end) — kayıpsız göç.
    final int? start = raw['start'] as int?;
    final int? end = raw['end'] as int?;
    if (start == null || end == null) return null;
    final int measured = ((end - start) / 60000).round();
    return SeaTripLog(
      id: id,
      name: name,
      status: TripStatus.done,
      dateMs: end,
      distanceNm: (nm ?? 0).toDouble(),
      stops: stops,
      durMin: measured < 1 ? 1 : measured,
    );
  }

  /// Kaydın kopyası — durum geçişi için (PLANLANDI → GERÇEKLEŞTİ).
  /// Rota verisi AYNEN taşınır: gerçekleşen seferin rotası da açılabilir.
  SeaTripLog copyWith({TripStatus? status, int? dateMs, int? durMin}) {
    return SeaTripLog(
      id: id,
      name: name,
      status: status ?? this.status,
      dateMs: dateMs ?? this.dateMs,
      distanceNm: distanceNm,
      stops: stops,
      durMin: durMin ?? this.durMin,
      routeOrigin: routeOrigin,
      routeWaypoints: routeWaypoints,
    );
  }
}

/// ESKİ "süren seyir" kaydı — yalnız GÖÇ için okunur (v2.0 kalıntısı).
/// "Seyri başlat" demiş ama hiç bitirmemiş kaptanın kaydı çöpe atılmaz:
/// ilk açılışta PLANLANDI seferine çevrilir (dürüst durum: niyet vardı,
/// bitiş ölçümü yok). Yeni akışta bu sınıf hiçbir yerde YAZILMAZ.
class ActiveTrip {
  const ActiveTrip({
    required this.name,
    required this.startMs,
    required this.distanceNm,
    this.stops = 0,
  });

  final String name;
  final int startMs;
  final double distanceNm;
  final int stops;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'start': startMs,
        'nm': distanceNm,
        'stops': stops,
      };

  static ActiveTrip? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? name = raw['name'] as String?;
    final int? start = raw['start'] as int?;
    final num? nm = raw['nm'] as num?;
    if (name == null || start == null) return null;
    return ActiveTrip(
      name: name,
      startMs: start,
      distanceNm: (nm ?? 0).toDouble(),
      stops: (raw['stops'] as int?) ?? 0,
    );
  }
}

/// Seyir deposu arayüzü — testte sahtesiyle değiştirilir.
/// loadActive/saveActive yalnız eski-kayıt GÖÇÜ için durur.
abstract interface class SeaTripLogStore {
  Future<List<SeaTripLog>> load();
  Future<void> save(List<SeaTripLog> trips);

  /// ESKİ süren seyir (yoksa null) — göçte okunur, sonra null'a çekilir.
  Future<ActiveTrip?> loadActive();
  Future<void> saveActive(ActiveTrip? trip);
}
