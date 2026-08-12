import 'dart:math' as math;

import 'package:dockly_api/dockly_api.dart' show GeoPoint, LocationPin;
import 'package:dockly_mobile/features/map/domain/pin_spread.dart';
import 'package:flutter_test/flutter_test.dart';

/// ÇAKIŞIK İĞNE testleri (Faz 2 — denetim bulgusu: 10 kayıt çifti birebir
/// aynı koordinatta; alttaki iğne hiç seçilemiyordu).
///
/// Sözleşme: kayıt verisi DEĞİŞMEZ, yalnız haritaya çizilen kopya açılır;
/// ilk iğne yerinde kalır; sonuç deterministiktir.
LocationPin _pin(String id, double lat, double lon) => LocationPin(
      id: id,
      name: id,
      type: 'fuel_dock',
      position: GeoPoint(lat: lat, lon: lon),
      ratingAvg: null,
      priceTier: 'paid',
    );

double _distM(GeoPoint a, GeoPoint b) {
  // Küçük mesafede düzlem yaklaşımı yeter (test toleransları geniş).
  const double mPerDegLat = 111320;
  final double dLat = (a.lat - b.lat) * mPerDegLat;
  final double dLon =
      (a.lon - b.lon) * mPerDegLat * math.cos(a.lat * math.pi / 180);
  return math.sqrt(dLat * dLat + dLon * dLon);
}

void main() {
  test('çakışma yoksa liste OLDUĞU GİBİ döner (kimlik dahil)', () {
    final List<LocationPin> pins = <LocationPin>[
      _pin('a', 36.75, 28.93),
      _pin('b', 36.76, 28.94),
    ];
    expect(identical(spreadCoincidentPins(pins), pins), isTrue);
  });

  test('birebir aynı koordinat: ilk iğne yerinde, ikincisi ~30 m açılır', () {
    final List<LocationPin> out = spreadCoincidentPins(<LocationPin>[
      _pin('marina', 36.599625, 30.573331),
      _pin('yakit', 36.599625, 30.573331),
    ]);
    final LocationPin marina =
        out.firstWhere((LocationPin p) => p.id == 'marina');
    final LocationPin yakit =
        out.firstWhere((LocationPin p) => p.id == 'yakit');
    // Kimliğe göre sıralamada baştaki ('marina' < 'yakit') yerinde kalır.
    expect(marina.position.lat, 36.599625);
    expect(marina.position.lon, 30.573331);
    final double d = _distM(marina.position, yakit.position);
    expect(d, greaterThan(20));
    expect(d, lessThan(50));
  });

  test('deterministik: aynı girdi her seferinde aynı çıktı', () {
    final List<LocationPin> input = <LocationPin>[
      _pin('b', 36.7112, 28.8967),
      _pin('a', 36.7112, 28.8967),
    ];
    final List<LocationPin> r1 = spreadCoincidentPins(input);
    final List<LocationPin> r2 = spreadCoincidentPins(input);
    for (int i = 0; i < r1.length; i++) {
      expect(r1[i].position.lat, r2[i].position.lat);
      expect(r1[i].position.lon, r2[i].position.lon);
    }
    // Girdi sırasından bağımsız: yerinde kalan hep kimlikçe küçük olan ('a').
    final LocationPin a = r1.firstWhere((LocationPin p) => p.id == 'a');
    expect(a.position.lat, 36.7112);
    expect(a.position.lon, 28.8967);
  });

  test('üçlü çakışma: hepsi birbirinden ayrışır', () {
    final List<LocationPin> out = spreadCoincidentPins(<LocationPin>[
      _pin('a', 38.3231, 26.34201),
      _pin('b', 38.3231, 26.34201),
      _pin('c', 38.3231, 26.34201),
    ]);
    for (int i = 0; i < out.length; i++) {
      for (int j = i + 1; j < out.length; j++) {
        expect(_distM(out[i].position, out[j].position), greaterThan(10),
            reason: '${out[i].id}-${out[j].id}');
      }
    }
  });

  test('iğnenin diğer alanları aynen taşınır (yalnız konum değişir)', () {
    final List<LocationPin> out = spreadCoincidentPins(<LocationPin>[
      _pin('a', 36.75, 28.93),
      _pin('b', 36.75, 28.93),
    ]);
    final LocationPin b = out.firstWhere((LocationPin p) => p.id == 'b');
    expect(b.name, 'b');
    expect(b.type, 'fuel_dock');
    expect(b.priceTier, 'paid');
  });

  test('yakın ama FARKLI koordinatlar açılmaz (yalnız birebir eşitlik)', () {
    // Setur ikilemesi gibi ~300 m ayrık kayıtlar veri sorunudur, sunum değil;
    // onlara dokunulmaz (o ikileme Faz 2'de veri tarafında kapatıldı).
    final List<LocationPin> pins = <LocationPin>[
      _pin('a', 38.3237, 26.3456),
      _pin('b', 38.3231, 26.34201),
    ];
    final List<LocationPin> out = spreadCoincidentPins(pins);
    expect(out[0].position.lat, pins[0].position.lat);
    expect(out[1].position.lat, pins[1].position.lat);
  });
}
