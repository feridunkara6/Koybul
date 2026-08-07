import 'dart:math' as math;

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/weather_controller.dart';

/// Detay sayfası "Rüzgâr & Hava" kartı. HASSAS VERİ İLKELERİ:
/// - Değerler sunucudan aynen gösterilir (knot, 1 ondalık) + HAMLE ayrıca.
/// - Her tahmin dilimi saat etiketi taşır; kartın altında veri saati damgası,
///   zorunlu MET Norway atfı ve "tahmindir" ibaresi yer alır.
/// - 20+ kn turuncu, 30+ kn kırmızı vurgulanır (tasarım durum renkleri).
/// - Yüklenirken küçük gösterge; hata/boş → kart sessizce gizlenir.
class WeatherCard extends ConsumerWidget {
  const WeatherCard({required this.position, this.accent, super.key});

  final GeoPoint position;

  /// Tip kimlik rengi (2026-08) — başlık ikonu.
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final key = weatherKeyFor(position.lat, position.lon);
    final AsyncValue<WeatherForecast> async = ref.watch(weatherForecastProvider(key));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
      data: (WeatherForecast f) {
        if (f.points.isEmpty) return const SizedBox.shrink();
        final ThemeData theme = Theme.of(context);
        final ForecastPoint now = f.points.first;
        final List<ForecastPoint> slices = _sixHourSlices(f.points);
        // KART görünümü (ürün kararı): bölüm kendi kutusunda — Demirleme
        // Notları ile aynı dil: yumuşak zemin, 16 px köşe, ince çerçeve.
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                DocklyIcon(DocklyIcons.explore,
                    size: 18, color: accent ?? theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(t.wxTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            // ŞİMDİKİ durum: büyük satır — ok + hız + yön + hamle + sıcaklık.
            Row(
              children: <Widget>[
                _WindArrow(dirDeg: now.windDirDeg, size: 28, color: _windColor(now.windKn, theme)),
                const SizedBox(width: 10),
                Text(
                  '${_fmtKn(now.windKn)} kn',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _windColor(now.windKn, theme),
                  ),
                ),
                const SizedBox(width: 8),
                Text(t.compassDir(compassTr(now.windDirDeg)),
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (now.gustKn != null)
                      Text(
                        L10n.fmt(t.wxGustFmt, _fmtKn(now.gustKn!)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _windColor(now.gustKn!, theme),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text('${now.tempC.toStringAsFixed(0)}°',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 6 saatlik dilimler: yatay mini kolonlar (saat, ok, knot).
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: slices.length,
                separatorBuilder: (BuildContext _, int __) => const SizedBox(width: 14),
                itemBuilder: (BuildContext context, int i) {
                  final ForecastPoint p = slices[i];
                  final Color c = _windColor(p.windKn, theme);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(_hourLabel(p.time),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      _WindArrow(dirDeg: p.windDirDeg, size: 16, color: c),
                      const SizedBox(height: 6),
                      Text(_fmtKn(p.windKn),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700, color: c)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Dürüstlük satırı: tahmin uyarısı + veri saati + ZORUNLU atıf.
            Text(
              L10n.fmt2(t.wxDisclaimerFmt, f.attribution, _hourLabel(f.fetchedAt)),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
            ),
          ),
        );
      },
    );
  }

  /// İlk 48 saatten ~6 saat arayla en fazla 8 dilim seçer (ilk nokta dahil).
  static List<ForecastPoint> _sixHourSlices(List<ForecastPoint> points) {
    final List<ForecastPoint> out = <ForecastPoint>[];
    DateTime? last;
    for (final ForecastPoint p in points) {
      if (last == null || p.time.difference(last).inHours >= 6) {
        out.add(p);
        last = p.time;
        if (out.length == 8) break;
      }
    }
    return out;
  }

  static String _fmtKn(double kn) =>
      kn == kn.roundToDouble() ? kn.toStringAsFixed(0) : kn.toStringAsFixed(1);

  static String _hourLabel(DateTime utc) {
    final DateTime t = utc.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:00';
  }

  static Color _windColor(double kn, ThemeData theme) {
    if (kn >= 30) return DocklyColors.error;
    if (kn >= 20) return DocklyColors.warning;
    return theme.colorScheme.onSurface;
  }
}

/// 8 yönlü Türkçe pusula etiketi (K=Kuzey ... KB=Kuzeybatı).
String compassTr(int deg) {
  const List<String> dirs = <String>['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
  return dirs[(((deg % 360) + 360) % 360 + 22.5) ~/ 45 % 8];
}

/// Rüzgâr yön oku: navigasyon ikonu, rüzgârın GİTTİĞİ yöne döndürülür
/// (meteorolojik ok akış yönünü gösterir; `windDirDeg` geldiği yöndür → +180°).
class _WindArrow extends StatelessWidget {
  const _WindArrow({required this.dirDeg, required this.size, required this.color});

  final int dirDeg;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (dirDeg + 180) * math.pi / 180,
      child: DocklyIcon(DocklyIcons.navigation, size: size, color: color),
    );
  }
}
