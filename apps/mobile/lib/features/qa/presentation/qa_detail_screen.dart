import 'package:dockly_api/dockly_api.dart' show QaAnswer, QaCreateResult, QaDetail;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../premium/presentation/premium_screen.dart';
import '../../profile/presentation/captain_profile_screen.dart';
import '../application/qa_controller.dart';
import 'qa_list_screen.dart' show QaPremiumBadge;

/// SORU DETAYI (Blog V1 — onaylı görsel konsept Ekran 3-4).
///
/// Erişim kararı SUNUCUDAN gelir: `full` ise gövde + cevaplar + cevap kutusu;
/// `teaser` ise başlık + önizleme + KİLİT KARTI (koy vitrin kilidiyle aynı
/// aile — sahte bulanık içerik ÇİZİLMEZ, kilitli veri istemciye hiç inmez).
class QaDetailScreen extends ConsumerStatefulWidget {
  const QaDetailScreen({required this.questionId, super.key});

  final String questionId;

  @override
  ConsumerState<QaDetailScreen> createState() => _QaDetailScreenState();
}

class _QaDetailScreenState extends ConsumerState<QaDetailScreen> {
  final TextEditingController _answer = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Yazma eylemlerinin ortak hata dili: Premium kapısına takılan (403)
  /// doğruca paket ekranına taşınır; diğer hatalar kibarca söylenir.
  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ForbiddenFailure catch (f) {
      _snack(f.message);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
        );
      }
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendAnswer() async {
    final L10n t = ref.read(l10nProvider);
    final String body = _answer.text.trim();
    if (body.length < 10) {
      _snack(t.qaValAnswer);
      return;
    }
    await _guarded(() async {
      final QaCreateResult res = await ref
          .read(qaGatewayProvider)
          .createAnswer(questionId: widget.questionId, body: body);
      _answer.clear();
      ref.invalidate(qaDetailProvider(widget.questionId));
      _snack(res.pending ? t.qaPendingNote : t.qaPublishedNote);
    });
  }

  Future<void> _toggleLike() => _guarded(() async {
        await ref.read(qaGatewayProvider).toggleLike(widget.questionId);
        ref.invalidate(qaDetailProvider(widget.questionId));
      });

  Future<void> _toggleHelpful(String answerId) => _guarded(() async {
        await ref.read(qaGatewayProvider).toggleHelpful(answerId);
        ref.invalidate(qaDetailProvider(widget.questionId));
      });

  Future<void> _report({required String entity, required String id}) async {
    final L10n t = ref.read(l10nProvider);
    await _guarded(() async {
      await ref.read(qaGatewayProvider).report(entity: entity, id: id);
      _snack(t.qaReported);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<QaDetail> detail =
        ref.watch(qaDetailProvider(widget.questionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.qaRowTitle),
        actions: <Widget>[
          // ⚑ Soru bildirimi — Premium ŞARTI YOK (Apple UGC beklentisi).
          IconButton(
            key: const ValueKey<String>('qa-report-question'),
            onPressed: _busy
                ? null
                : () => _report(entity: 'question', id: widget.questionId),
            icon: const DocklyIcon(DocklyIcons.flag,
                size: 18, color: DocklyColors.text2),
            tooltip: t.qaReport,
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is AppFailure ? e.message : '$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (QaDetail d) => _body(theme, t, d),
      ),
    );
  }

  Widget _body(ThemeData theme, L10n t, QaDetail d) {
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        // SORU KARTI — teaser'da gövde yerine önizleme (sunucu kararı).
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                t.qaCategoryLabel(d.question.category).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: DocklyColors.brandPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4),
              ),
              const SizedBox(height: 4),
              Text(d.question.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                d.full ? (d.body ?? '') : d.question.preview,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (d.question.authorPremium) const QaPremiumBadge(),
                  // KAPTAN KARTI KÖPRÜSÜ (Hafta 1B, kurucu onayı 2026-10-24):
                  // yazar adına dokununca herkese açık profil açılır. Eski
                  // sunucu yanıtında kimlik yoksa ad düz metin kalır.
                  if (d.question.authorId != null)
                    InkWell(
                      key: const ValueKey<String>('qa-author'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => CaptainProfileScreen(
                                userId: d.question.authorId!)),
                      ),
                      child: Text(d.question.authorName,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: DocklyColors.brandPrimary,
                              fontWeight: FontWeight.w800)),
                    )
                  else
                    Text(d.question.authorName,
                        style: theme.textTheme.labelSmall?.copyWith(color: sub)),
                  if (d.full && !d.mine)
                    // Beğeni — kendi soruna görünmez (sunucu da reddeder).
                    TextButton.icon(
                      key: const ValueKey<String>('qa-like'),
                      onPressed: _busy ? null : _toggleLike,
                      icon: DocklyIcon(DocklyIcons.thumbUp,
                          size: 15,
                          color: d.likedByMe
                              ? DocklyColors.brandPrimary
                              : DocklyColors.text2),
                      label: Text('${d.question.likeCount}'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    )
                  else
                    Text('👍 ${d.question.likeCount}',
                        style:
                            theme.textTheme.labelSmall?.copyWith(color: sub)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (!d.full) ...<Widget>[
          _LockCard(
            answersCount: d.answersCount,
            t: t,
            // ERİŞİM REVİZYONU (2026-10-30): teaser yalnız MİSAFİRE/oturumsuza
            // iner — çağrı artık Premium değil, ücretsiz HESAP davetidir.
            onCta: () async {
              await showSignInSheet(context);
              ref.invalidate(qaDetailProvider(widget.questionId));
            },
          ),
        ] else ...<Widget>[
          Text(
            L10n.fmt(t.qaAnswersFmt, '${d.answers.length}').toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: sub, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final QaAnswer a in d.answers)
            _AnswerCard(
              a: a,
              t: t,
              busy: _busy,
              onHelpful: () => _toggleHelpful(a.id),
              onReport: () => _report(entity: 'answer', id: a.id),
            ),
          const SizedBox(height: 8),
          // CEVAP KUTUSU — gönderim sonrası karma moderasyon sonucu dürüstçe
          // söylenir (yayınlandı / denetimde).
          TextField(
            key: const ValueKey<String>('qa-answer-field'),
            controller: _answer,
            enabled: !_busy,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: t.qaAnswerHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey<String>('qa-answer-send'),
            onPressed: _busy ? null : _sendAnswer,
            child: Text(_busy ? t.busyLabel : t.qaSubmitAnswer),
          ),
        ],
      ],
    );
  }
}

