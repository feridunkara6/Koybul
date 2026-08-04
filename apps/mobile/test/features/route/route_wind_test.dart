import 'package:dockly_api/dockly_api.dart'
    show ForecastPoint, GeoPoint, WeatherForecast;
import 'package:dockly_mobile/features/route/domain/route_wind.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:flutter_test/flutter_test.dart';

ForecastPoint _fp(DateTime t, double kn, int dir) => ForecastPoint(
      time: t,
      windKn: kn,
      gustKn: null,
      windDirDeg: dir,
      tempC: 24,
      symbol: null,
    );

void main() {
  test('dir8Tr: dereceler 8-yön TR koduna doğru eşlenir', () {
    expect(dir8Tr(0), 'K');
    expect(dir8Tr(45), 'KD');
    expect(dir8Tr(90), 'D');
    expect(dir8Tr(180), 'G');
    expect(dir8Tr(270), 'B');
    expect(dir8Tr(315), 'KB');
    expect(dir8Tr(350), 'K'); // sektör kenarı kuzeye yuvarlanır
  });

  test('isHeadwind: pruvadan gelen rüzgâr karşı, kıçtan gelen değil', () {
    expect(isHeadwind(10, 0), isTrue); // kuzeye giderken kuzeyden esiyor
    expect(isHeadwind(44, 0), isTrue); // sektör kenarı
    expect(isHeadwind(46, 0), isFalse);
    expect(isHeadwind(180, 0), isFalse); // kıçtan (pupa)
    expect(isHeadwind(350, 355), isTrue); // 360° sarımı
  });

  test('routeSamplePoints: 60 nm kuzey rotası — 4 örnek, doğru ETA ve yön', () {
    const SeaRoutePlan plan = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.0, lon: 28.0), GeoPoint(lat: 37.0, lon: 28.0)],
      distanceNm: 60,
      reachedGoal: true,
      viaSea: true,
    );
    final List<RouteSample> s = routeSamplePoints(plan); // 8 kn varsayılan
    expect(s, hasLength(4));
    expect(s.first.etaHours, 0);
    expect(s.last.etaHours, closeTo(60 / 8, 0.05));
    expect(s[1].etaHours, closeTo(2.5, 0.06));
    for (final RouteSample x in s) {
      expect(x.bearingDeg, closeTo(0, 1.5)); // kuzey
      expect(x.point.lon, closeTo(28.0, 0.001));
    }
    expect(s[2].point.lat, closeTo(36.0 + 2.0 / 3.0, 0.01));
  });

  test('forecastAt: en yakın saat seçilir; ufuk dışına dürüstçe null', () {
    final DateTime t0 = DateTime.utc(2026, 8, 4, 6);
    final WeatherForecast f = WeatherForecast(
      points: <ForecastPoint>[
        for (int h = 0; h < 6; h++) _fp(t0.add(Duration(hours: h)), 10 + h.toDouble(), 90),
      ],
      fetchedAt: t0,
      attribution: 'MET Norway (CC BY 4.0)',
    );
    final ForecastPoint? near = forecastAt(f, t0.add(const Duration(hours: 2, minutes: 20)));
    expect(near, isNotNull);
    expect(near!.windKn, 12); // t0+2h en yakın
    // Son noktadan 4 saat sonrası → 3 saat penceresinin dışında → null.
    expect(forecastAt(f, t0.add(const Duration(hours: 9, minutes: 30))), isNull);
  });

  test('buildRouteWindReport: en kuvvetli örnek + karşı rüzgâr bayrağı', () {
    const RouteSample rs = RouteSample(
      point: GeoPoint(lat: 36.5, lon: 28.0),
      etaHours: 1,
      bearingDeg: 0,
    );
    const List<RouteWindSample> samples = <RouteWindSample>[
      RouteWindSample(sample: rs, windKn: 12, gustKn: null, windDirDeg: 180),
      RouteWindSample(sample: rs, windKn: 22, gustKn: null, windDirDeg: 10),
      RouteWindSample(sample: rs, windKn: 17, gustKn: null, windDirDeg: 200),
    ];
    final RouteWindReport r = buildRouteWindReport(samples)!;
    expect(r.worst.windKn, 22);
    expect(r.anyHeadwind, isTrue); // 10° pruvadan (rota 0°)
    expect(r.warn, isTrue);
    expect(r.strong, isFalse);
    expect(r.arrival, isNull); // açık-yön verisi verilmedi
  });

  test('varış uyarısı: koy rüzgârın geldiği yöne açıksa ve eşik üstündeyse çıkar', () {
    const RouteSample rs = RouteSample(
      point: GeoPoint(lat: 36.5, lon: 28.0),
      etaHours: 3,
      bearingDeg: 90,
    );
    List<RouteWindSample> at(double kn, int dir) => <RouteWindSample>[
          RouteWindSample(sample: rs, windKn: kn, gustKn: null, windDirDeg: dir),
        ];
    // K'dan 20 kn, koy K ve KB'ye açık → uyarı var.
    final RouteWindReport r1 =
        buildRouteWindReport(at(20, 0), arrivalExposedDirs: 'K,KB')!;
    expect(r1.arrival, isNotNull);
    expect(r1.arrival!.dirTr, 'K');
    // Aynı yön ama 10 kn (eşik altı) → uyarı yok.
    final RouteWindReport r2 =
        buildRouteWindReport(at(10, 0), arrivalExposedDirs: 'K,KB')!;
    expect(r2.arrival, isNull);
    // 20 kn ama koy yalnız G'ye açık, rüzgâr K'dan → uyarı yok.
    final RouteWindReport r3 =
        buildRouteWindReport(at(20, 0), arrivalExposedDirs: 'G')!;
    expect(r3.arrival, isNull);
  });

  test('boş örnek listesi → rapor yok (uydurma yok)', () {
    expect(buildRouteWindReport(const <RouteWindSample>[]), isNull);
  });
}
