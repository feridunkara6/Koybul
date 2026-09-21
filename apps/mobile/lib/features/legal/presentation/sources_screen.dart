import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../data/photo_credits.dart';

/// KAYNAKLAR VE LİSANSLAR (FAZ 0 K4, kurucu onayı 2026-09).
///
/// Denetim bulgusu 🔴2: atıflar uygulamada TEK TEK vardı (kapak şeridi,
/// harita köşesi, hava kartı) ama merkezi bir vitrin yoktu. CC BY / CC BY-SA
/// lisansları görünür atıf şart koşar; mağaza incelemesi ve lisans sahipleri
/// "bütün atıflar nerede?" diye TEK yere bakabilmeli. Bu ekran o yerdir.
///
/// İçerik uygulamanın İÇİNDEDİR ve çevrimdışı okunur (yasal ekranla aynı
/// ilke). Fotoğraf listesi elle yazılmaz: photo_credits.dart, atıf veri
/// dosyasından üretilir — tek doğruluk kaynağı JSON'dur.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.srcTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          Text(
            t.srcLead,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            icon: DocklyIcons.mapOutlined,
            title: t.srcMapTitle,
            body: t.srcMapBody,
          ),
          const SizedBox(height: 10),
          _SectionCard(
            icon: DocklyIcons.explore,
            title: t.srcWeatherTitle,
            body: t.srcWeatherBody,
          ),
          const SizedBox(height: 10),
          _SectionCard(
            icon: DocklyIcons.verified,
            title: t.srcDataTitle,
            body: t.srcDataBody,
          ),
          const SizedBox(height: 24),
          Text(t.srcPhotosTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            L10n.fmt(t.srcPhotosLeadFmt, '${kPhotoCredits.length}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (final PhotoCredit c in kPhotoCredits) _CreditRow(credit: c),
        ],
      ),
    );
  }
}

/// Harita/hava/veri kaynağı kartı: ikon + başlık + açıklama.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.body});

  final DocklyIconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DocklyIcon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek fotoğraf atfı: yer adı + "atıf · lisans"; kaynak sayfası varsa dokunuş
/// onu açar (CC atfı kaynağa bağlantı bekler — kapak şeridiyle aynı kural).
class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final PhotoCredit credit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String meta = credit.license.isEmpty
        ? credit.credit
        : '${credit.credit} · ${credit.license}';
    final bool linked = credit.sourceUrl.startsWith('https://');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: !linked
          ? null
          : () async {
              // Açılamazsa sessiz kal: atıf metni zaten ekranda (kapak
              // şeridindeki davranışla birebir aynı gerekçe).
              try {
                await launchUrl(Uri.parse(credit.sourceUrl),
                    mode: LaunchMode.externalApplication);
              } catch (_) {/* bağlantı açılamadı — atıf görünür kalır */}
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(credit.place,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35)),
                ],
              ),
            ),
            if (linked) ...<Widget>[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: DocklyIcon(DocklyIcons.openInNew,
                    size: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
