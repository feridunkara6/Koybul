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

  // RÜZGÂR EŞLEME: hücre başına TEK istek. Saklanan şey sonuç değil, İSTEĞİN
  // KENDİSİ (Future). Sonucu saklamak yalnız sıralı çalışmada işe yarardı;
  // adaylar aynı anda koştuğunda hepsi boş kutuyu görüp ayrı ayrı istek
  // açardı ve eşleme sessizce kaybolurdu.
  final Map<WeatherKey, Future<WeatherForecast>> wxInFlight =
      <WeatherKey, Future<WeatherForecast>>{};
  // Not: gövdenin ilk `await`e kadarki kısmı SENKRON çalışır; yani kayıt
  // (`??=`) tüm adaylar için, hiçbir istek dönmeden önce tamamlanır. Eşleme
  // bu yüzden paralel çalışmada da geçerlidir.
  Future<WeatherForecast?> weatherFor(WeatherKey wk) async {
    try {
      return await (wxInFlight[wk] ??=
          ref.read(weatherGatewayProvider).forecast(lat: wk.lat, lon: wk.lon));
    } catch (_) {
      return null; // rüzgâr yoksa belirsizlik — motor yine puan verir
    }
  }

  // PARALEL (Faz 1 — hız). Eskiden her aday, bir öncekinin detayı VE rüzgârı
  // gelene kadar bekliyordu: 8 aday = 16 sıralı gidiş-geliş, ~7 saniye.
  // Adaylar arasında hiçbir veri bağımlılığı yok — hepsi aynı anda koşar,
  // bekleme en yavaş TEK adayın süresine iner (~2 gidiş-geliş).
  //
  // Sunucu tarafı bunu kaldırır: okuma bütçesi IP başına 300/dk (bu akış
  // en fazla 17 istek), hava servisi hem istemcide hem sunucuda ~1 km
  // hücreye göre önbelleklenir.
  final List<DaySuggestion> scored = await Future.wait<DaySuggestion>(
    pool.map((LocationSummary place) async {
      // DETAY KAYDI: açık yön + derinlik + zemin + doluluk (onaylı E2: her
      // önerinin gerekçesi ekranda). Alınamazsa hepsi null — motor kırılmaz.
      String? dirs;
      double? depthMin;
      double? depthMax;
      String? bottom;
      String? shelter;
      String? occupancy;
      final WeatherKey wk =
          weatherKeyFor(place.position.lat, place.position.lon);
      // Rüzgâr isteği detayı BEKLEMEDEN başlar (ikisi birbirine bağlı değil).
      final Future<WeatherForecast?> wxFuture = weatherFor(wk);
      try {
        final LocationDetail d =
            await ref.read(locationDetailGatewayProvider).fetch(place.id);
        dirs = d.windExposedDirs;
        depthMin = d.dimensions.depthMinM;
        depthMax = d.dimensions.depthMaxM;
        // Zemin ÜST DÜZEY alandan okunur (veri turu 2026-08): balıkçı barınağı
        // ve belediye limanı gibi demirleme-dışı tiplerde de dolu olabilir.
        // `typeDetails` yedeği eski sunucu sürümü için durur.
        final TypeDetails? td = d.typeDetails;
        bottom = d.seabed ?? (td is AnchorageTypeDetails ? td.holdingType : null);
        shelter = d.shelteredDirs;
        occupancy = d.occupancy?.level;
      } catch (_) {
        dirs = null;
      }
      // Rüzgâr alınamazsa null (belirsizlik) — motor yine puan verir.
      final WeatherForecast? forecast = await wxFuture;
      return scoreCandidate(
        place: place,
        exposedDirs: dirs,
        forecast: forecast,
        boat: ref.read(myBoatProvider),
        depthMinM: depthMin,
        depthMaxM: depthMax,
        bottomCode: bottom,
        shelteredDirs: shelter,
        occupancyLevel: occupancy,
      );
    }),
  );

  // SIRALAMA (kararlı): Dart'ın sort'u eşit değerlerde sırayı KORUMAZ. Eşit
  // puanlı iki koyda hangisinin önce çıkacağı rastgele olurdu; sunucu zaten
  // mesafeye göre sıralı gönderdiği için beraberliği YAKINLIK bozar.
  final List<int> order =
      List<int>.generate(scored.length, (int i) => i, growable: false);
  order.sort((int a, int b) {
    final int byScore = scored[b].score - scored[a].score;
    return byScore != 0 ? byScore : a - b;
  });
  return order
      .take(kSuggestCount)
      .map((int i) => scored[i])
      .toList(growable: false);
});
