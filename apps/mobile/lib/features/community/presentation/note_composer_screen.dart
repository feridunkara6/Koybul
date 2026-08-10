import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../weather/application/weather_controller.dart';
import '../application/community_controller.dart';
import 'note_card.dart';

/// NOT BIRAKMA — 3 adım, ama kullanıcı yalnız İKİSİNİ doldurur.
///
/// Tasarım sözü: "gereksiz bilgi isteme, sistem otomatik doldursun."
/// Nokta, tarih ve o anki hava önceden gelir; kaptan yalnız tipi ve metni verir.
class NoteComposerScreen extends ConsumerStatefulWidget {
  const NoteComposerScreen({
    required this.locationId,
    required this.locationName,
    required this.position,
    this.devicePosition,
    super.key,
  });

  final String locationId;
  final String locationName;

  /// Noktanın konumu (hava tahmini için).
  final GeoPoint position;

  /// Kaptanın GERÇEK konumu — status/hazard notları bunu ister.
  final GeoPoint? devicePosition;

  @override
  ConsumerState<NoteComposerScreen> createState() => _NoteComposerScreenState();
}

class _NoteComposerScreenState extends ConsumerState<NoteComposerScreen> {
  NoteKind _kind = NoteKind.experience;
  final TextEditingController _body = TextEditingController();
  DateTime _observed = DateTime.now();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Kaptan noktanın yanındaysa muhtemelen "şu anki durumu" paylaşacaktır.
    if (widget.devicePosition != null) _kind = NoteKind.status;
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int _maxChars(NoteKind k) => switch (k) {
        NoteKind.status => 280,
        NoteKind.hazard => 500,
        _ => 4000,
      };

  bool _needsGps(NoteKind k) => k == NoteKind.status || k == NoteKind.hazard;

  /// O anki rüzgâr — kullanıcıdan İSTENMEZ, tahminden okunup nota dondurulur.
  NoteWind? _currentWind() {
    final AsyncValue<WeatherForecast> wx = ref.read(
      weatherForecastProvider(weatherKeyFor(widget.position.lat, widget.position.lon)),
    );
    final WeatherForecast? f = wx.valueOrNull;
    if (f == null || f.points.isEmpty) return null;
    final ForecastPoint p = f.points.first;
    final L10n t = ref.read(l10nProvider);
    return NoteWind(kn: p.windKn.round(), dirTr: t.compassDir(_dirCode(p.windDirDeg)));
  }

  static String _dirCode(int deg) {
    const List<String> codes = <String>['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    return codes[(((deg % 360) + 22) ~/ 45) % 8];
  }

  Future<void> _submit() async {
    final L10n t = ref.read(l10nProvider);
    if (_needsGps(_kind) && widget.devicePosition == null) {
      _snack(t.noteNeedLocation);
      return;
    }
    // Messenger ÖNCEDEN yakalanır: pop'tan sonra bu context ölür ve
    // ScaffoldMessenger.of(context) patlar (sessiz bir çökme kaynağı).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final Note note = await ref.read(communityGatewayProvider).createNote(
            locationId: widget.locationId,
            kind: _kind,
            body: _body.text.trim(),
            observedOn: _ymd(_observed),
            position: _needsGps(_kind) ? widget.devicePosition : null,
            wind: _currentWind(),
          );
      if (!mounted) return;
      ref.read(noteOverridesProvider.notifier).prepend(widget.locationId, note);
      Navigator.of(context).pop(true);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(note.status == 'approved' ? t.notePublished : t.noteSubmitted),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(_message(error, t));
    }
  }

  /// Sunucu zaten yerelleştirilmiş bir `message` gönderir; ham istisna metni
  /// arayüze SIZMAZ (docs/26 §13, occupancy_row ile aynı desen).
  String _message(Object error, L10n t) {
    if (error is ValidationFailure) return error.message;
    if (error is AppFailure) return error.message;
    return t.noteTooFar;
  }

  void _snack(String text) {
    final ScaffoldMessengerState m = ScaffoldMessenger.of(context);
    m
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final int max = _maxChars(_kind);
    final NoteWind? wind = _currentWind();
    final String body = _body.text.trim();
    final bool canSend = body.length >= 3 && body.length <= max && !_sending;

    return Scaffold(
      appBar: AppBar(title: Text(t.noteComposerTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _StepLabel(index: 1, text: t.noteStep1),
          for (final NoteKind k in NoteKind.values)
            _KindTile(
              kind: k,
              selected: _kind == k,
              onTap: () => setState(() => _kind = k),
            ),
          const SizedBox(height: 18),
          _StepLabel(index: 2, text: t.noteStep2),
          TextField(
            key: const ValueKey<String>('note-body'),
            controller: _body,
            maxLines: 6,
            maxLength: max,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: t.noteBodyHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _StepLabel(index: 3, text: t.noteStep3),
              const SizedBox(width: 6),
              Text(
                '· ${t.noteAutoFilled}',
                style: theme.textTheme.labelSmall?.copyWith(color: DocklyColors.success),
              ),
            ],
          ),
          _ContextRow(icon: DocklyIcons.place, label: widget.locationName),
          _ContextRow(
            icon: DocklyIcons.eventNoteOutlined,
            label: _ymd(_observed),
            trailing: t.editLabel,
            onTap: _pickDate,
          ),
          if (wind != null)
            _ContextRow(
              icon: DocklyIcons.navigation,
              label: '${t.noteWindLabel}: ${wind.kn} kn ${wind.dirTr}',
            ),
          if (_needsGps(_kind))
            _ContextRow(
              icon: DocklyIcons.verified,
              label: widget.devicePosition != null ? t.noteGpsOk : t.noteNeedLocation,
              danger: widget.devicePosition == null,
            ),
          const SizedBox(height: 14),
          DocklyButton(
            key: const ValueKey<String>('note-submit'),
            label: t.noteSubmit,
            loading: _sending,
            onPressed: canSend ? _submit : null,
          ),
          const SizedBox(height: 8),
          Text(
            // Gönderim ÖNCESİ moderasyon bildirimi (09 §10.2 onaylı mikro-metin).
            // "Notun alındı" metni yalnız gönderimden SONRA çıkar.
            t.noteModerationNotice,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _observed.isAfter(now) ? now : _observed,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _observed = picked);
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$index · $text',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}

class _KindTile extends ConsumerWidget {
  const _KindTile({required this.kind, required this.selected, required this.onTap});

  final NoteKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final Color color = noteKindColor(context, kind);
    final String hint = switch (kind) {
      NoteKind.status => t.noteKindStatusHint,
      NoteKind.hazard => t.noteKindHazardHint,
      NoteKind.experience => t.noteKindExperienceHint,
      NoteKind.passage => t.noteKindPassageHint,
    };
    return InkWell(
      key: ValueKey<String>('note-kind-${kind.wire}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            DocklyIcon(noteKindIcon(kind), size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.noteKindLabel(kind.wire),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final DocklyIconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = danger ? DocklyColors.error : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            DocklyIcon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }
}
