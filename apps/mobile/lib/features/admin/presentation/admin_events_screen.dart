import 'package:dockly_api/dockly_api.dart'
    show AdminEventInput, EventParticipantView, EventView;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../events/application/events_controller.dart';
import '../../events/presentation/events_screen.dart' show EventAudienceChip;
import '../application/admin_controller.dart';

/// PANEL — ETKİNLİK YÖNETİMİ (V1, kurucu onayı 2026-10-23).
/// Oluştur / iptal et / katılımcıları gör. Yetki SUNUCUDA (admin+);
/// liste, kullanıcıların gördüğü akışın aynısıdır — ayrı doğruluk yok.
class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends ConsumerState<AdminEventsScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelEvent(EventView e) async {
    final L10n t = ref.read(l10nProvider);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(t.admEvCancelCta),
        content: Text(t.admEvCancelConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancelLabel),
          ),
          FilledButton(
            key: const ValueKey<String>('adm-ev-cancel-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: DocklyColors.error),
            child: Text(t.admEvCancelCta),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminGatewayProvider).cancelEvent(e.id);
      ref.invalidate(eventsFeedProvider);
      _snack(t.admEvCancelDone);
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showParticipants(EventView e) async {
    final L10n t = ref.read(l10nProvider);
    List<EventParticipantView> list;
    try {
      list = await ref.read(adminGatewayProvider).participants(e.id);
    } on AppFailure catch (f) {
      _snack(f.message);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: <Widget>[
            Text('${t.admEvParticipants} · ${list.length}',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (list.isEmpty)
              Text(t.admEvNoParticipants)
            else
              for (final EventParticipantView p in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('${p.displayName} — ${p.email}'),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<EventView>> feed = ref.watch(eventsFeedProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.admEventsRow)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('adm-ev-new'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminEventComposer()),
        ),
        label: Text(t.admEvNew),
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
            child: Text(e is AppFailure ? e.message : '$e',
                textAlign: TextAlign.center)),
        data: (List<EventView> events) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: <Widget>[
            for (final EventView e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: theme.dividerColor.withValues(alpha: .4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        Expanded(
                          child: Text(e.title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        if (e.cancelled)
                          Text(t.evCancelledChip,
                              style: const TextStyle(
                                  color: DocklyColors.error,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10))
                        else
                          EventAudienceChip(audience: e.audience, t: t),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        '📅 ${formatEventMoment(e.startsAt)} · '
                        '${L10n.fmt2(t.evQuotaFmt2, '${e.registeredCount}', '${e.quota}')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Row(children: <Widget>[
                        OutlinedButton(
                          key: ValueKey<String>('adm-ev-participants-${e.id}'),
                          style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                          onPressed: _busy ? null : () => _showParticipants(e),
                          child: Text(t.admEvParticipants),
                        ),
                        const SizedBox(width: 8),
                        if (!e.cancelled)
                          OutlinedButton(
                            key: ValueKey<String>('adm-ev-cancel-${e.id}'),
                            style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: DocklyColors.error),
                            onPressed: _busy ? null : () => _cancelEvent(e),
                            child: Text(t.admEvCancelCta),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Etkinlik oluşturma formu — tarih/saat yerli seçicilerle (ISO yazdırmak
/// kurucuya bırakılmaz). Varsayılan başlangıç: bir hafta sonra 14:00.
class AdminEventComposer extends ConsumerStatefulWidget {
  const AdminEventComposer({super.key});

  @override
  ConsumerState<AdminEventComposer> createState() => _AdminEventComposerState();
}

class _AdminEventComposerState extends ConsumerState<AdminEventComposer> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _quota = TextEditingController(text: '25');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _conditions = TextEditingController();
  late DateTime _startsAt;
  DateTime? _deadline;
  String _audience = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day + 7, 14);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _location.dispose();
    _quota.dispose();
    _price.dispose();
    _conditions.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<DateTime?> _pickMoment(DateTime initial) async {
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (day == null || !mounted) return null;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final L10n t = ref.read(l10nProvider);
    final int? quota = int.tryParse(_quota.text.trim());
    if (_title.text.trim().length < 3 ||
        _body.text.trim().length < 10 ||
        _location.text.trim().length < 2 ||
        quota == null ||
        quota < 1) {
      _snack(t.admValRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminGatewayProvider).createEvent(AdminEventInput(
            title: _title.text.trim(),
            body: _body.text.trim(),
            startsAt: _startsAt,
            locationText: _location.text.trim(),
            quota: quota,
            audience: _audience,
            registrationDeadline: _deadline,
            priceNote: _price.text.trim().isEmpty ? null : _price.text.trim(),
            conditions:
                _conditions.text.trim().isEmpty ? null : _conditions.text.trim(),
          ));
      ref.invalidate(eventsFeedProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _snack(t.admSavedNote);
      }
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);

    Widget field(TextEditingController c, String label,
            {int lines = 1, TextInputType? type, String? keyValue}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            key: keyValue != null ? ValueKey<String>(keyValue) : null,
            controller: c,
            enabled: !_busy,
            minLines: lines,
            maxLines: lines < 3 ? lines : 6,
            keyboardType: type,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
          ),
        );

    Widget momentRow(String label, DateTime? value, VoidCallback onPick) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: <Widget>[
            Expanded(
              child: Text(
                '$label\n${value == null ? '—' : formatEventMoment(value.toUtc())}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            OutlinedButton(onPressed: _busy ? null : onPick, child: Text(t.editLabel)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.admEvNew)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          field(_title, t.admFormTitle, keyValue: 'adm-ev-title'),
          field(_body, t.admFormBody, lines: 4, keyValue: 'adm-ev-body'),
          field(_location, t.admFormLocation, keyValue: 'adm-ev-location'),
          field(_quota, t.admFormQuota,
              type: TextInputType.number, keyValue: 'adm-ev-quota'),
          momentRow(t.admFormStart, _startsAt, () async {
            final DateTime? picked = await _pickMoment(_startsAt);
            if (picked != null) setState(() => _startsAt = picked);
          }),
          momentRow(t.admFormDeadline, _deadline, () async {
            final DateTime? picked = await _pickMoment(_deadline ?? _startsAt);
            if (picked != null) setState(() => _deadline = picked);
          }),
          field(_price, t.admFormPrice),
          field(_conditions, t.admFormConditions, lines: 2),
          Text(t.admFormAudience,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: <Widget>[
            for (final (String code, String label) in <(String, String)>[
              ('all', t.admAudAll),
              ('members', t.admAudMembers),
              ('premium', t.admAudPremium),
            ])
              ChoiceChip(
                key: ValueKey<String>('adm-ev-aud-$code'),
                label: Text(label),
                selected: _audience == code,
                onSelected: (_) => setState(() => _audience = code),
                showCheckmark: false,
                selectedColor: DocklyColors.brandPrimary,
                labelStyle: TextStyle(
                  color: _audience == code
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ]),
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey<String>('adm-ev-save'),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? t.busyLabel : t.admSaveCta),
          ),
        ],
      ),
    );
  }
}
