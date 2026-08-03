import 'package:dockly_api/dockly_api.dart' show LocationPin;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../occupancy/presentation/occupancy_row.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_fit.dart';

/// Harita alt detay kartı (S-06, docs/01-prd §6.3). Pine dokununca alttan belirir:
/// tip (renk noktası + etiket), ad, puan ve fiyat rozeti. "Detay"/"Yol tarifi"
/// aksiyonları B.4'te (navigasyon + harici harita) eklenir.
class LocationBottomCard extends ConsumerWidget {
  const LocationBottomCard({
    required this.pin,
    required this.onClose,
    this.onOpenDetail,
    this.fit,
    super.key,
  });

  final LocationPin pin;
  final VoidCallback onClose;

  /// "Detay" aksiyonu — verilmezse buton gösterilmez (B.3 uyumu).
  final VoidCallback? onOpenDetail;

  /// Tekne-uyum rozeti (verilirse ve `unknown` değilse gösterilir). Ekran
  /// hesaplar; kart sağlayıcı-bağımsız kalır (testte sarma gerekmez).
  final BoatFit? fit;

  static const ValueKey<String> cardKey = ValueKey<String>('location-bottom-card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final String? priceLabel = pin.priceTier == 'free'
        ? t.freeChip
        : pin.priceTier == 'paid'
            ? t.pricePaid
            : null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        // GENİŞ EKRAN (2026-08): kart bilgisayar/yatay iPad'de uçtan uca
        // yayılmaz; 480px'te sabitlenip ortalanır. Telefonda değişiklik yok.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              key: cardKey,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: DocklyMapColors.forType(pin.type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.typeLabel(pin.type),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    // DOLULUK (kullanıcı kararı 2026-07): bağlama noktası
                    // işaretinin yanında, SALT GÖSTERİM — bildirme yalnız
                    // detay sayfasından yapılır. ConstrainedBox: satırda
                    // sınırsız genişlik almasın (çip içi Flexible güvenli olur).
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: OccupancyChip(
                        idOrSlug: pin.id,
                        initial: pin.occupancy,
                        compact: true,
                      ),
                    ),
                    IconButton(
                      icon: const DocklyIcon(DocklyIcons.close),
                      onPressed: onClose,
                      tooltip: t.closeTooltip,
                    ),
                  ],
                ),
                Text(
                  pin.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const DocklyIcon(DocklyIcons.star, size: 18, color: DocklyColors.warning),
                    const SizedBox(width: 4),
                    Text(pin.ratingAvg != null ? pin.ratingAvg!.toStringAsFixed(1) : t.noRatingShort),
                    if (priceLabel != null) ...<Widget>[
                      const SizedBox(width: 12),
                      _PriceBadge(label: priceLabel),
                    ],
                  ],
                ),
                if (fit != null && fit != BoatFit.unknown) ...<Widget>[
                  const SizedBox(height: 8),
                  BoatFitBadge(fit: fit!),
                ],
                if (onOpenDetail != null) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: DocklyButton(
                      label: t.detailBtn,
                      icon: DocklyIcons.arrowForward,
                      onPressed: onOpenDetail,
                    ),
                  ),
                ],
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: DocklyColors.brandPrimary),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: DocklyColors.brandPrimary),
      ),
    );
  }
}
