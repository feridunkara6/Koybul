import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../deck/application/trip_log_controller.dart';
import '../../deck/domain/sea_trip_log.dart';
import '../application/reputation_controller.dart';
import 'badges_screen.dart';
import 'reputation_shell.dart';
import 'sailor_level_screen.dart';

/// PROFİL sekmesindeki "Denizci Profilim" kartı.
///
/// Teknem Konsept A (kullanıcı onayı 2026-08) ile Teknem'den Profil'e
/// taşındı: bu kart KAPTANIN kimliğidir, teknenin değil. Hesap kartının
/// hemen altında durur. HESAP YOKSA HİÇ ÇİZİLMEZ — misafirin Profil ekranı
/// bugünküyle birebir aynı kalır (kurucu kararı 2026-08 aynen sürer).
///
/// Sayılar iki kaynaktan gelir ve hiçbiri uydurulmaz: SEYİR/NM cihazdaki
/// gerçek seyir kayıtlarından (Defter'deki sezon özetiyle AYNI hesap), katkı
/// puanı ve seviye sunucudan.
class SailorProfileCard extends ConsumerWidget {
  const SailorProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasRealAccountProvider)) return const SizedBox.shrink();

    // TÜM izlemeler build içinde yapılır. `onData` geri çağrısı build bittikten
    // SONRA koşar; oradan ref.watch etmek aboneliği her karede kapatıp yeniden
    // açardı (Riverpod, build sonunda yenilenmeyen bağımlılıkları kapatır).
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<ReputationSummary> async = ref.watch(reputationSummaryProvider);

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

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: _card(context, t, async, trips, nm),
    );
  }

  /// SEYİR ve NM CİHAZDAN gelir — ağ hatası onları GİZLEMEZ. Kart her zaman
  /// çizilir; yalnız sunucudan gelen bölüm (seviye, puan, bölge, rozet)
  /// hata/yükleme durumuna göre değişir. Eskiden kartın tamamı kayboluyor ve
  /// telefonda duran seyir kayıtları da görünmez oluyordu (inceleme bulgusu).
  Widget _card(
    BuildContext context,
    L10n t,
    AsyncValue<ReputationSummary> async,
    int trips,
    double nm,
  ) {
    final ThemeData theme = Theme.of(context);
    final ReputationSummary? data = async.valueOrNull;
    final ReputationSummary s = data ?? ReputationSummary.empty;
    final bool failed = data == null && async.hasError;
    final bool loading = data == null && !async.hasError;

    return Container(
      key: const ValueKey<String>('sailor-profile-card'),
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
                      // Ad varsa BAŞ HARFLER, yoksa genel rozet ikonu.
                      // Uydurma harf gösterilmez (0-uydurma kuralı).
                      child: Center(
                        child: s.initials.isEmpty
                            ? const DocklyIcon(DocklyIcons.award,
                                size: 18, color: DocklyColors.accentTurquoise)
                            : Text(
                                s.initials,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: DocklyColors.accentTurquoise,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            // Kartın başlığı KAPTANIN ADIDIR; ad gelmediyse
                            // bölüm adına düşer (onaylı tasarım: "FK · Feridun Kara").
                            s.displayName.isEmpty ? t.sailorProfileTitle : s.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // Seviye PUANDAN türetilir (sunucunun level_code'u
                            // ödül yazımından sonra bir an geride kalabiliyor).
                            // Veri yokken seviye UYDURULMAZ: "Yeni Denizci"
                            // yazmak 2.840 puanlı kaptana yalan olurdu.
                            data == null
                                ? (failed ? t.reputationLoadFailed : '—')
                                : t.levelLabel(levelForPoints(s.points)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: failed
                                  ? theme.colorScheme.onSurfaceVariant
                                  : DocklyColors.accentTurquoise,
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
                      Expanded(
                        child: _Stat(caption: t.sailorTripsCap, value: formatCount(t, trips)),
                      ),
                      Expanded(
                        child: _Stat(
                          caption: t.sailorNmCap,
                          value: nm > 0 ? '≈ ${formatNm(t, nm)}' : '—',
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          caption: t.sailorPointsCap,
                          // Sunucudan gelmediyse SIFIR YAZILMAZ: "0 puan" ile
                          // "ulaşamadım" aynı şey değildir.
                          value: data == null ? '—' : formatCount(t, s.points),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bölgesel uzmanlık: "Fethiye · 22 katkı". Katkı yoksa çizilmez —
                // boş çip şeridi hiçbir şey anlatmaz.
                if (data != null && s.areas.isNotEmpty) ...<Widget>[
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
                            '${a.name} · '
                            '${L10n.fmt(t.sailorAreaCountFmt, formatCount(t, a.count))}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // ROZETLERİM — onaylı tasarımda karttan DOĞRUDAN açılır.
                // Seviye ekranının arkasına saklanınca üç dokunuş uzağa
                // düşüyordu (inceleme bulgusu 2026-08).
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey<String>('sailor-badges'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const BadgesScreen()),
                    ),
                    icon: const DocklyIcon(DocklyIcons.award, size: 16),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 34),
                    ),
                    label: Text(
                      s.earnedBadges.isEmpty
                          ? t.sailorBadgesCta
                          : '${t.sailorBadgesCta} · ${s.earnedBadges.length}',
                    ),
                  ),
                ),
                // "Henüz katkın yok" YALNIZ veri GERÇEKTEN geldiyse yazılır.
                if (data != null && s.isEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    t.sailorProfileEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                if (loading) const LinearProgressIndicator(minHeight: 2),
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
