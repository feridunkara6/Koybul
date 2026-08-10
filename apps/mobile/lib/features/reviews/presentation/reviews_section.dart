import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../../community/presentation/review_composer_screen.dart';
import '../application/reviews_controller.dart';

/// Detay ekranında "Yorumlar" bölümü (S-09). Onaylı yorumları okuma — misafir
/// dostu (yazma üyelik ister, sonraki faz). UX kararı (2026-08): BOŞ durumda
/// gizlenmek yerine tek satırlık dost mesaj gösterilir — kullanıcı "yorum yok
/// mu, yüklenemedi mi?" belirsizliği yaşamaz. Hata durumunda bölüm gizli kalır
/// (misafiri teknik hatayla rahatsız etmeme kararı korunur).
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({
    required this.idOrSlug,
    this.locationName = '',
    this.accent,
    super.key,
  });

  final String idOrSlug;

  /// Yorum yazma ekranında başlık olarak gösterilir.
  final String locationName;

  /// Tip kimlik rengi (2026-08) — başlık madalyonu.
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Review>> async = ref.watch(reviewsProvider(idOrSlug));
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
      data: (List<Review> items) {
        final ThemeData theme = Theme.of(context);
        final L10n t = ref.watch(l10nProvider);
        // Bölüm kartı (yeniden tasarım 2026-08): ikonlu başlık + içerik.
        return SectionCard(
          accent: accent,
          icon: DocklyIcons.chat,
          title: t.reviewsTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (items.isEmpty)
                Text(
                  t.revEmpty,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                for (final Review r in items) _ReviewCard(review: r),
              // YORUM YAZMA (2026-08): bölüm artık yalnız okuma değil.
              // Üyelik kapısı eylem anında çıkar, gezinmeyi engellemez.
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('review-write'),
                  onPressed: () => openReviewComposer(
                    context,
                    ref,
                    idOrSlug: idOrSlug,
                    locationName: locationName,
                  ),
                  icon: const DocklyIcon(DocklyIcons.edit, size: 18),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: Text(t.reviewWriteCta),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Stars(rating: review.rating),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.authorName,
                  style: theme.textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _fmtDate(review.createdAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (review.title != null && review.title!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(review.title!, style: theme.textTheme.titleSmall),
          ],
          if (review.body != null && review.body!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(review.body!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 5; i++)
          DocklyIcon(
            i <= rating ? DocklyIcons.star : DocklyIcons.starBorder,
            size: 16,
            color: DocklyColors.warning,
          ),
      ],
    );
  }
}

/// ISO tarihi "gg.aa.yyyy" biçimine getirir; ayrıştırılamazsa tarih kısmını verir.
String _fmtDate(String iso) {
  final DateTime? d = DateTime.tryParse(iso);
  if (d == null) return iso.split('T').first;
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}
