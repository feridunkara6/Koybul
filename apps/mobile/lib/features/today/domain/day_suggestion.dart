/// AKILLI ÖNERİ v1 — SAF puanlama (v2.0 vizyonu "Bugün Nereye?", kurucu
/// onayı 2026-08). KURAL TABANLIDIR ve yalnız GERÇEK veriyle çalışır:
///  • rüzgâr = MET Norway tahmini (hava kartıyla aynı kaynak/eşikler),
///  • açık yön = koyun detay kaydındaki `windExposedDirs`,
///  • mesafe = sunucunun hesapladığı kuş uçuşu deniz mili,
///  • tekne uyumu = kaptanın tanımladığı tekne + koyun bilinen limitleri.
/// Bilgi YOKSA puan uydurulmaz: "açık yön bilgisi yok" rozeti gösterilir ve
/// küçük bir belirsizlik kesintisi uygulanır. Karar HER ZAMAN kaptanındır.
library;

import 'package:dockly_api/dockly_api.dart'
    show ForecastPoint, LocationSummary, WeatherForecast;

import '../../boat/domain/my_boat.dart';
import '../../route/domain/route_wind.dart' show angleDiffDeg;
import '../../route/domain/sea_route.dart' show etaHours;
import '../../weather/presentation/wind_warning_badge.dart'
    show windSectorHalfDeg, windStrongKn, windWarnKn;

/// Rozet türleri — arayüz her birini kendi dilinde yazar (0 uydurma:
/// yalnız gerekçesi olan rozet üretilir).
enum SuggestReasonKind {
  /// Koyun açık yönleri biliniyor ve bugünkü rüzgâr onlara esmiyor.
  sheltered,

  /// Koy, bugün beklenen rüzgâra açık ([dir] TR pusula kodu, [windKn] tepe).
  exposed,

  /// Konumuna yakın ([nm] deniz mili).
  near,

  /// Açık yön bilgisi kayıtlarda yok — rüzgâr uyumu değerlendirilemedi.
  exposureUnknown,

  /// Tekne tanımlı ve koyun bilinen limitlerine sığıyor.
  boatFits,

  /// Tekne tanımlı ama koyun bilinen limitini aşıyor.
  boatTooBig,

  /// Tahminî varış süresi ([nm] mesafe, [etaHours] saat) — seyir planı için.
  eta,

  /// Bilinen derinlik aralığı ([depthMinM]–[depthMaxM] m).
  depth,

  /// Bilinen zemin türü ([bottomCode]: sand/mud/weed/rock/mixed).
  bottom,

  /// Son bildirimlere göre kalabalık (doluluk 'full').
  crowded,

  /// Son bildirimlere göre sakin (doluluk 'empty').
  quiet,
}

class SuggestReason {
  const SuggestReason(
    this.kind, {
    this.dir,
    this.windKn,
    this.nm,
    this.etaHours,
    this.depthMinM,
    this.depthMaxM,
    this.bottomCode,
  });

  final SuggestReasonKind kind;
  final String? dir; // exposed: TR pusula kodu ('G', 'GB', ...)
  final double? windKn; // exposed: 24 saatteki tepe rüzgâr (kn)
  final double? nm; // near/eta: mesafe (deniz mili)
  final double? etaHours; // eta: seyir süresi (saat)
  final double? depthMinM; // depth: bilinen en sığ
  final double? depthMaxM; // depth: bilinen en derin
  final String? bottomCode; // bottom: zemin kodu (sand/mud/...)
}

/// Tek adayın puanı + NEDEN rozetleri. Puan 0–100 arası ve karşılaştırma
/// içindir; kesinlik iddiası değildir (arayüz bunu açıkça söyler).
class DaySuggestion {
  const DaySuggestion({
    required this.place,
    required this.score,
    required this.reasons,
  });

  final LocationSummary place;
  final int score;
  final List<SuggestReason> reasons;
}

/// Yakınlık eşiği: bu mesafeye kadar "yakın" rozeti verilir, kesinti olmaz.
const double kSuggestNearNm = 5;

/// TR 8-nokta pusula kodu → derece. Rüzgâr rozetindeki haritanın aynısı;
/// burada AYRICA doğrulama görevi görür: kayıttaki açık yön kodu bu
/// listede yoksa veri OKUNAMAMIŞ sayılır ve asla "korunaklı" denmez
/// (inceleme dersi 2026-08 — 0-uydurma).
const Map<String, int> _dirDeg = <String, int>{
  'K': 0, 'KD': 45, 'D': 90, 'GD': 135,
  'G': 180, 'GB': 225, 'B': 270, 'KB': 315,
};

