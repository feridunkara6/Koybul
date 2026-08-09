import 'package:dockly_api/dockly_api.dart' show ForecastPoint, WeatherForecast;
import 'package:dockly_mobile/features/today/domain/day_summary.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 9, 6);

WeatherForecast _fc(List<double> knots, {int dir = 225}) {
  return WeatherForecast(
    fetchedAt: _t0,
    attribution: 'MET Norway (CC BY 4.0)',
    points: <ForecastPoint>[
      for (int i = 0; i < knots.length; i++)
        ForecastPoint(
          time: _t0.add(Duration(hours: i)),
          windKn: knots[i],
          gustKn: null,
          windDirDeg: dir,
          tempC: 24,
          symbol: null,
        ),
    ],
  );
}

/// Saatler kullanıcıya YEREL gösterilir; test makinenin saat diliminden
/// bağımsız olsun diye beklenen değer de yerelden hesaplanır.
int _localHour(int offsetHours) =>
    _t0.add(Duration(hours: offsetHours)).toLocal().hour;

/// GÜNÜN ÖZETİ birim testleri (onaylı E2): rüzgâr aralığı, en sakin pencere,
/// rüzgârdan TÜRETİLEN deniz durumu. Veri yoksa özet de yok.
void main() {
  test('tahmin yoksa/boşsa özet üretilmez (0-uydurma)', () {
    expect(summarizeDay(null), isNull);
    expect(summarizeDay(_fc(<double>[])), isNull);
  });

  test('rüzgâr aralığı ve baskın yön: yön EN KUVVETLİ saatten alınır', () {
    final DaySummary s = summarizeDay(_fc(<double>[6, 9, 18, 12]))!;
    expect(s.minKn, 6);
    expect(s.maxKn, 18);
    expect(s.dirTr, 'GB'); // 225°
  });

  test('en sakin pencere: ardışık 5 saatin tepe rüzgârı en düşük olanı', () {
    final DaySummary s =
        summarizeDay(_fc(<double>[5, 6, 7, 6, 5, 20, 22, 24]))!;
    expect(s.bestFromHour, _localHour(0));
    expect(s.bestToHour, _localHour(4));
  });

  test('5 saatten az veri varsa pencere hesaplanmaz (kutu gizlenir)', () {
    final DaySummary s = summarizeDay(_fc(<double>[10, 11, 12]))!;
    expect(s.bestFromHour, isNull);
    expect(s.bestToHour, isNull);
  });

  test('deniz durumu rüzgâr eşiklerinden türetilir', () {
    expect(seaStateFor(4), SeaState.calm);
    expect(seaStateFor(10), SeaState.light);
    expect(seaStateFor(18), SeaState.choppy);
    expect(seaStateFor(24), SeaState.rough);
    expect(seaStateFor(35), SeaState.veryRough);
    // Özet, GÜNÜN TEPE rüzgârına göre durumu seçer (en kötü hâl esastır).
    expect(summarizeDay(_fc(<double>[4, 5, 30]))!.sea, SeaState.veryRough);
  });

  test('pencere 24 saatle sınırlı: sonraki saatler özete katılmaz', () {
    // 24. saatte (sınır dahil) sert rüzgâr → özete GİRER.
    final List<double> inside = <double>[
      for (int i = 0; i <= 24; i++) i == 24 ? 40 : 5,
    ];
    expect(summarizeDay(_fc(inside))!.maxKn, 40);
    // 25. saatte sert rüzgâr → pencere dışı, özete GİRMEZ.
    final List<double> outside = <double>[
      for (int i = 0; i <= 25; i++) i == 25 ? 40 : 5,
    ];
    expect(summarizeDay(_fc(outside))!.maxKn, 5);
  });
}
