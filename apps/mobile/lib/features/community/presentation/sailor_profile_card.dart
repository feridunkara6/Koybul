import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../deck/application/trip_log_controller.dart';
import '../../deck/domain/sea_trip_log.dart';
import '../application/reputation_controller.dart';
import 'sailor_level_screen.dart';

/// TEKNEM sekmesindeki "Denizci Profilim" kartı.
///
/// Tekne kimlik kartı ile bakım takibi ARASINA girer; ikisine de dokunmaz.
/// HESAP YOKSA HİÇ ÇİZİLMEZ — misafirin Teknem sekmesi bugünküyle birebir
/// aynı kalır (kurucu kararı 2026-08).
///
/// Sayılar iki kaynaktan gelir ve hiçbiri uydurulmaz: SEYİR/NM cihazdaki
/// gerçek seyir kayıtlarından (Defter'deki sezon özetiyle AYNI hesap), katkı
/// puanı ve seviye sunucudan.
class SailorProfileCard extends ConsumerWidget {
  const SailorProfileCard({super.key});

  static String _fmtNm(double nm) => nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasRealAccountProvider)) return const SizedBox.shrink();

    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<ReputationSummary> async = ref.watch(reputationSummaryProvider);
    // valueOrNull ŞART: hata durumunda .value istisnayı YENİDEN FIRLATIR ve
    // ağ yokken bütün Teknem sekmesi çökerdi (CI dersi 2026-08).
    final ReputationSummary s = async.valueOrNull ?? ReputationSummary.empty;

    // Sezon istatistiği Defter'deki hesabın aynısı — iki ekranda iki farklı
    // sayı görünmesin diye aynı kaynaktan, aynı kuralla.
    final int year = DateTime.now().year;
    int trips = 0;
    double nm = 0;
    for (final SeaTripLog x in ref.watch(tripLogProvider)) {
      if (DateTime.fromMillisecondsSinceEpoch(x.endMs).year != year) continue;
      trips++;
      nm += x.distanceNm;
    }

    return Container(
      key: const ValueKey<String>('sailor-profile-card'),
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SailorLevelScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: DocklyColors.accentTurquoise.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: DocklyIcon(DocklyIcons.award,
                            size: 18, color: DocklyColors.accentTurquoise),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            t.sailorProfileTitle,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.levelLabel(s.levelCode),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: DocklyColors.accentTurquoise,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DocklyIcon(DocklyIcons.arrowForward,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                // EŞİT BOY: liste içinde yükseklik sınırsızdır — stretch kullanan
                // Row IntrinsicHeight ile sarılmazsa "sonsuz yükseklik" verir.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: _Stat(caption: t.sailorTripsCap, value: '$trips')),
                      Expanded(
                        child: _Stat(
                          caption: t.sailorNmCap,
                          value: nm > 0 ? '≈ ${_fmtNm(nm)}' : '—',
                        ),
                      ),
                      Expanded(
                        child: _Stat(caption: t.sailorPointsCap, value: '${s.points}'),
                      ),
                    ],
                  ),
                ),
                // Bölgesel uzmanlık: "Fethiye · 22 katkı". Katkı yoksa çizilmez —
                // boş çip şeridi hiçbir şey anlatmaz.
                if (s.areas.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final AreaExpertise a in s.areas)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${a.name} · ${L10n.fmt(t.sailorAreaCountFmt, '${a.count}')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (s.isEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    t.sailorProfileEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kart içi sayı hücresi: küçük başlık + belirgin değer (sezon kartıyla aynı dil).
class _Stat extends StatelessWidget {
  const _Stat({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
