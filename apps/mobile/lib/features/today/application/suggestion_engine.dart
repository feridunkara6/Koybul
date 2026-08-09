import 'package:dockly_api/dockly_api.dart'
    show
        AnchorageTypeDetails,
        GeoPoint,
        LocationDetail,
        LocationSummary,
        TypeDetails,
        WeatherForecast;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boat/application/my_boat_controller.dart';
import '../../detail/application/location_detail_controller.dart';
import '../../nearby/application/nearby_controller.dart';
import '../../weather/application/weather_controller.dart';
import '../domain/day_suggestion.dart';

/// AKILLI ÖNERİ motoru (v2.0 "Bugün Nereye?", kurucu onayı 2026-08).
///
/// Akış (RouteWindAdvisor deseni):
///  1) Konum çevresindeki adaylar sunucudan alınır (mesafe sıralı).
///  2) Her adayın "açık yön" bilgisi DETAY kaydından çekilir — liste
///     yükünde bu alan yok. Detay alınamazsa aday "bilgi yok" sayılır,
///     motor ASLA kırılmaz (dürüst bozulma).
///  3) Rüzgâr tahmini ~1 km hücre başına BİR kez istenir (bellek içi eş).
///  4) Saf puanlayıcı (day_suggestion.dart) sıralar; en iyi 3 gösterilir.

/// Aday havuzu (detay isteği sayısının tavanı) ve gösterilen öneri sayısı.
const int kSuggestCandidatePool = 8;
const int kSuggestCount = 3;

/// Aday arama yarıçapı (nm) — günübirlik seyir menzili.
const double kSuggestRadiusNm = 25;

/// Öneri anahtarı: konum ~11 km hücreye yuvarlanır (0.1°). KASITLI kaba
/// (inceleme dersi 2026-08): Bugün sekmesi kabukta canlı kaldığı için harita
/// gezinirken `originProvider` sürekli değişir — ince anahtar her ~1 km'de
/// motoru yeniden çalıştırıp onlarca isteğe yol açardı. 25 nm arama
/// yarıçapında 11 km'lik kayma aday kümesini neredeyse değiştirmez.
typedef SuggestKey = ({double lat, double lon});

SuggestKey suggestKeyFor(GeoPoint p) => (
      lat: (p.lat * 10).roundToDouble() / 10,
      lon: (p.lon * 10).roundToDouble() / 10,
    );

/// Günün önerileri — en iyi [kSuggestCount] aday, puan sırasıyla.
/// Yakında aday yoksa boş liste döner (arayüz dürüst boş durum yazar).
/// autoDispose: ekran anahtarı bırakınca sonuç ve istek zinciri SALINIR —
/// eski hücrelerin sonuçları uygulama ömrü boyunca bellekte birikmez.
final daySuggestionsProvider =
    FutureProvider.autoDispose.family<List<DaySuggestion>, SuggestKey>(
        (ref, SuggestKey key) async {
  final List<LocationSummary> nearby =
      await ref.watch(nearbyGatewayProvider).fetch(
            lat: key.lat,
            lon: key.lon,
            radiusNm: kSuggestRadiusNm,
            limit: kSuggestCandidatePool + 4,
          );
  final List<LocationSummary> pool =
      nearby.take(kSuggestCandidatePool).toList();
  final Map<WeatherKey, WeatherForecast> wxCache =
      <WeatherKey, WeatherForecast>{};
  final List<DaySuggestion> scored = <DaySuggestion>[];
  for (final LocationSummary place in pool) {
    // DETAY KAYDI: açık yön + derinlik + zemin + doluluk (onaylı E2: her
    // önerinin gerekçesi ekranda). Alınamazsa hepsi null — motor kırılmaz.
    String? dirs;
    double? depthMin;
    double? depthMax;
    String? bottom;
    String? occupancy;
    try {
      final LocationDetail d =
          await ref.read(locationDetailGatewayProvider).fetch(place.id);
      dirs = d.windExposedDirs;
      depthMin = d.dimensions.depthMinM;
      depthMax = d.dimensions.depthMaxM;
      final TypeDetails? td = d.typeDetails;
      if (td is AnchorageTypeDetails) bottom = td.holdingType;
      occupancy = d.occupancy?.level;
    } catch (_) {
      dirs = null;
    }
    // Rüzgâr — hücre başına tek istek; alınamazsa null (belirsizlik).
    WeatherForecast? forecast;
    final WeatherKey wk =
        weatherKeyFor(place.position.lat, place.position.lon);
    try {
      forecast = wxCache[wk] ??=
          await ref.read(weatherGatewayProvider).forecast(
                lat: wk.lat,
                lon: wk.lon,
              );
    } catch (_) {
      forecast = null;
    }
    scored.add(scoreCandidate(
      place: place,
      exposedDirs: dirs,
      forecast: forecast,
      boat: ref.read(myBoatProvider),
      depthMinM: depthMin,
      depthMaxM: depthMax,
      bottomCode: bottom,
      occupancyLevel: occupancy,
    ));
  }
  scored.sort((DaySuggestion a, DaySuggestion b) => b.score - a.score);
  return scored.take(kSuggestCount).toList();
});