/// Tek adayı puanlar — SAF fonksiyon (ağ yok, saat yok; teste açık).
///
/// Kurallar (şeffaf ve toplamsal):
///  • 100'den başlanır.
///  • Rüzgâr: açık yöne ≥16 kn esiyorsa −40 (≥25 kn ise −60). Açık yöne
///    yalnız HAFİF rüzgâr esiyorsa ne kesinti ne rozet — "korunaklı" İDDİASI
///    ancak bugünkü rüzgâr açık yönlere hiç esmiyorsa yapılır.
///  • Açık yön bilgisi yoksa/okunamıyorsa ya da tahmin alınamadıysa −10
///    (belirsizlik) + dürüst "bilgi yok" rozeti.
///  • Mesafe: ilk 5 nm serbest; sonrası nm başına −2 (en çok −30).
///  • Tekne: bilinen limiti aşıyorsa −50; sığıyorsa kesinti yok.
DaySuggestion scoreCandidate({
  required LocationSummary place,
  required String? exposedDirs,
  required WeatherForecast? forecast,
  MyBoat? boat,
  // Detay kaydından gelen EK GERÇEKLER (onaylı E2 tasarımı: "5-8 m kum,
  // teknen sığar · dün: sakin"). Bilinmeyen alan hiç rozetlenmez.
  double? depthMinM,
  double? depthMaxM,
  String? bottomCode,
  String? occupancyLevel, // 'empty' | 'moderate' | 'full'
}) {
  int score = 100;
  final List<SuggestReason> reasons = <SuggestReason>[];

  // RÜZGÂR × AÇIK YÖN — rüzgâr rozetiyle aynı eşikler (16/25 kn) ve aynı
  // ±30° sektör; pencere = tahminin ilk 24 saati.
  final List<String> openCodes = <String>[
    if (exposedDirs != null)
      for (final String raw in exposedDirs.split(','))
        if (_dirDeg.containsKey(raw.trim())) raw.trim(),
  ];
  if (openCodes.isEmpty || forecast == null || forecast.points.isEmpty) {
    score -= 10;
    reasons.add(const SuggestReason(SuggestReasonKind.exposureUnknown));
  } else {
    double maxTowardKn = 0;
    String worstDir = openCodes.first;
    final DateTime end =
        forecast.points.first.time.add(const Duration(hours: 24));
    for (final ForecastPoint p in forecast.points) {
      if (p.time.isAfter(end)) continue;
      for (final String code in openCodes) {
        final double diff = angleDiffDeg(
            p.windDirDeg.toDouble(), _dirDeg[code]!.toDouble());
        if (diff <= windSectorHalfDeg && p.windKn > maxTowardKn) {
          maxTowardKn = p.windKn;
          worstDir = code;
        }
      }
    }
    if (maxTowardKn >= windWarnKn) {
      score -= maxTowardKn >= windStrongKn ? 60 : 40;
      reasons.add(SuggestReason(
        SuggestReasonKind.exposed,
        dir: worstDir,
        windKn: maxTowardKn,
      ));
    } else if (maxTowardKn == 0) {
      // Bugünkü rüzgâr açık yönlere HİÇ esmiyor — korunaklı iddiası güvenli.
      reasons.add(const SuggestReason(SuggestReasonKind.sheltered));
    }
    // Açık yöne yalnız hafif rüzgâr (<16 kn) esiyorsa: kesinti de iddia da
    // yok — dürüst sessizlik.
  }

  // MESAFE — sunucunun verdiği kuş uçuşu nm.
  final double nm = place.distanceNm;
  if (nm <= kSuggestNearNm) {
    reasons.add(SuggestReason(SuggestReasonKind.near, nm: nm));
  } else {
    final int cut = ((nm - kSuggestNearNm) * 2).round();
    score -= cut > 30 ? 30 : cut;
  }
  // SÜRE — mesafe biliniyorsa seyir süresi tahmini (seyir hızı varsayımıyla).
  if (nm > 0) {
    reasons.add(SuggestReason(
      SuggestReasonKind.eta,
      nm: nm,
      etaHours: etaHours(nm),
    ));
  }

  // TEKNE UYUMU — yalnız tekne TANIMLIYSA ve limit BİLİNİYORSA konuşulur.
  final BoatFit fit = computeBoatFit(
    boat: boat,
    maxBoatLengthM: place.maxBoatLengthM,
    maxDraftM: place.maxDraftM,
  );
  if (fit == BoatFit.tooBig) {
    score -= 50;
    reasons.add(const SuggestReason(SuggestReasonKind.boatTooBig));
  } else if (fit == BoatFit.fits) {
    reasons.add(const SuggestReason(SuggestReasonKind.boatFits));
  }

  // DERİNLİK / ZEMİN — yalnız kayıtta VARSA rozetlenir (puanı etkilemez;
  // bilgi rozetidir: "5-8 m kum"). Eksik alan hiç çizilmez.
  if (depthMinM != null || depthMaxM != null) {
    reasons.add(SuggestReason(
      SuggestReasonKind.depth,
      depthMinM: depthMinM,
      depthMaxM: depthMaxM,
    ));
  }
  if (bottomCode != null && bottomCode.trim().isNotEmpty) {
    reasons.add(SuggestReason(SuggestReasonKind.bottom, bottomCode: bottomCode));
  }

  // KALABALIK — denizcilerin son bildirimleri (varsa). "Dolu" küçük bir
  // kesinti alır; "boş" yalnız rozettir. Bildirim yoksa hiçbir şey denmez.
  if (occupancyLevel == 'full') {
    score -= 15;
    reasons.add(const SuggestReason(SuggestReasonKind.crowded));
  } else if (occupancyLevel == 'empty') {
    reasons.add(const SuggestReason(SuggestReasonKind.quiet));
  }

  return DaySuggestion(
    place: place,
    score: score < 0 ? 0 : score,
    reasons: reasons,
  );
}
