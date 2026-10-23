import 'package:dockly_api/dockly_api.dart' show QaFeed, QaQuestionSummary, kQaCategories;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/qa_controller.dart';
import 'qa_composer_screen.dart';
import 'qa_detail_screen.dart';

/// SORU-CEVAP ana akışı (Blog V1 — onaylı görsel konsept Ekran 1-2).
///
/// HERKESE açıktır (misafir dâhil): başlıklar + önizlemeler vitrin görevi
/// görür. "Öne çıkan" şeridi, onayından sonraki 24 saatte olan soruları
/// altın çerçeveyle üstte taşır (adalet kararı A — en çok 3, akışta tekrar yok).
/// Detaya dokunuş erişim kararını SUNUCUYA sorar; kilit kararı burada verilmez.
class QaListScreen extends ConsumerStatefulWidget {
  const QaListScreen({super.key});

  @override
  ConsumerState<QaListScreen> createState() => _QaListScreenState();
}

class _QaListScreenState extends ConsumerState<QaListScreen> {
  /// null = tüm kategoriler.
  String? _category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<QaFeed> feed = ref.watch(qaFeedProvider(_category));

    return Scaffold(
      appBar: AppBar(title: Text(t.qaRowTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('qa-ask-fab'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const QaComposerScreen()),
        ),
        icon: const DocklyIcon(DocklyIcons.edit, size: 18, color: Colors.white),
        label: Text(t.qaAskCta),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(qaFeedProvider(_category)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: <Widget>[
            Text(
              t.qaLead,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            // Kategori çipleri — haritadaki filtre çipleriyle aynı davranış.
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  _CategoryChip(
                    label: t.qaCatAll,
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final String code in kQaCategories)
                    _CategoryChip(
                      label: t.qaCategoryLabel(code),
                      selected: _category == code,
                      onTap: () => setState(() => _category = code),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            feed.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => _ErrorBox(
                message: e is AppFailure ? e.message : '$e',
                onRetry: () => ref.invalidate(qaFeedProvider(_category)),
              ),
              data: (QaFeed f) => _FeedBody(feed: f, t: t),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.feed, required this.t});

  final QaFeed feed;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (feed.featured.isEmpty && feed.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: <Widget>[
            const DocklyIcon(DocklyIcons.chat, size: 40, color: DocklyColors.text2),
            const SizedBox(height: 10),
            Text(
              t.qaEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    TextStyle? cap(Color c) =>
        theme.textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w800);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (feed.featured.isNotEmpty) ...<Widget>[
          Text('⭑ ${t.qaFeaturedCap}', style: cap(const Color(0xFFB8860B))),
          const SizedBox(height: 6),
          for (final QaQuestionSummary q in feed.featured)
            _QuestionCard(q: q, t: t, featured: true),
          const SizedBox(height: 10),
          Text(t.qaLatestCap, style: cap(DocklyColors.text2)),
          const SizedBox(height: 6),
        ],
        for (final QaQuestionSummary q in feed.items) _QuestionCard(q: q, t: t),
      ],
    );
  }
}

/// Altın "⭑ PREMIUM" rozeti — yazarın GÜNCEL premium durumunu söyler.
class QaPremiumBadge extends StatelessWidget {
  const QaPremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8D49A)),
      ),
      child: const Text(
        '⭑ PREMIUM',
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFB8860B)),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.q, required this.t, this.featured = false});

  final QaQuestionSummary q;
  final L10n t;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey<String>('qa-item-${q.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => QaDetailScreen(questionId: q.id)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: featured
                    ? const Color(0xFFE2C367)
                    : theme.dividerColor.withValues(alpha: 0.4),
                width: featured ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  t.qaCategoryLabel(q.category).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: DocklyColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4),
                ),
                const SizedBox(height: 3),
                Text(q.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  q.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: sub),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (q.authorPremium) const QaPremiumBadge(),
                    Text(q.authorName,
                        style: theme.textTheme.labelSmall?.copyWith(color: sub)),
                    Text('💬 ${L10n.fmt(t.qaAnswersFmt, '${q.answersCount}')}',
                        style: theme.textTheme.labelSmall?.copyWith(color: sub)),
                    Text('👍 ${q.likeCount}',
                        style: theme.textTheme.labelSmall?.copyWith(color: sub)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        selectedColor: DocklyColors.brandPrimary,
        showCheckmark: false,
      ),
    );
  }
}

class _ErrorBox extends ConsumerWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: <Widget>[
          Text(message,
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: Text(t.retryLabel)),
        ],
      ),
    );
  }
}
