import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_gate.dart';
import '../application/community_controller.dart';

/// Not tipinin rengi. UYARI her zaman kırmızı: emniyet dili tip kimlik rengine
/// BOYANMAZ (mevcut rüzgâr uyarı bandıyla aynı ilke).
Color noteKindColor(BuildContext context, NoteKind kind) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return switch (kind) {
    NoteKind.hazard => DocklyColors.error,
    NoteKind.status => DocklyColors.warning,
    NoteKind.passage => DocklyColors.accentTurquoise,
    NoteKind.experience => cs.primary,
  };
}

DocklyIconData noteKindIcon(NoteKind kind) => switch (kind) {
      NoteKind.hazard => DocklyIcons.errorOutline,
      NoteKind.status => DocklyIcons.infoOutline,
      NoteKind.passage => DocklyIcons.navigation,
      NoteKind.experience => DocklyIcons.sailing,
    };

/// Tek bir Kaptan Notu. Yazarın seviyesi bir ETİKETTİR — sıralamayı etkilemez
/// (tasarım §8.4: "yüksek puan = haklı" tuzağından kaçınma).
class NoteCard extends ConsumerWidget {
  const NoteCard({
    required this.note,
    required this.locationId,
    this.showActions = true,
    super.key,
  });

  final Note note;
  final String locationId;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final Color kindColor = noteKindColor(context, note.kind);
    final bool hazard = note.kind == NoteKind.hazard;
    // Kendi oyunu VEREN kullanıcı sonucu hemen görmeli: sunucu GET'i
    // önbellekli olabilir, sayaç yaması listeden bağımsız okunur.
    final NoteCounts? patch = ref.watch(noteCountersProvider)[note.id];
    final int helpful = patch?.helpfulCount ?? note.helpfulCount;
    final int confirms = patch?.confirmCount ?? note.confirmCount;

    return Container(
      key: ValueKey<String>('note-${note.id}'),
      margin: const EdgeInsets.only(bottom: 8),
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
              DocklyIcon(noteKindIcon(note.kind), size: 16, color: kindColor),
              const SizedBox(width: 6),
              Text(
                t.noteKindLabel(note.kind.wire),
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: kindColor),
              ),
              const Spacer(),
              Text(
                note.observedOn,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (note.title != null && note.title!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(note.title!, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 4),
          Text(note.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          // O günkü hava sunucuda DONDURULMUŞTUR: okuyan kaptan kendi
          // koşuluyla karşılaştırabilsin diye notun ayrılmaz parçası.
          if (note.wind != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              L10n.fmt(t.noteRecordedWindFmt, '${note.wind!.kn} kn ${note.wind!.dirTr}'),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 6),
          _AuthorLine(note: note),
          if (confirms > 0) ...<Widget>[
            const SizedBox(height: 5),
            _Pill(
              text: L10n.fmt(t.noteConfirmedFmt, '$confirms'),
              color: DocklyColors.success,
            ),
          ],
          if (showActions) ...<Widget>[
            const SizedBox(height: 6),
            _Actions(note: note, hazard: hazard, helpfulCount: helpful),
          ],
        ],
      ),
    );
  }
}

class _AuthorLine extends ConsumerWidget {
  const _AuthorLine({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            note.author.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 6),
        _Pill(text: t.levelLabel(note.author.levelCode), color: DocklyColors.accentTurquoise),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.note, required this.hazard, required this.helpfulCount});

  final Note note;
  final bool hazard;
  final int helpfulCount;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  Future<void> _react(String reaction) async {
    final L10n t = ref.read(l10nProvider);
    await requireAccount(
      context,
      ref,
      message: t.gateNoteMsg,
      onAllowed: () => _send(reaction),
    );
  }

  void _send(String reaction) {
    if (_busy) return;
    setState(() => _busy = true);
    ref.read(communityGatewayProvider).react(widget.note.id, reaction).then(
        (NoteCounts counts) {
      if (!mounted) return;
      ref.read(noteCountersProvider.notifier).apply(widget.note.id, counts);
      setState(() => _busy = false);
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final L10n t = ref.read(l10nProvider);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(_message(error, t))));
    });
  }

  /// Ham istisna metni ASLA arayüze sızmaz (docs/26 §13): sunucunun
  /// yerelleştirilmiş `message` alanı kullanılır.
  String _message(Object error, L10n t) {
    if (error is ForbiddenFailure) return t.noteOwnVote;
    if (error is AppFailure) return error.message;
    return t.noteOwnVote;
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        _SmallButton(
          key: ValueKey<String>('note-helpful-${widget.note.id}'),
          label: widget.helpfulCount > 0
              ? '${t.noteHelpful} · ${widget.helpfulCount}'
              : t.noteHelpful,
          color: DocklyColors.success,
          onTap: _busy ? null : () => _react('helpful'),
        ),
        // Doğrulama/çelişki YALNIZ uyarılarda anlamlı: emniyet bilgisinin
        // hâlâ geçerli olup olmadığını topluluk söyler.
        if (widget.hazard) ...<Widget>[
          _SmallButton(
            key: ValueKey<String>('note-confirm-${widget.note.id}'),
            label: t.noteConfirm,
            color: DocklyColors.success,
            onTap: _busy ? null : () => _react('confirm'),
          ),
          _SmallButton(
            key: ValueKey<String>('note-dispute-${widget.note.id}'),
            label: t.noteDispute,
            color: theme.colorScheme.onSurfaceVariant,
            onTap: _busy ? null : () => _react('dispute'),
          ),
        ],
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.color, this.onTap, super.key});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}
