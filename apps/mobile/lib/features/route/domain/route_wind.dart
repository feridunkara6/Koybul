import 'dart:math' as math;

import 'package:dockly_api/dockly_api.dart' show ForecastPoint, GeoPoint, WeatherForecast;

import 'sea_route.dart';
import 'sea_router.dart';

/// ROTA RÜZGÂR ANALİZİ (Rota v2, 2026-08) — saf alan mantığı (birim testli).
///
/// Rota kırıklıkları üzerinde örnek noktalar seçilir (kalkış, ~1/3, ~2/3,
/// varış); her örneğin ETA'sındaki MET Norway tahmini bacak yönüyle
/// kesiştirilir: en kuvvetli rüzgâr, karşı-rüzgâr bacakları ve varış koyunun
/// açık yönü uyarısı üretilir. DÜRÜSTLÜK: tahmin penceresine oturmayan örnek
/// ATLANIR (uydurma yok); hiç örnek kalmazsa rapor üretilmez; eşikler rüzgâr
/// rozetiyle AYNIDIR (wind_warning_badge.dart: 16/25 kn) — iki yüzey çelişmez.

/// Uyarı eşiği (kn) — rozetle aynı (4-5 bofor başlangıcı).
const double kRouteWindWarnKn = 16;

/// Kuvvetli eşik (kn) — rozetle aynı (6 bofor).
const double kRouteWindStrongKn = 25;

/// Karşı-rüzgâr sektörü: bacak yönü ile rüzgârın GELDİĞİ yön arasındaki fark
/// bu değerin altındaysa rüzgâr pruvadandır.
const double kHeadwindHalfDeg = 45;

/// Örnek tahminle ETA arasındaki en büyük kabul edilebilir fark (saat) —
/// daha uzağa düşen örnek dürüstçe atlanır.
const double kMaxForecastGapHours = 3;

