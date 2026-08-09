/// GÜNÜN ÖZETİ — SAF hesaplar (E2 "Bugün" onaylı tasarımı, 2026-08).
///
/// Üç kutu: RÜZGÂR (aralık + baskın yön) · EN İYİ SAAT (en sakin pencere) ·
/// DENİZ (rüzgâra göre beklenen durum). Hepsi TEK kaynaktan — MET Norway
/// saatlik tahmini — türetilir; ölçüm değildir ve arayüz bunu açıkça yazar.
/// Veri yoksa kutu ÇİZİLMEZ (0-uydurma).
library;

import 'package:dockly_api/dockly_api.dart' show ForecastPoint, WeatherForecast;

import '../../route/domain/route_wind.dart' show dir8Tr;

/// Denizin rüzgârdan TÜRETİLEN beklenen durumu (ölçüm değil — arayüz
/// başlıkta "rüzgâra göre" der).
enum SeaState { calm, light, choppy, rough, veryRough }

/// Günün özeti. [bestFromHour]/[bestToHour] null ise sakin pencere
/// hesaplanamamıştır (yeterli saatlik veri yok) — kutu gizlenir.
class DaySummary {
  const DaySummary({
    required this.minKn,
    required this.maxKn,
    required this.dirTr,
    required this.sea,
    this.bestFromHour,
    this.bestToHour,
  });

  final double minKn;
  final double maxKn;

  /// Günün baskın rüzgâr yönü (TR pusula kodu: 'K', 'GB'...).
  final String dirTr;

  final SeaState sea;
  final int? bestFromHour;
  final int? bestToHour;
}

/// Sakin pencere uzunluğu (saat) — "EN İYİ SAAT" bu kadar saatlik dilimdir.
const int kBestWindowHours = 5;

/// Bugünün (tahminin ilk 24 saati) özetini çıkarır. Nokta yoksa null.
DaySummary? summarizeDay(WeatherForecast? forecast) {
  if (forecast == null || forecast.points.isEmpty) return null;
  final DateTime start = forecast.points.first.time;
  final DateTime end = start.add(const Duration(hours: 24));
  final List<ForecastPoint> day = <ForecastPoint>[
    for (final ForecastPoint p in forecast.points)
      if (!p.time.isAfter(end)) p,
  ];
  if (day.isEmpty) return null;
  double min = day.first.windKn;
  double max = day.first.windKn;
  // Baskın yön: en KUVVETLİ saatin yönü (kaptanı ilgilendiren yön odur).
  int dirOfMax = day.first.windDirDeg;
  for (final ForecastPoint p in day) {
    if (p.windKn < min) min = p.windKn;
    if (p.windKn > max) {
      max = p.windKn;
      dirOfMax = p.windDirDeg;
    }
  }
  // EN SAKİN PENCERE: ardışık [kBestWindowHours] saatlik dilimler içinde
  // tepe rüzgârı en düşük olanı. Yeterli nokta yoksa null.
  int? bestFrom;
  int? bestTo;
  if (day.length >= kBestWindowHours) {
    double bestPeak = double.infinity;
    for (int i = 0; i + kBestWindowHours <= day.length; i++) {
      double peak = 0;
      for (int j = i; j < i + kBestWindowHours; j++) {
        if (day[j].windKn > peak) peak = day[j].windKn;
      }
      if (peak < bestPeak) {
        bestPeak = peak;
        bestFrom = day[i].time.toLocal().hour;
        bestTo = day[i + kBestWindowHours - 1].time.toLocal().hour;
      }
    }
  }
  return DaySummary(
    minKn: min,
    maxKn: max,
    dirTr: dir8Tr(dirOfMax),
    sea: seaStateFor(max),
    bestFromHour: bestFrom,
    bestToHour: bestTo,
  );
}

/// Rüzgâr hızından beklenen deniz durumu (Beaufort mantığı — kaba ölçek).
/// ÖLÇÜM DEĞİLDİR: gerçek dalga; mesafe, süre ve akıntıya da bağlıdır.
SeaState seaStateFor(double windKn) {
  if (windKn < 7) return SeaState.calm;
  if (windKn < 16) return SeaState.light;
  if (windKn < 22) return SeaState.choppy;
  if (windKn < 28) return SeaState.rough;
  return SeaState.veryRough;
}
