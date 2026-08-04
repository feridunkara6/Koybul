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
    super.key,
  });

  final List<MaritimeStat> stats;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    // Bölüm kartı (yeniden tasarım 2026-08): ikonlu başlık + stat ızgarası.
    return SectionCard(
      icon: DocklyIcons.sailing,
      title: title,
      child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 10;
            // İki sütun; dar ekranlarda taşarsa Wrap alt satıra alır.
            final double tileWidth = (constraints.maxWidth - gap) / 2;
            // TASARIM KARARI (kullanıcı isteği): kutucukların hepsi AYNI boyda —
            // içerik uzunluğu ne olursa olsun. Yükseklik 2 satır değer + 1 satır
            // etiket + iç boşluğu karşılar; cihazın yazı ölçeğiyle birlikte
            // büyür (erişilebilirlik: büyük yazıda taşma olmasın).
            final double tileHeight =
                MediaQuery.textScalerOf(context).scale(kMaritimeStatTileHeight);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final MaritimeStat s in stats)
                  SizedBox(
                    key: ValueKey<String>('stat-${s.label}'),
                    width: tileWidth,
                    height: tileHeight,
                    child: _StatTile(stat: s),
                  ),
              ],
            );
          },
      ),
    );
  }
}

/// Stat kutusunun SABİT yüksekliği (yazı ölçeği 1.0'da, piksel):
/// 2 satır değer (~40) + ara (2) + 1 satır etiket (~16) + dikey dolgu (24).
/// Tüm kutular bu yüksekliği kullanır → içerikten bağımsız eşit boy.
const double kMaritimeStatTileHeight = 84;

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final MaritimeStat stat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Tema-duyarlı: karanlık modda koyu yüzey/çizgi (sabit açık renk DEĞİL).
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      // Dikeyde ortala: tek satırlık içerik sabit yükseklikte şık dursun.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          DocklyIcon(stat.icon, size: 22, color: DocklyColors.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  stat.value,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
