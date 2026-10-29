import '../../route/domain/sea_trip.dart' show RouteOrigin, RouteWaypoint;
import 'sea_trip_log.dart';

/// SEYİR PAYLAŞIM YÜKÜ (SP-3b, kurucu onayı 2026-10-31) — "Toplulukla
/// paylaş" anahtarı açıkken sunucuya giden YAPISAL özet.
///
/// GİZLİLİK KURALI BURADA YAŞAR (test edilebilir, tek yer):
/// - "Konumum" başlangıçlı seyirde başlangıç adı GÖNDERİLMEZ (null).
/// - Koordinat ve iz HİÇBİR durumda yüke girmez — alanları yoktur.
class TripSharePayload {
  const TripSharePayload({
    required this.startName,
    required this.endName,
    required this.distanceNm,
    required this.durationMin,
    required this.stopCount,
    required this.sailedOn,
  });

  final String? startName;
  final String? endName;
  final double distanceNm;
  final int? durationMin;
  final int stopCount;

  /// 'YYYY-MM-DD' — sefer günü (gün hassasiyeti; saat iddiası yok).
  final String sailedOn;
}

/// Seyir kaydından paylaşım yükü kurar. [durMin] sayfadaki süre seçimidir;
/// [day] kaptanın onayladığı sefer günü.
TripSharePayload buildTripSharePayload({
  required SeaTripLog trip,
  required int? durMin,
  required DateTime day,
}) {
  final RouteOrigin? org = trip.routeOrigin;
  final List<RouteWaypoint>? wps = trip.routeWaypoints;
  return TripSharePayload(
    // Cihaz konumu başlangıcı PAYLAŞILMAZ (kurucu kuralı) — adı bile.
    startName: (org != null && !org.isDevice) ? org.name : null,
    endName: (wps != null && wps.isNotEmpty) ? wps.last.name : null,
    distanceNm: trip.distanceNm,
    durationMin: durMin,
    stopCount: trip.stops,
    sailedOn: '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}',
  );
}
