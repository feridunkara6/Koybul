import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';

/// Detayda çalışma saatleri + sezon bölümü (docs/23 §11.3). Veri yoksa gizlenir.
///
/// NOT: `day_of_week` 0–6 (docs/22). Standart Postgres/JS düzeni varsayıldı:
/// 0 = Pazar … 6 = Cumartesi. Veri farklı bir düzen kullanıyorsa `t.dayNames`
/// dizini tek satırda güncellenir (l10n_strings.dart, dört dilde).
class OperatingInfo extends ConsumerWidget {
  const OperatingInfo({
    required this.hours,
    required this.seasons,
    required this.is24h,
    this.accent,
    super.key,
  });

  final List<Hour> hours;
  final List<Season> seasons;
  final bool is24h;

  /// Tip kimlik rengi (2026-08) — başlık madalyonu.
  final Color? accent;

  // Hafta görünümü: Pazartesi → Pazar sırası (denizci takvimi).
  static const List<int> _weekOrder = <int>[1, 2, 3, 4, 5, 6, 0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final bool hasHours = is24h || hours.isNotEmpty;
    final List<Widget> children = <Widget>[];

    if (is24h) {
      children.add(_Row(label: t.everyDay, value: t.open24));
    } else if (hours.isNotEmpty) {
      for (final int dow in _weekOrder) {
        final List<Hour> dayHours = hours.where((Hour h) => h.dayOfWeek == dow).toList();
        if (dayHours.isEmpty) continue;
        final String open = dayHours
            .where((Hour h) => h.opensAt != null && h.closesAt != null)
            .map((Hour h) => '${h.opensAt}–${h.closesAt}')
            .join(', ');
        children.add(_Row(label: t.dayNames[dow], value: open.isEmpty ? t.closedLabel : open));
      }
    }

    if (seasons.isNotEmpty) {
      // Saatler de varsa sezon kendi ara başlığını taşır; yalnız sezon varsa
      // kartın başlığı zaten sezon olur (aşağıda) — ikinci başlık gerekmez.
      if (hasHours) children.add(_title(theme, t.seasonTitle));
      for (final Season s in seasons) {
        children.add(_Row(
            label: t.openLabel,
            value: '${_fmtMonthDay(t, s.opensOn)} – ${_fmtMonthDay(t, s.closesOn)}'));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    // Bölüm kartı (yeniden tasarım 2026-08): ikonlu başlık + satırlar.
    return SectionCard(
      accent: accent,
      icon: DocklyIcons.amClock,
      title: hasHours ? t.opHoursTitle : t.seasonTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _title(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: theme.textTheme.titleMedium),
      );

  static String _fmtMonthDay(L10n t, String? mmdd) {
    if (mmdd == null) return '?';
    final List<String> parts = mmdd.split('-');
    if (parts.length != 2) return mmdd;
    final int? m = int.tryParse(parts[0]);
    final int? d = int.tryParse(parts[1]);
    if (m == null || d == null || m < 1 || m > 12) return mmdd;
    return '$d ${t.monthAbbr[m]}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
