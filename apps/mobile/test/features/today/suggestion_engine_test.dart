import 'dart:async';

import 'package:dockly_api/dockly_api.dart'
    show LocationDetail, LocationSummary, WeatherForecast;
import 'package:dockly_core/dockly_core.dart' show NetworkFailure;
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/detail/domain/location_detail_gateway.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/today/application/suggestion_engine.dart';
import 'package:dockly_mobile/features/today/domain/day_suggestion.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:dockly_mobile/features/weather/domain/weather_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/detail_fakes.dart' show sampleMarinaDetail;
import '../../support/nearby_fakes.dart';
import '../../support/search_fakes.dart' show sampleSummary;
import '../../support/weather_fakes.dart' show sampleForecast;

/// "BUGÜN NEREYE?" motorunun İSTEK DAVRANIŞI (Faz 1 — hız).
///
/// Eski hâlinde her aday bir öncekinin detayı VE rüzgârı gelene kadar
/// bekliyordu: 8 aday = 16 sıralı gidiş-geliş (~7 sn). Buradaki testler
/// düzeltmeyi kilitler — süreyi ÖLÇMEZLER (ölçüm CI'da kaypaktır), aynı anda
/// kaç isteğin uçuşta olduğunu SAYARLAR. Sıralı bir uygulamada bu sayı her
/// zaman 1'dir.

/// Detay ağ geçidi: kaç istek aynı anda uçuşta, sayar. Yanıtları test
/// tetikler — böylece "uçuşta" anı gözlemlenebilir.
class _CountingDetailGateway implements LocationDetailGateway {
  int calls = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  final List<Completer<LocationDetail>> pending =
      <Completer<LocationDetail>>[];

  @override
  Future<LocationDetail> fetch(String idOrSlug) {
    calls++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final Completer<LocationDetail> c = Completer<LocationDetail>();
    pending.add(c);
    return c.future.whenComplete(() => inFlight--);
  }

  void completeAll({bool fail = false}) {
    for (final Completer<LocationDetail> c in pending) {
      if (c.isCompleted) continue;
      if (fail) {
        c.completeError(const NetworkFailure());
      } else {
        c.complete(sampleMarinaDetail);
      }
    }
  }
}

/// Rüzgâr ağ geçidi: çağrı sayar (hücre eşlemesi bozulursa test kırılsın).
class _CountingWeatherGateway implements WeatherGateway {
  _CountingWeatherGateway({this.fail = false});

  final bool fail;
  int calls = 0;

  @override
  Future<WeatherForecast> forecast({
    required double lat,
    required double lon,
  }) {
    calls++;
    if (fail) {
      return Future<WeatherForecast>.error(const NetworkFailure());
    }
    return Future<WeatherForecast>.value(sampleForecast());
  }
}

