import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../premium/presentation/premium_screen.dart';
import '../application/events_controller.dart';

/// ETKİNLİK KURMA (SP-4, kurucu onayı 2026-10-31) — YALNIZ Premium
/// (kapının son sözü SUNUCUDA; bu ekrana premium olmayan zaten gelmez,
/// gelirse 403'ü dürüstçe gösterir ve Premium sayfasına köprü kurar).
///
/// 3 ŞABLON (kurucu kararı): koy buluşması / birlikte seyir / marina.
/// Form bilerek KISA: başlık + açıklama + tarih + yer + kontenjan. Fiyat ve
/// koşul alanı YOK — bu ticari organizasyon değil, denizci buluşmasıdır.
/// Her etkinlik moderasyon ONAYINDAN sonra yayınlanır (pending doğar).
class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  String _template = 'bay_meetup';
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _place = TextEditingController();

  /// Varsayılan: bir hafta sonra 10:00 — kaptan dokunup değiştirir.
  late DateTime _when;
  int _quota = 10;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _when = DateTime(now.year, now.month, now.day + 7, 10);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final DateTime now = DateTime.now();
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: _when.isAfter(now) ? _when : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _when.hour, minute: _when.minute),
    );
    if (!mounted) return;
    setState(() {
      _when = DateTime(
        day.year,
        day.month,
        day.day,
        time?.hour ?? _when.hour,
        time?.minute ?? _when.minute,
      );
    });
  }

  Future<void> _submit() async {
    final L10n t = ref.read(l10nProvider);
    final String title = _title.text.trim();
    final String body = _body.text.trim();
    final String place = _place.text.trim();
    // İstemci ön denetimi — sunucu sınırlarıyla birebir (3/10/2).
    if (title.length < 3 || body.length < 10 || place.length < 2) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.evFormIncomplete)));
      return;
    }
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(eventsGatewayProvider).createEvent(
            template: _template,
            title: title,
            body: body,
            startsAt: _when,
            locationText: place,
            quota: _quota,
          );
      ref.invalidate(eventsFeedProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.evCreateSent)));
    } on ForbiddenFailure catch (f) {
      // Premium kapısı sunucuda — dürüst mesaj + köprü (sıkmama sözleşmesi).
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(f.message)));
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
        );
      }
    } on AppFailure catch (f) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(f.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final TextStyle? label = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.evCreateTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: <Widget>[
          Text(t.evTplCap.toUpperCase(), style: label),
          const SizedBox(height: 8),
          for (final (String code, DocklyIconData icon, String name, String desc)
              in <(String, DocklyIconData, String, String)>[
            ('bay_meetup', DocklyIcons.place, t.evTplBay, t.evTplBayDesc),
            ('joint_sail', DocklyIcons.sailing, t.evTplSail, t.evTplSailDesc),
            ('marina_meetup', DocklyIcons.pier, t.evTplMarina, t.evTplMarinaDesc),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: ValueKey<String>('evc-tpl-$code'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _template = code),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: _template == code
                        ? DocklyColors.brandPrimary.withValues(alpha: 0.07)
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _template == code
                          ? DocklyColors.brandPrimary
                          : theme.dividerColor.withValues(alpha: .4),
                      width: _template == code ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      DocklyIcon(icon,
                          size: 20,
                          color: _template == code
                              ? DocklyColors.brandPrimary
                              : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(name,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(desc,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(t.evFormTitleCap.toUpperCase(), style: label),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey<String>('evc-title'),
            controller: _title,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: t.evFormTitleHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Text(t.evFormBodyCap.toUpperCase(), style: label),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey<String>('evc-body'),
            controller: _body,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: t.evFormBodyHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(t.evFormWhenCap.toUpperCase(), style: label),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const ValueKey<String>('evc-when'),
            onPressed: _pickWhen,
            icon: const DocklyIcon(DocklyIcons.eventNoteOutlined, size: 16),
            label: Text(formatEventMoment(_when.toUtc())),
          ),
          const SizedBox(height: 12),
          Text(t.evFormWhereCap.toUpperCase(), style: label),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey<String>('evc-place'),
            controller: _place,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: t.evFormWhereHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Text(t.evFormQuotaCap.toUpperCase(), style: label),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('evc-quota-minus'),
                onPressed:
                    _quota > 2 ? () => setState(() => _quota -= 1) : null,
                icon: const Text('−',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text('$_quota',
                  key: const ValueKey<String>('evc-quota'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              IconButton(
                key: const ValueKey<String>('evc-quota-plus'),
                onPressed:
                    _quota < 100 ? () => setState(() => _quota += 1) : null,
                icon: const Text('+',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.evFormQuotaNote,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey<String>('evc-send'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? t.busyLabel : t.evFormSend),
          ),
          const SizedBox(height: 8),
          // Dürüst süreç notu: önce moderasyon, sonra yayın.
          Center(
            child: Text(t.evCreateModNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
