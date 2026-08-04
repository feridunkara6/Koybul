import 'package:dockly_api/dockly_api.dart'
    show ForecastPoint, LocationDetail, WeatherForecast;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../weather/application/weather_controller.dart';
import '../domain/route_wind.dart';
import '../domain/sea_router.dart';

/// Rota rüzgâr danışmanı (Rota v2, 2026-08): çizilen deniz rotası için
/// MET Norway tahminini örnek noktalarda okur, hedef koyun açık-yön verisini
/// çekip varış uyarısı üretir. EN İYİ ÇABA: herhangi bir adım başarısızsa
/// null döner — rota çizimi ve mesafe/süre bilgisi ASLA bundan etkilenmez.
/// Testler sahtesiyle override eder (routeWindAdvisorProvider).
class RouteWindAdvisor {
  RouteWindAdvisor(this._ref);

  final Ref _ref;

  Future<RouteWindReport?> analyze(
    SeaRoutePlan plan,
    String destinationIdOrSlug, {
    DateTime? departure,
  }) async {
    try {
      final List<RouteSample> samples = routeSamplePoints(plan);
      if (samples.isEmpty) return null;
      final DateTime t0 = departure ?? DateTime.now().toUtc();
      // Aynı ~1 km hücresine tek istek (kalkış/varış yakınsa 4 → 2 çağrı).
      final Map<WeatherKey, WeatherForecast> cache =
          <WeatherKey, WeatherForecast>{};
      final List<RouteWindSample> evaluated = <RouteWindSample>[];
      for (final RouteSample s in samples) {
        final WeatherKey key = weatherKeyFor(s.point.lat, s.point.lon);
        final WeatherForecast f = cache[key] ??= await _ref
            .read(weatherGatewayProvider)
            .forecast(lat: key.lat, lon: key.lon);
        final DateTime when =
            t0.add(Duration(minutes: (s.etaHours * 60).round()));
        final ForecastPoint? fp = forecastAt(f, when);
        if (fp == null) continue; // tahmin penceresi dışında — dürüstçe atla
        evaluated.add(RouteWindSample(
          sample: s,
          windKn: fp.windKn,
          gustKn: fp.gustKn,
          windDirDeg: fp.windDirDeg,
        ));
      }
      // Varış koyunun açık yönleri (yalnız bu alan için detay çekilir;
      // başarısızlık varış uyarısını düşürür, raporu düşürmez).
      String? exposed;
      try {
        final LocationDetail d =
            await _ref.read(locationsApiProvider).detail(destinationIdOrSlug);
        exposed = d.windExposedDirs;
      } catch (_) {
        exposed = null;
      }
      return buildRouteWindReport(evaluated, arrivalExposedDirs: exposed);
    } catch (_) {
      return null;
    }
  }
}

/// Danışman sağlayıcısı — testte sahte ile override edilir.
final Provider<RouteWindAdvisor> routeWindAdvisorProvider =
    Provider<RouteWindAdvisor>((ref) => RouteWindAdvisor(ref));