/// KİLİT KARTI (erişim revizyonu 2026-10-30): teaser yalnız misafire iner,
/// çağrı ÜCRETSİZ HESAP davetidir — tek çağrı, kendiliğinden pencere açmaz.
class _LockCard extends StatelessWidget {
  const _LockCard({
    required this.answersCount,
    required this.t,
    required this.onCta,
  });

  final int answersCount;
  final L10n t;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>('qa-lock'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.lockOutline,
                  size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.qaLockTitle, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            L10n.fmt(t.qaLockBodyFmt, '$answersCount'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey<String>('qa-lock-cta'),
            onPressed: onCta,
            child: Text(t.accCta),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.a,
    required this.t,
    required this.busy,
    required this.onHelpful,
    required this.onReport,
  });

  final QaAnswer a;
  final L10n t;
  final bool busy;
  final VoidCallback onHelpful;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      // Cevap yazarı da kaptan kartına köprülenir (Hafta 1B).
                      if (a.authorId != null)
                        InkWell(
                          key: ValueKey<String>('qa-answer-author-${a.id}'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => CaptainProfileScreen(
                                    userId: a.authorId!)),
                          ),
                          child: Text(a.authorName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DocklyColors.brandPrimary)),
                        )
                      else
                        Text(a.authorName,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      if (a.authorPremium) const QaPremiumBadge(),
                      if (a.status == 'pending')
                        // Yalnız sahibine görünen dürüst durum çipi.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(t.qaPendingChip,
                              style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF8A6D1A))),
                        ),
                    ],
                  ),
                ),
                if (!a.mine)
                  IconButton(
                    onPressed: busy ? null : onReport,
                    icon: const DocklyIcon(DocklyIcons.flag,
                        size: 15, color: DocklyColors.text2),
                    visualDensity: VisualDensity.compact,
                    tooltip: t.qaReport,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            if (!a.mine && a.status == 'approved')
              OutlinedButton(
                key: ValueKey<String>('qa-helpful-${a.id}'),
                onPressed: busy ? null : onHelpful,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: a.helpedByMe
                      ? DocklyColors.success
                      : DocklyColors.text2,
                ),
                child: Text('✓ ${L10n.fmt(t.qaHelpfulFmt, '${a.helpfulCount}')}'),
              )
            else
              Text('✓ ${L10n.fmt(t.qaHelpfulFmt, '${a.helpfulCount}')}',
                  style: theme.textTheme.labelSmall?.copyWith(color: sub)),
          ],
        ),
      ),
    );
  }
}
