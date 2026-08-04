import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../application/nearby_controller.dart';

/// Detay ekranında "Yakındaki alternatifler" bölümü (vizyon: dolu/uygun değilse
/// plan B). Merkez lokasyonun çevresindeki en yakın bağlama noktaları; dokununca
/// onların detayına gider. Boş/hata durumunda sessizce gizlenir.
class NearbyAlternatives extends ConsumerWidget {
  const NearbyAlternatives({required this.locationId, required this.position, super.key});

  final String locationId;
  final GeoPoint position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NearbyKey key = (lat: position.lat, lon: position.lon, excludeId: locationId);
    final AsyncValue<List<LocationSummary>> async = ref.watch(nearbyAlternativesProvider(key));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 20),
        child: SizedBox(
          height: 24,
          width: double.infinity,
          child: Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
      data: (List<LocationSummary> items) {
        if (items.isEmpty) return const SizedBox.shrink();
        // Bölüm kartı (yeniden tasarım 2026-08): koy doluysa plan B hemen elde.
        return SectionCard(
          icon: DocklyIcons.place,
          title: ref.watch(l10nProvider).nearbyAltTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final LocationSummary item in items) _AltTile(item: item),
            ],
          ),
        );
      },
    );
  }
}

class _AltTile extends ConsumerWidget {
  const _AltTile({required this.item});

  final LocationSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: DocklyTypeAvatar(type: item.type),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(ref.watch(l10nProvider).typeLabel(item.type)),
      trailing: Text('${_fmtDistance(item.distanceNm)} dnz mili'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => LocationDetailScreen(idOrSlug: item.id),
        ),
      ),
    );
  }

  static String _fmtDistance(double nm) =>
      nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);
}