/// 8 yönlü TR pusula kodları (K/KD/D/GD/G/GB/B/KB) — `wind_exposed_dirs` ve
/// `wind_sheltered_dirs` verisinin ve l10n `windExposedLabel` etiketlerinin
/// aynı kod alanı. Yön→derece çeviren tablolar (rüzgâr rozeti, öneri motoru,
/// not bırakma) hâlâ kendi eşlemelerini tutar; bu liste yalnız KOD DİZİSİDİR.
const List<String> kDir8 = <String>['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];

String dir8Tr(int deg) => kDir8[(((deg % 360) + 360) % 360 / 45.0).round() % 8];

/// İki açı arasındaki en küçük fark (0-180).
double angleDiffDeg(double a, double b) {
  final double d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// Rüzgâr pruvadan mı? (rüzgârın geldiği yön ≈ gidiş yönü)
bool isHeadwind(int windDirDeg, double legBearingDeg) =>
    angleDiffDeg(windDirDeg.toDouble(), legBearingDeg) <= kHeadwindHalfDeg;

/// Rota üzerinde örnek nokta: konum + kalkıştan süre + o bacağın yönü.
class RouteSample {
  const RouteSample({
    required this.point,
    required this.etaHours,
    required this.bearingDeg,
  });

  final GeoPoint point;
  final double etaHours;
  final double bearingDeg;
}

/// Rota kırıklıklarından eşit-aralıklı örnekler (kalkış dahil, varış dahil).
List<RouteSample> routeSamplePoints(
  SeaRoutePlan plan, {
  double speedKn = kDefaultCruiseKn,
  int count = 4,
}) {
  final List<GeoPoint> pts = plan.points;
  if (pts.length < 2 || plan.distanceNm <= 0 || speedKn <= 0) {
    return <RouteSample>[];
  }
  // Bacak uzunlukları ve kümülatif mesafe.
  final List<double> legNm = <double>[];
  for (int i = 1; i < pts.length; i++) {
    legNm.add(haversineNm(pts[i - 1], pts[i]));
  }
  final double total = legNm.fold(0, (double a, double b) => a + b);
  if (total <= 0) return <RouteSample>[];
  final List<RouteSample> out = <RouteSample>[];
  final int n = math.max(2, count);
  for (int k = 0; k < n; k++) {
    final double target = total * k / (n - 1);
    double acc = 0;
    for (int i = 0; i < legNm.length; i++) {
      final double end = acc + legNm[i];
      final bool lastLeg = i == legNm.length - 1;
      if (target <= end || lastLeg) {
        final double f = legNm[i] <= 0
            ? 0
            : ((target - acc) / legNm[i]).clamp(0.0, 1.0);
        final GeoPoint a = pts[i], b = pts[i + 1];
        out.add(RouteSample(
          point: GeoPoint(
            lat: a.lat + (b.lat - a.lat) * f,
            lon: a.lon + (b.lon - a.lon) * f,
          ),
          etaHours: target / speedKn,
          bearingDeg: initialBearingDeg(a, b),
        ));
        break;
      }
      acc = end;
    }
  }
  return out;
}

/// `when` anına EN YAKIN tahmin noktası; fark [kMaxForecastGapHours]'ı
/// aşıyorsa null (dürüstçe "bilmiyoruz").
ForecastPoint? forecastAt(WeatherForecast forecast, DateTime when) {
  ForecastPoint? best;
  double bestGap = double.infinity;
  for (final ForecastPoint p in forecast.points) {
    final double gap =
        (p.time.difference(when).inMinutes).abs() / 60.0;
    if (gap < bestGap) {
      bestGap = gap;
      best = p;
    }
  }
  if (best == null || bestGap > kMaxForecastGapHours) return null;
  return best;
}

/// Değerlendirilmiş örnek: konum/süre/yön + o andaki rüzgâr.
class RouteWindSample {
  const RouteWindSample({
    required this.sample,
    required this.windKn,
    required this.gustKn,
    required this.windDirDeg,
  });

  final RouteSample sample;
  final double windKn;
  final double? gustKn;
  final int windDirDeg;

  bool get headwind => isHeadwind(windDirDeg, sample.bearingDeg);
}

/// Varış uyarısı: koy, varıştaki rüzgârın geldiği yöne açık.
class ArrivalExposure {
  const ArrivalExposure({required this.dirTr, required this.windKn});

  /// 8-yön TR kodu (l10n `windExposedLabel` ile etiketlenir).
  final String dirTr;
  final double windKn;
}

/// Rota rüzgâr raporu — çipte gösterilen özet.
class RouteWindReport {
  const RouteWindReport({
    required this.samples,
    required this.worst,
    required this.anyHeadwind,
    this.arrival,
  });

  final List<RouteWindSample> samples;

  /// En kuvvetli rüzgârlı örnek (kn bazında).
  final RouteWindSample worst;

  final bool anyHeadwind;

  /// Varış koyu açık-yön uyarısı (veri + eşik sağlanırsa).
  final ArrivalExposure? arrival;

  bool get strong => worst.windKn >= kRouteWindStrongKn;
  bool get warn => worst.windKn >= kRouteWindWarnKn;
}

/// Değerlendirilmiş örneklerden rapor kurar. Örnek yoksa null.
/// `arrivalExposedDirs`: hedef koyun açık yönleri ('K,KD' biçimi, olabilir null).
RouteWindReport? buildRouteWindReport(
  List<RouteWindSample> samples, {
  String? arrivalExposedDirs,
}) {
  if (samples.isEmpty) return null;
  RouteWindSample worst = samples.first;
  bool head = false;
  for (final RouteWindSample s in samples) {
    if (s.windKn > worst.windKn) worst = s;
    head = head || s.headwind;
  }
  ArrivalExposure? arrival;
  final String? dirs = arrivalExposedDirs;
  if (dirs != null && dirs.trim().isNotEmpty) {
    final RouteWindSample last = samples.last;
    final String windFrom = dir8Tr(last.windDirDeg);
    final bool exposed = dirs
        .split(',')
        .map((String s) => s.trim())
        .contains(windFrom);
    if (exposed && last.windKn >= kRouteWindWarnKn) {
      arrival = ArrivalExposure(dirTr: windFrom, windKn: last.windKn);
    }
  }
  return RouteWindReport(
    samples: samples,
    worst: worst,
    anyHeadwind: head,
    arrival: arrival,
  );
}
