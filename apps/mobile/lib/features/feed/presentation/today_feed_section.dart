import 'package:dockly_api/dockly_api.dart' show FeedItem;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/feed_controller.dart';
import 'feed_cards.dart';
import 'feed_screen.dart';

/// Bugün'deki TOPLULUK AKIŞI bölümü (SP-3b, kurucu onayı 2026-10-31).
///
/// İlk birkaç kart + "Tümünü gör" köprüsü. Misafirde, yüklenirken, hatada
/// ve boş akışta KENDİNİ HİÇ ÇİZMEZ (0-uydurma; Bugün düzeni bozulmaz) —
/// topluluğun kapısı zaten topluluk şerididir.
class TodayFeedSection extends ConsumerWidget {
  const TodayFeedSection({super.key});

  /// Bugün'de gösterilen en çok kart sayısı — tamamı FeedScreen'de.
  static const int previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<FeedItem> items = ref.watch(feedProvider).maybeWhen(
          data: (List<FeedItem> list) => list,
          orElse: () => const <FeedItem>[],
        );
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 16, left: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  // Büyük harf l10n'de saklanmaz; başlık tek kelimelik
                  // marka değil, çeviri — İ/I tuzağı yok (ASCII değilse
                  // zaten locale'e göre yazıldı).
                  t.fdTitle.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('today-feed-all'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor:
                      DocklyColors.brandPrimary.withValues(alpha: 0.08),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const FeedScreen()),
                ),
                child: Text('${t.tdCommunityAll} ›'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final FeedItem item in items.take(previewCount))
          FeedItemCard(item: item),
      ],
    );
  }
}
