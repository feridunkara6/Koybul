import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../application/deria_controller.dart';

/// DERİA TONOZ DOLULUK KUTUSU (kurucu kararı 2026-08).
///
/// Göcek'teki TÜÇA şamandıra sahalarında "bu gece kaç tonoz boş" gösterir.
/// Üç dürüstlük kuralı:
/// · Veri yoksa / kayıt eşlenmemişse / veri bayatsa kutu HİÇ ÇİZİLMEZ —
///   denizde bayat "boş" bilgisi, hiç bilgi olmamasından tehlikelidir.
/// · Kaynak her zaman görünür: "Kaynak: DERİA (Türkiye Çevre Ajansı)".
/// · Rezervasyon BİZDE YAPILMAZ; düğme deria.gov.tr'yi açar.
class DeriaAvailabilityBox extends ConsumerWidget {
  const DeriaAvailabilityBox({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeriaAvailability? a =
        ref.watch(deriaAvailabilityProvider).valueOrNull;
    final DeriaCove? cove = deriaCoveFor(a, slug, DateTime.now());
    if (cove == null) return const SizedBox.shrink();

    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final bool anyFree = cove.free > 0;
    final Color stateColor =
        anyFree ? const Color(0xFF0CA30C) : const Color(0xFFD03B3B);

    return SectionCard(
      icon: DocklyIcons.amMooring,
      title: t.deriaTitle,
      accent: stateColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            key: const ValueKey<String>('deria-box'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${cove.free}',
                key: const ValueKey<String>('deria-free'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  L10n.fmt(t.deriaFreeOfTotal, '${cove.total}'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.deriaSourceNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('deria-reserve'),
              icon: const DocklyIcon(DocklyIcons.openInNew, size: 15),
              label: Text(t.deriaReserveBtn),
              onPressed: () async {
                // Açılamazsa sessiz: kutu bilgilendirme amaçlı, sayfa kırılmaz.
                try {
                  await launchUrl(
                    Uri.parse('https://deria.gov.tr'),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {/* bağlantı açılamadı */}
              },
            ),
          ),
        ],
      ),
    );
  }
}
