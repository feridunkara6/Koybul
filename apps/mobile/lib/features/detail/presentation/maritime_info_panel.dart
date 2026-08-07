import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';

/// Tek bir denizci istatistiği: ikon + değer + etiket. Detay ekranındaki
/// "Denizci Bilgileri" panelinde kart olarak gösterilir. Salt-veri modeli —
/// hangi veriyi göstereceğine detay ekranı karar verir (uydurma veri yok:
/// yalnız dolu alanlar stat'a çevrilir).
@immutable
class MaritimeStat {
  const MaritimeStat({required this.icon, required this.value, required this.label});

  final DocklyIconData icon;
  final String value;
  final String label;
}

/// Boyut + türe özel denizci verisini, taranması kolay bir stat-kart ızgarasında
/// gösterir (2 sütun). Değer yoksa (stats boş) hiç yer kaplamaz — böylece veri
/// dolmamış lokasyonlarda boş bir başlık görünmez.
class MaritimeInfoPanel extends StatelessWidget {
  const MaritimeInfoPanel({
    required this.stats,
    this.title = 'Denizci Bilgileri',
    this.accent,
    super.key,
  });

  final List<MaritimeStat> stats;
  final String title;

  /// Tip kimlik rengi (2026-08) — başlık madalyonu ve stat ikonları.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    // Bölüm kartı (yeniden tasarım 2026-08): ikonlu başlık + stat ızgarası.
    return SectionCard(
      icon: DocklyIcons.sailing,
      title: title,
      accent: accent,
      child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 10;
            // İki sütun; dar ekranlarda taşarsa Wrap alt satıra alır.
            final double tileWidth = (constraints.maxWidth - gap) / 2;
            // Tam-satır eşiği yazı ölçeğiyle birlikte KÜÇÜLÜR: büyük yazıda
            // daha kısa değerler de tam satıra alınır (taşma değil, satır).
            final double fscale =
                MediaQuery.textScalerOf(context).scale(14) / 14;
            final int fullRowChars = (24 / fscale).round();
            // TASARIM KARARI (güncel, kullanıcı isteği 2026-08): kısa
            // değerli kutular AYNI MIN boyda; uzun değerli kutu TAM SATIRA
            // alınır ve gerektiği kadar BÜYÜR — bilgi asla kırpılmaz.
            final double tileHeight =
                MediaQuery.textScalerOf(context).scale(kMaritimeStatTileHeight);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final MaritimeStat s in stats)
                  ConstrainedBox(
                    key: ValueKey<String>('stat-${s.label}'),
                    // TAM GÖRÜNÜRLÜK (kullanıcı isteği 2026-08): sabit boy
                    // KALKTI — kısa değerlerde kutu aynı boyda kalır (min),
                    // uzun değerde kutu BÜYÜR ve metin tam okunur. Ayrıca
                    // uzun değerli kutu tek başına TAM SATIR olur ki iki dar
                    // sütuna sıkışmasın.
                    constraints: BoxConstraints(
                      minWidth: s.value.length > fullRowChars
                          ? constraints.maxWidth
                          : tileWidth,
                      maxWidth: s.value.length > fullRowChars
                          ? constraints.maxWidth
                          : tileWidth,
                      minHeight: tileHeight,
                    ),
                    child: _StatTile(stat: s, accent: accent),
                  ),
              ],
            );
          },
      ),
    );
  }
}

/// Stat kutusunun MİNİMUM yüksekliği (yazı ölçeği 1.0'da, piksel):
/// 2 satır değer (~40) + ara (2) + 1 satır etiket (~16) + dikey dolgu (24).
/// Kısa içerikte tüm kutular bu boyda; uzun içerikte kutu büyür (2026-08).
const double kMaritimeStatTileHeight = 84;

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, this.accent});

  final MaritimeStat stat;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Tip kimliği (2026-08): kutu zemini kimlik renginin çok yumuşak tonu.
        // Tema-duyarlı: karanlık modda saydamlık artar (renk iki temada okunur).
        color: accent == null
            ? theme.colorScheme.surface
            : accent!.withValues(alpha: dark ? 0.14 : 0.06),
        border: Border.all(
          color: accent?.withValues(alpha: 0.30) ?? theme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      // Dikeyde ortala: kısa içerik min yükseklikli kutuda şık dursun.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          DocklyIcon(stat.icon, size: 22, color: accent ?? DocklyColors.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  // Kırpma YOK (kullanıcı isteği 2026-08): değer kaç satır
                  // tutuyorsa kutu o kadar büyür — bilgi asla "..." olmaz.
                  stat.value,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  stat.label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
