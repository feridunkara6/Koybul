import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/reputation_controller.dart';
import 'note_card.dart';
import 'reputation_shell.dart';

/// "Katkılarım" ekranı — Profil'deki katkı bloğundan açılır.
///
/// Üç durum ayrı ayrı görünür: YAYINDA (kabul edilenler), İNCELEMEDE (ne
/// zaman sonuçlanacağı yazar) ve REDDEDİLEN (SEBEBİ yazar). Reddi sebepsiz
/// göstermek kaptanı öğrenmeden uzaklaştırırdı (tasarım §9.3).
class MyContributionsScreen extends ConsumerStatefulWidget {
  const MyContributionsScreen({this.initialStatus = 'approved', super.key});

  /// 'approved' | 'pending' | 'rejected' — Profil'deki hangi satıra
  /// dokunulduysa o sekme açılır.
  final String initialStatus;

  @override
  ConsumerState<MyContributionsScreen> createState() => _MyContributionsScreenState();
}

class _MyContributionsScreenState extends ConsumerState<MyContributionsScreen> {
  late String _status = widget.initialStatus;

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Note>> async = ref.watch(myNotesProvider(_status));
    final List<Note> notes = async.valueOrNull ?? const <Note>[];
    final AsyncValue<ReputationSummary> summary = ref.watch(reputationSummaryProvider);
    final ReputationSummary s = summary.valueOrNull ?? ReputationSummary.empty;
    // Sayaçlar özetten, liste kendi isteğinden gelir: biri düşerse ÖTEKİ
    // gizlenmez. Sayaç okunamadıysa rakam yerine "—" yazılır — sayısız etiket
    // "sıfır katkı" gibi okunuyordu (inceleme bulgusu 2026-08).
    final bool summaryFailed = summary.valueOrNull == null && summary.hasError;
    final bool listFailed = async.valueOrNull == null && async.hasError;

    return Scaffold(
      appBar: AppBar(title: Text(t.contribTitle)),
      body: Column(
        children: <Widget>[
          // Segment şeridi YATAY KAYDIRILABİLİR (CI dersi 2026-08: üç çip dar
          // telefonda taşıyordu). Sayılar özetten gelir, listeden değil —
          // liste yalnız seçili durumu yükler.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: <Widget>[
                _Seg(
                  t: t,
                  label: t.contribTabPublished,
                  count: summaryFailed ? null : s.approvedCount,
                  selected: _status == 'approved',
                  onTap: () => setState(() => _status = 'approved'),
                ),
                const SizedBox(width: 8),
                _Seg(
                  t: t,
                  label: t.contribTabPending,
                  count: summaryFailed ? null : s.pendingCount,
                  selected: _status == 'pending',
                  onTap: () => setState(() => _status = 'pending'),
                ),
                const SizedBox(width: 8),
                _Seg(
                  t: t,
                  label: t.contribTabRejected,
                  count: summaryFailed ? null : s.rejectedCount,
                  selected: _status == 'rejected',
                  onTap: () => setState(() => _status = 'rejected'),
                ),
              ],
            ),
          ),
          Expanded(
            child: listFailed
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ReputationErrorBox(
                      isRetrying: async.isLoading || summary.isLoading,
                      onRetry: () {
                        ref.invalidate(myNotesProvider(_status));
                        if (summaryFailed) ref.invalidate(reputationSummaryProvider);
                      },
                    ),
                  )
                : async.isLoading && notes.isEmpty
                ? const Center(child: ReputationLoadingBox())
                : notes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            t.contribEmpty,
                            key: const ValueKey<String>('contrib-empty'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
                        children: <Widget>[
                          if (_status == 'pending')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                t.contribPendingHint,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          for (final Note n in notes)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Kendi katkısına oy verilemez: eylem düğmeleri
                                // burada HİÇ çizilmez (403 almasın diye).
                                NoteCard(
                                  note: n,
                                  locationId: n.locationId ?? '',
                                  showActions: false,
                                ),
                                if (n.helpfulCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                                    child: Text(
                                      L10n.fmt(
                                          t.contribHelpfulFmt, formatCount(t, n.helpfulCount)),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: DocklyColors.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// Durum çipi: etiket + sayı rozeti (Defter segmentiyle aynı görsel dil).
class _Seg extends StatelessWidget {
  const _Seg({
    required this.t,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final L10n t;
  final String label;

  /// null = sayı OKUNAMADI (etiketin yanında "—" çıkar); 0 = gerçekten sıfır.
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: selected ? DocklyColors.brandPrimary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? DocklyColors.brandPrimary : theme.colorScheme.outline,
            ),
          ),
          child: Text(
            count == null
                ? '$label —'
                : (count! > 0 ? '$label ${formatCount(t, count!)}' : label),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
