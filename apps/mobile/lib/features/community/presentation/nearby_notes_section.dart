import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../application/community_controller.dart';
import 'note_card.dart';

/// BUGÜN ekranının en altındaki "Yakında paylaşılanlar" kartı.
///
/// Kart, NOT YOKSA HİÇ ÇİZİLMEZ — mevcut hava kartının konum yokken
/// davranışıyla aynı ilke (0-uydurma). Konum yoksa da çizilmez: "yakın"
/// tanımı konumsuz anlamsızdır.
///
/// Okuma ANONİMDİR: misafir de görür, hesap istemez (PRD §5.3).
class NearbyNotesSection extends ConsumerWidget {
  const NearbyNotesSection({required this.position, super.key});

  final GeoPoint position;

  /// Kaç not gösterilir — fazlası için "Tümü" yok: Bugün ekranı bir akış
  /// değildir, günün özetidir.
  static const int maxShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<NearbyNote>> async =
        ref.watch(nearbyNotesProvider(nearbyNotesKeyFor(position.lat, position.lon)));
    // valueOrNull ŞART: hata durumunda .value istisnayı yeniden fırlatır ve
    // ağ yokken bütün Bugün ekranı çökerdi (CI dersi 2026-08).
    final List<NearbyNote> all = async.valueOrNull ?? const <NearbyNote>[];
    if (all.isEmpty) return const SizedBox.shrink();
    final List<NearbyNote> shown = all.take(maxShown).toList(growable: false);

    return SectionCard(
      key: const ValueKey<String>('nearby-notes'),
      icon: DocklyIcons.edit,
      title: t.nearbyNotesTitle,
      accent: const Color(0xFFF59E0B), // Bugün ekranının gün ışığı kimliği
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            t.nearbyNotesLead,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 8),
          for (final NearbyNote n in shown) _NearbyRow(item: n),
        ],
      ),
    );
  }
}

/// Tek satır: tip ikonu + nokta adı + notun ilk satırı + mesafe/zaman.
/// Tam kart (oy düğmeleriyle) BURADA çizilmez — Bugün ekranı bir eylem
/// yüzeyi değildir; dokununca koy detayına gidilir.
class _NearbyRow extends ConsumerWidget {
  const _NearbyRow({required this.item});

  final NearbyNote item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final Note n = item.note;
    final Color tint = noteKindColor(context, n.kind);
    return Padding(
      key: ValueKey<String>('nearby-${n.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DocklyIcon(noteKindIcon(n.kind), size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.locationName ?? t.noteKindLabel(n.kind.wire),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    if (n.author.displayName.isNotEmpty) n.author.displayName,
                    relativeTime(t, n.createdAt),
                    L10n.fmt(t.nearbyDistanceFmt, _fmtNm(item.distanceNm)),
                  ].join(' · '),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtNm(double nm) =>
      nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);
}

/// ISO zaman damgasını "az önce / 12 dk önce / 6 sa önce / 3 gün önce"ye
/// çevirir. Ayrıştırılamayan değerde BOŞ döner — ekran çökmez, satır kısalır.
String relativeTime(L10n t, String iso, {DateTime? now}) {
  final DateTime? d = DateTime.tryParse(iso);
  if (d == null) return '';
  final DateTime ref = now ?? DateTime.now();
  final int minutes = ref.difference(d.toLocal()).inMinutes;
  if (minutes < 1) return t.agoJustNow;
  if (minutes < 60) return L10n.fmt(t.agoMinFmt, '$minutes');
  final int hours = minutes ~/ 60;
  if (hours < 48) return L10n.fmt(t.agoHourFmt, '$hours');
  return L10n.fmt(t.agoDayFmt, '${hours ~/ 24}');
}
