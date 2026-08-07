import 'package:dockly_api/dockly_api.dart' show LocationSummary;
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/today/domain/day_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/search_fakes.dart' show sampleSummary;
import '../../support/weather_fakes.dart' show sampleForecast;

/// AKILLI ÖNERİ puanlayıcısı (v2.0 "Bugün Nereye?") — SAF birim testleri.
/// Kural: puan uydurulmaz; her kesintinin/rozetin gerekçesi vardır.
void main() {
  test('korunaklı koy, rüzgâra açık koyu geçer (aynı mesafe)', () {
    // Rüzgâr bugün K'den (0°) ~20 kn esiyor.
    final LocationSummary a = sampleSummary('a', 'Korunaklı Koy');
    final LocationSummary b = sampleSummary('b', 'Açık Koy');
    final DaySuggestion sa = scoreCandidate(
      place: a,
      exposedDirs: 'G,GB', // güneye açık — bugünkü rüzgâr vurmaz
      forecast: sampleForecast(windKn: 20, windDirDeg: 0),
    );
    final DaySuggestion sb = scoreCandidate(
      place: b,
      exposedDirs: 'K', // kuzeye açık — bugünkü rüzgâr tam üstüne
      forecast: sampleForecast(windKn: 20, windDirDeg: 0),
    );
    expect(sa.score, 100);
    expect(sa.reasons.map((SuggestReason r) => r.kind),
        contains(SuggestReasonKind.sheltered));
    expect(sb.score, 60); // −40 (16 kn eşiği aşıldı, 25 altı)
    final SuggestReason exposed = sb.reasons
        .firstWhere((SuggestReason r) => r.kind == SuggestReasonKind.exposed);
    expect(exposed.dir, 'K');
    expect(exposed.windKn, greaterThanOrEqualTo(16));
    expect(sa.score, greaterThan(sb.score));
  });

  test('sert rüzgârda (≥25 kn) kesinti büyür: −60', () {
    final DaySuggestion s = scoreCandidate(
      place: sampleSummary('c', 'Fırtınalı Koy'),
      exposedDirs: 'K',
      forecast: sampleForecast(windKn: 30, windDirDeg: 0),
    );
    expect(s.score, 40);
  });

  test('açık yön bilgisi yoksa küçük belirsizlik kesintisi (−10) + dürüst rozet',
      () {
    final DaySuggestion s = scoreCandidate(
      place: sampleSummary('d', 'Bilinmez Koy'),
      exposedDirs: null,
      forecast: sampleForecast(),
    );
    expect(s.score, 90);
    expect(s.reasons.map((SuggestReason r) => r.kind),
        contains(SuggestReasonKind.exposureUnknown));
    // Tahmin alınamadıysa da aynı dürüst yol izlenir.
    final DaySuggestion s2 = scoreCandidate(
      place: sampleSummary('d2', 'Tahminsiz Koy'),
      exposedDirs: 'K',
      forecast: null,
    );
    expect(s2.score, 90);
  });

  test('mesafe: ilk 5 nm serbest (yakın rozeti); sonrası nm başına −2, '
      'tavan −30', () {
    final DaySuggestion near = scoreCandidate(
      place: sampleSummary('e', 'Yakın Koy', distanceNm: 3.2),
      exposedDirs: 'G',
      forecast: sampleForecast(windKn: 5, windDirDeg: 0),
    );
    expect(near.score, 100);
    expect(near.reasons.map((SuggestReason r) => r.kind),
        contains(SuggestReasonKind.near));

    final DaySuggestion mid = scoreCandidate(
      place: sampleSummary('f', 'Orta Koy', distanceNm: 15),
      exposedDirs: 'G',
      forecast: sampleForecast(windKn: 5, windDirDeg: 0),
    );
    expect(mid.score, 80); // (15−5)×2 = 20 kesinti

    final DaySuggestion far = scoreCandidate(
      place: sampleSummary('g', 'Uzak Koy', distanceNm: 40),
      exposedDirs: 'G',
      forecast: sampleForecast(windKn: 5, windDirDeg: 0),
    );
    expect(far.score, 70); // tavan −30
  });

  test('tekne bilinen limiti aşıyorsa −50 + uyarı rozeti; sığıyorsa rozet',
      () {
    const MyBoat boat = MyBoat(lengthM: 18);
    final DaySuggestion tooBig = scoreCandidate(
      place: sampleSummary('h', 'Küçük İskele', maxBoatLengthM: 12),
      exposedDirs: 'G',
      forecast: sampleForecast(windKn: 5, windDirDeg: 0),
      boat: boat,
    );
    expect(tooBig.score, 50);
    expect(tooBig.reasons.map((SuggestReason r) => r.kind),
        contains(SuggestReasonKind.boatTooBig));

    final DaySuggestion fits = scoreCandidate(
      place: sampleSummary('i', 'Büyük Marina', maxBoatLengthM: 30),
      exposedDirs: 'G',
      forecast: sampleForecast(windKn: 5, windDirDeg: 0),
      boat: boat,
    );
    expect(fits.score, 100);
    expect(fits.reasons.map((SuggestReason r) => r.kind),
        contains(SuggestReasonKind.boatFits));
  });

  test('TANINMAYAN açık yön kodu ("N,NE" gibi) korunaklı SAYILMAZ — '
      'bilgi yok yoluna düşer (0-uydurma)', () {
    final DaySuggestion s = scoreCandidate(
      place: sampleSummary('k', 'Yabancı Kodlu Koy'),
      exposedDirs: 'N,NE', // TR kodu değil — okunamadı demektir
      forecast: sampleForecast(windKn: 20, windDirDeg: 0),
    );
    expect(s.score, 90);
    expect(s.reasons.map((SuggestReason r) => r.kind),
        contains(SuggestReasonKind.exposureUnknown));
    expect(s.reasons.map((SuggestReason r) => r.kind),
        isNot(contains(SuggestReasonKind.sheltered)));
  });

  test('açık yöne yalnız HAFİF rüzgâr esiyorsa ne kesinti ne iddia', () {
    final DaySuggestion s = scoreCandidate(
      place: sampleSummary('l', 'Hafif Rüzgârlı Koy'),
      exposedDirs: 'K',
      // Tek saatlik tahmin: K'den 5 kn — eşik (16) altında.
      forecast: sampleForecast(windKn: 5, windDirDeg: 0, hours: 1),
    );
    expect(s.score, 100);
    expect(s.reasons.map((SuggestReason r) => r.kind),
        isNot(contains(SuggestReasonKind.sheltered)));
    expect(s.reasons.map((SuggestReason r) => r.kind),
        isNot(contains(SuggestReasonKind.exposed)));
  });

  test('puan 0 altına inmez', () {
    final DaySuggestion s = scoreCandidate(
      place: sampleSummary('j', 'Her Şey Ters', distanceNm: 40, maxBoatLengthM: 8),
      exposedDirs: 'K',
      forecast: sampleForecast(windKn: 30, windDirDeg: 0),
      boat: const MyBoat(lengthM: 18),
    );
    expect(s.score, 0); // 100 −60 −30 −50 → tabana kenetlenir
  });
}
