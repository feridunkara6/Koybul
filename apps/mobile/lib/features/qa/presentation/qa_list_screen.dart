import 'dart:async' show Timer;

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

  /// ARAMA (kurucu isteği 2026-10-30): konu/anahtar kelime → başlık+gövde.
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  /// SAYFALI DÜZEN (kurucu isteği 2026-10-30): 1 tabanlı sayfa.
  int _page = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Yazarken 400 ms beklenir — her tuşta ağa gidilmez; süzgeç değişince
  /// sayfa 1'e döner (yeni sorgu, yeni sayfalama).
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _page = 1;
      });
    });
  }

  QaFeedKey get _key => (category: _category, query: _query, page: _page);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<QaFeed> feed = ref.watch(qaFeedProvider(_key));

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
        onRefresh: () async => ref.invalidate(qaFeedProvider(_key)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: <Widget>[
            Text(
              t.qaLead,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            // ARAMA KUTUSU (kurucu isteği 2026-10-30): konu başlığı ya da
            // anahtar kelime — başlık ve gövdede geçen sorular listelenir.
            TextField(
              key: const ValueKey<String>('qa-search'),
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.qaSearchHint,
                isDense: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(10),
                  child: DocklyIcon(DocklyIcons.search, size: 18),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 38, minHeight: 38),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey<String>('qa-search-clear'),
                        visualDensity: VisualDensity.compact,
                        icon: const DocklyIcon(DocklyIcons.close, size: 16),
                        onPressed: () {
                          _debounce?.cancel();
                          _search.clear();
                          setState(() {
                            _query = '';
                            _page = 1;
                          });
                        },
                      ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                    onTap: () => setState(() {
                      _category = null;
                      _page = 1; // süzgeç değişti → sayfalama başa döner
                    }),
                  ),
                  for (final String code in kQaCategories)
                    _CategoryChip(
                      label: t.qaCategoryLabel(code),
                      selected: _category == code,
                      onTap: () => setState(() {
                        _category = code;
                        _page = 1;
                      }),
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
                onRetry: () => ref.invalidate(qaFeedProvider(_key)),
              ),
              data: (QaFeed f) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FeedBody(feed: f, t: t),
                  // SAYFA SEÇİCİ (2026-10-30): ‹ Sayfa X / Y › — tek sayfada
                  // hiç çizilmez (gürültü olmasın).
                  if (f.pageCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          OutlinedButton(
                            key: const ValueKey<String>('qa-page-prev'),
                            onPressed: _page > 1
                                ? () => setState(() => _page -= 1)
                                : null,
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(44, 38),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12)),
                            child: const Text('‹'),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              L10n.fmt2(
                                  t.qaPageFmt2, '$_page', '${f.pageCount}'),
                              key: const ValueKey<String>('qa-page-label'),
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          OutlinedButton(
                            key: const ValueKey<String>('qa-page-next'),
                            onPressed: _page < f.pageCount
                                ? () => setState(() => _page += 1)
                                : null,
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(44, 38),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12)),
                            child: const Text('›'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
