import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/weather_controller.dart';

/// RÜZGÂR UYARI ROZETİ (2026-07 ayrıştırma paketi ②).
///
/// İki doğrulanmış veriyi kesiştirir: koyun AÇIK olduğu yönler (açıklamalardan
/// çıkarılmış, elle onaylı `windExposedDirs`) + canlı MET Norway tahmini.
/// Önümüzdeki 24 saatte, koyun açık olduğu bir yönden eşik üstü rüzgâr
/// bekleniyorsa rozet çıkar: "Lodosa açık · bugün 22 kn".
///
/// DÜRÜSTLÜK KURALLARI: yön verisi olmayan koyda rozet YOK (tahmin üretilmez);
/// tahmin yüklenemezse rozet sessizce gizlenir; rüzgâr eşiğin altındaysa
/// rozet çıkmaz — rozet göründüyse gerçekten dikkat gerektirir.

/// Uyarı eşiği (kn) — 4-5 bofor başlangıcı; demirdeki tekne için anlamlı.
const double windWarnKn = 16;

/// Kuvvetli eşik (kn) — 6 bofor; rozet kırmızıya döner.
const double windStrongKn = 25;

/// Yön sektörü yarı genişliği (derece): kendi 22,5°'lik sektörü + küçük pay.
const double windSectorHalfDeg = 30;

const Map<String, double> _dirDeg = <String, double>{
  'K': 0, 'KD': 45, 'D': 90, 'GD': 135, 'G': 180, 'GB': 225, 'B': 270, 'KB': 315,
};

/// İki açı arasındaki en küçük fark (0-180).
double _angDiff(double a, double b) {
  final double d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// Uyarı sonucu: eşleşen yön + beklenen en yüksek rüzgâr.
typedef WindWarning = ({String dir, double maxKn});

/// Önümüzdeki 24 saatte, açık yönlerden gelen en kuvvetli rüzgârı bulur.
/// Eşik altında kalırsa null (rozet çıkmaz). Saf işlev — birim testli.
WindWarning? computeWindWarning(String? exposedDirs, List<ForecastPoint> points) {
  if (exposedDirs == null || exposedDirs.trim().isEmpty || points.isEmpty) {
    return null;
  }
  final List<String> dirs = exposedDirs
      .split(',')
      .map((String s) => s.trim())
      .where(_dirDeg.containsKey)
      .toList();
  if (dirs.isEmpty) return null;
  final DateTime start = points.first.time;
  String? bestDir;
  double best = 0;
  for (final ForecastPoint p in points) {
    if (p.time.difference(start).inHours > 24) break;
    for (final String d in dirs) {
      if (_angDiff(p.windDirDeg.toDouble(), _dirDeg[d]!) <= windSectorHalfDeg &&
          p.windKn > best) {
        best = p.windKn;
        bestDir = d;
      }
    }
  }
  if (bestDir == null || best < windWarnKn) return null;
  return (dir: bestDir, maxKn: best);
}

/// Detay sayfası rozeti — koy açık yönünden kuvvetli rüzgâr bekliyorsa görünür.
class WindWarningBadge extends ConsumerWidget {
  const WindWarningBadge({
    required this.exposedDirs,
    required this.position,
    super.key,
  });

  final String? exposedDirs;
  final GeoPoint position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exposedDirs == null || exposedDirs!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final key = weatherKeyFor(position.lat, position.lon);
    final AsyncValue<WeatherForecast> async = ref.watch(weatherForecastProvider(key));
    final WeatherForecast? f = async.valueOrNull;
    if (f == null) return const SizedBox.shrink(); // yükleniyor/hata → sessiz
    final WindWarning? w = computeWindWarning(exposedDirs, f.points);
    if (w == null) return const SizedBox.shrink();
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final bool strong = w.maxKn >= windStrongKn;
    final Color c = strong ? DocklyColors.error : DocklyColors.warning;
    final String kn = w.maxKn == w.maxKn.roundToDouble()
        ? w.maxKn.toStringAsFixed(0)
        : w.maxKn.toStringAsFixed(1);
    // BANT KART görünümü (detay yeniden tasarımı 2026-08, kullanıcı onaylı B):
    // tam genişlik, vurgulu başlık + kısa açıklama satırı — gözden kaçmaz.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        key: const ValueKey<String>('wind-warning-badge'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DocklyIcon(DocklyIcons.errorOutline, size: 18, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    L10n.fmt2(t.wwBadgeFmt, t.windExposedLabel(w.dir), kn),
                    maxLines: 2,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.wwBandNote,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
