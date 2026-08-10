import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/reputation_controller.dart';

/// Kuyruk şeridindeki türler. `null` = tümü.
const List<String?> kModerationTabs = <String?>[
  null,
  'note',
  'review',
  'media',
  'suggested_location',
  'location_report',
];

/// MODERASYON ekranı — Profil'den açılır, YALNIZ `moderator` rolüne görünür.
///
/// Ayrı bir web paneli yoktur: moderasyon telefondan yapılır (tasarım §9.2).
/// Sunucu ayrıca `@MinRole('moderator')` ile korur; buradaki gizleme yalnız
/// görünürlüktür, güvenlik sınırı DEĞİLDİR.
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  String? _entityType;

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ModerationItem>> async =
        ref.watch(moderationQueueProvider(_entityType));
    final Map<String, int> counts =
        ref.watch(moderationCountsProvider).valueOrNull ?? const <String, int>{};
    final Set<String> handled = ref.watch(moderationHandledProvider);
    // Karar verilen kart listede kalmaz: sunucu tazelemesini beklemeden düşer.
    final List<ModerationItem> items = (async.valueOrNull ?? const <ModerationItem>[])
        .where((ModerationItem i) => !handled.contains(i.taskId))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(t.navModeration)),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: <Widget>[
                for (final String? code in kModerationTabs) ...<Widget>[
                  _Seg(
                    label: code == null ? t.modAll : t.moderationEntityLabel(code),
                    // "Tümü" çipi TOPLAMI gösterir (Profil satırındaki sayıyla
                    // aynı hesap): iki yüzeyde farklı sayı görünmesin.
                    count: code == null
                        ? counts.values.fold<int>(0, (int a, int b) => a + b)
                        : (counts[code] ?? 0),
                    selected: _entityType == code,
                    onTap: () => setState(() => _entityType = code),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: async.isLoading && items.isEmpty
                ? const Center(
                    child: SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            t.modEmpty,
                            key: const ValueKey<String>('moderation-empty'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
                        children: <Widget>[
                          for (final ModerationItem i in items) ModerationCard(item: i),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// Tek moderasyon kartı: içerik + yazar bağlamı + Onayla/Reddet.
/// Testlerde doğrudan bulunabilsin diye public.
class ModerationCard extends ConsumerStatefulWidget {
  const ModerationCard({required this.item, super.key});

  final ModerationItem item;

  @override
  ConsumerState<ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends ConsumerState<ModerationCard> {
  bool _busy = false;

  Future<void> _decide(bool approve, {String? reason}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final L10n t = ref.read(l10nProvider);
    // Sayfa değişmese de mesajlaştırıcı ÖNCEDEN yakalanır: await sonrası
    // context ölmüş olabilir (CI dersi 2026-08).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reputationGatewayProvider).decide(
            taskId: widget.item.taskId,
            approve: approve,
            reason: reason,
          );
      // Karar SUNUCUDA geçerli oldu: bilgi her hâlükârda gösterilir.
      // Mesajlaştırıcı await'ten ÖNCE yakalandığı için sayfa kapanmış olsa
      // bile çalışır.
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(approve ? t.modApproved : t.modRejected)));
      // Sağlayıcıya yalnız ekran hâlâ ayaktayken dokunulur: kapanmış bir
      // ConsumerState'te `ref` okumak istisna fırlatır.
      if (!mounted) return;
      ref.read(moderationHandledProvider.notifier).markHandled(widget.item.taskId);
      ref.invalidate(moderationCountsProvider);
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(_message(error, t))));
    }
  }

  /// Ham istisna metni ASLA arayüze sızmaz: sunucunun yerelleştirilmiş
  /// `message` alanı kullanılır.
  String _message(Object error, L10n t) {
    if (error is AppFailure) return error.message;
    return t.actionFailed;
  }

  Future<void> _askReason() async {
    final L10n t = ref.read(l10nProvider);
    // isScrollControlled + kaydırma ŞART (CI dersi 2026-08): 7 sebep satırı
    // varsayılan yüksekliğe (ekranın 9/16'sı) sığmaz ve RenderFlex taşar.
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  t.modReasonTitle,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final String code in kRejectReasons)
                ListTile(
                  key: ValueKey<String>('reason-$code'),
                  title: Text(t.rejectReasonLabel(code)),
                  onTap: () => Navigator.of(ctx).pop(code),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    // Sebepsiz red sunucuda 422 verir — sayfa kapatılırsa hiç gönderilmez.
    if (reason != null) await _decide(false, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final ModerationItem i = widget.item;
    final bool hazard = i.kind == 'hazard';
    final int? rate = i.approvalRate;

    return Container(
      key: ValueKey<String>('mod-${i.taskId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: hazard ? DocklyColors.error.withValues(alpha: 0.06) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hazard
              ? DocklyColors.error.withValues(alpha: 0.45)
              : theme.colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DocklyIcon(
                hazard ? DocklyIcons.errorOutline : DocklyIcons.flag,
                size: 16,
                color: hazard ? DocklyColors.error : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                i.kind != null && i.entityType == 'note'
                    ? t.noteKindLabel(i.kind!)
                    : t.moderationEntityLabel(i.entityType),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hazard ? DocklyColors.error : theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (i.gpsVerified == true)
                Text(
                  t.modGpsVerified,
                  style: theme.textTheme.labelSmall?.copyWith(color: DocklyColors.success),
                ),
            ],
          ),
          if (i.locationName != null && i.locationName!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              i.locationName!,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          if (i.body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(i.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text(
            <String>[
              if (i.authorName.isNotEmpty) i.authorName,
              t.levelLabel(i.authorLevelCode),
              if (rate != null) L10n.fmt(t.modApprovalRateFmt, '$rate'),
              if (i.observedOn != null) i.observedOn!,
            ].join(' · '),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  key: ValueKey<String>('mod-approve-${i.taskId}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DocklyColors.success,
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: _busy ? null : () => _decide(true),
                  child: Text(t.modApprove),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey<String>('mod-reject-${i.taskId}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DocklyColors.error,
                    minimumSize: const Size(0, 42),
                    side: BorderSide(color: DocklyColors.error.withValues(alpha: 0.5)),
                  ),
                  onPressed: _busy ? null : _askReason,
                  child: Text(t.modReject),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
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
            count > 0 ? '$label $count' : label,
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