/// Bekleyen mikro görevleri akıt (zamanlayıcı yok — deterministik).
Future<void> _drain() async {
  for (int i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const SuggestKey _key = (lat: 36.7, lon: 28.9);

ProviderContainer _container({
  required List<LocationSummary> nearby,
  required LocationDetailGateway detail,
  required WeatherGateway weather,
}) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway(results: nearby)),
      locationDetailGatewayProvider.overrideWithValue(detail),
      weatherGatewayProvider.overrideWithValue(weather),
    ],
  );
  addTearDown(c.dispose);
  // autoDispose: dinleyici olmadan sonuç anında salınır.
  final ProviderSubscription<AsyncValue<List<DaySuggestion>>> sub =
      c.listen(daySuggestionsProvider(_key), (_, __) {});
  addTearDown(sub.close);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('adaylar AYNI ANDA sorgulanır — sıralı beklemez', () async {
    final _CountingDetailGateway detail = _CountingDetailGateway();
    final _CountingWeatherGateway weather = _CountingWeatherGateway();
    final ProviderContainer c = _container(
      nearby: <LocationSummary>[
        sampleSummary('a', 'Boynuz Bükü', distanceNm: 2),
        sampleSummary('b', 'Ekincik Koyu', distanceNm: 5),
        sampleSummary('c', 'Kille Bükü', distanceNm: 9),
      ],
      detail: detail,
      weather: weather,
    );
    final Future<List<DaySuggestion>> result =
        c.read(daySuggestionsProvider(_key).future);

    await _drain();
    // ASIL İDDİA: hiçbiri yanıt vermeden üçü de uçuşta. Sıralı kodda 1 olurdu.
    expect(detail.maxInFlight, 3);
    expect(detail.calls, 3);

    detail.completeAll();
    final List<DaySuggestion> out = await result;
    expect(out, hasLength(3));
  });

  test('aynı ~1 km hücresinde TEK rüzgâr isteği (paralelde de eşleme sürer)',
      () async {
    // Eskiden eşleme SONUCU saklıyordu; paralelde hepsi boş kutuyu görüp ayrı
    // istek açardı. Artık İSTEK saklanıyor — bu test o farkı kilitler.
    // sampleSummary tüm adayları aynı koordinata koyar → tek hücre.
    final _CountingDetailGateway detail = _CountingDetailGateway();
    final _CountingWeatherGateway weather = _CountingWeatherGateway();
    final ProviderContainer c = _container(
      nearby: <LocationSummary>[
        sampleSummary('a', 'A', distanceNm: 2),
        sampleSummary('b', 'B', distanceNm: 4),
        sampleSummary('c', 'C', distanceNm: 6),
        sampleSummary('d', 'D', distanceNm: 8),
      ],
      detail: detail,
      weather: weather,
    );
    final Future<List<DaySuggestion>> result =
        c.read(daySuggestionsProvider(_key).future);
    await _drain();
    detail.completeAll();
    await result;

    expect(weather.calls, 1);
  });

  test('rüzgâr alınamazsa öneriler yine gelir (dürüst bozulma)', () async {
    final _CountingDetailGateway detail = _CountingDetailGateway();
    final ProviderContainer c = _container(
      nearby: <LocationSummary>[
        sampleSummary('a', 'A', distanceNm: 2),
        sampleSummary('b', 'B', distanceNm: 4),
      ],
      detail: detail,
      weather: _CountingWeatherGateway(fail: true),
    );
    final Future<List<DaySuggestion>> result =
        c.read(daySuggestionsProvider(_key).future);
    await _drain();
    detail.completeAll();

    final List<DaySuggestion> out = await result;
    expect(out, hasLength(2));
  });

  test('detay alınamazsa öneriler yine gelir (motor kırılmaz)', () async {
    final _CountingDetailGateway detail = _CountingDetailGateway();
    final ProviderContainer c = _container(
      nearby: <LocationSummary>[
        sampleSummary('a', 'A', distanceNm: 2),
        sampleSummary('b', 'B', distanceNm: 4),
      ],
      detail: detail,
      weather: _CountingWeatherGateway(),
    );
    final Future<List<DaySuggestion>> result =
        c.read(daySuggestionsProvider(_key).future);
    await _drain();
    detail.completeAll(fail: true);

    final List<DaySuggestion> out = await result;
    expect(out, hasLength(2));
  });

  test('eşit puanda sıra YAKINLIĞA göre kararlıdır', () async {
    // Dart'ın sort'u eşitlikte sırayı korumaz; motor artık beraberliği
    // sunucudan gelen mesafe sırasıyla bozuyor. Aynı girdi hep aynı çıktı.
    final List<List<String>> runs = <List<String>>[];
    for (int i = 0; i < 3; i++) {
      final _CountingDetailGateway detail = _CountingDetailGateway();
      final ProviderContainer c = _container(
        nearby: <LocationSummary>[
          sampleSummary('yakin', 'Yakın', distanceNm: 2),
          sampleSummary('orta', 'Orta', distanceNm: 2),
          sampleSummary('uzak', 'Uzak', distanceNm: 2),
        ],
        detail: detail,
        weather: _CountingWeatherGateway(),
      );
      final Future<List<DaySuggestion>> result =
          c.read(daySuggestionsProvider(_key).future);
      await _drain();
      detail.completeAll();
      final List<DaySuggestion> out = await result;
      runs.add(out.map((DaySuggestion s) => s.place.id).toList());
    }
    expect(runs[0], <String>['yakin', 'orta', 'uzak']);
    expect(runs[1], runs[0]);
    expect(runs[2], runs[0]);
  });
}
