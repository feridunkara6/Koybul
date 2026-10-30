import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/fuel_controller.dart';
import '../domain/fuel.dart';

/// YAKIT SEKMESİ (kurucu onayı 2026-10-30) — Bakım ekranının ikinci yüzü.
///
/// Üç dürüst sayı: sezon toplamı, ortalama tüketim (yalnız motor saati
/// girilen dolumlardan — yoksa '—'), son dolumdan beri geçen gün. Altta
/// dolum geçmişi ve iki dokunuşluk "Dolum ekle" sayfası. Kayıtlar yalnız
/// CİHAZDA durur ve hesapla gezer (çıkışta görünmez olur).
class FuelTab extends ConsumerWidget {
  const FuelTab({super.key});

  /// '46' / '4,2' — gereksiz ondalık yazılmaz; virgül Türk alışkanlığı.
  static String fmt(double v) => v == v.roundToDouble()
      ? '${v.round()}'
      : v.toStringAsFixed(1).replaceAll('.', ',');

  static String _day(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    final List<FuelEntry> entries = ref.watch(fuelProvider);
    final DateTime now = DateTime.now();
    final double season = fuelSeasonTotal(entries, now);
    final double? avg = fuelAvgPerHour(entries);
    final int? since = fuelDaysSinceLast(entries, now);

    Widget stat(String value, String caption) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: .4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: sub,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            stat('${fmt(season)} ${t.fuelLtUnit}', t.fuelSeasonCap),
            const SizedBox(width: 8),
            stat(
              avg == null ? '—' : L10n.fmt(t.fuelPerHourFmt, fmt(avg)),
              t.fuelAvgCap,
            ),
            const SizedBox(width: 8),
            stat(
              since == null ? '—' : L10n.fmt(t.fuelDaysAgoFmt, '$since'),
              t.fuelSinceCap,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(t.fuelAvgNote,
            style: theme.textTheme.bodySmall?.copyWith(color: sub)),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey<String>('fuel-add'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => _showAddSheet(context, ref),
          child: Text('＋ ${t.fuelAddCta}'),
        ),
        const SizedBox(height: 14),
        Text(t.fuelHistoryCap.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: .8, color: sub)),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text(t.fuelEmpty,
              key: const ValueKey<String>('fuel-empty'),
              style: theme.textTheme.bodySmall?.copyWith(color: sub))
        else
          for (final FuelEntry e in entries)
            Container(
              key: ValueKey<String>('fuel-row-${e.id}'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: .4)),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 82,
                    child: Text(_day(e.dateMs),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: sub, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text('${fmt(e.liters)} ${t.fuelLtUnit}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(e.cost == null ? '—' : fmt(e.cost!),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: sub)),
                      Text(
                          e.engineHours == null
                              ? '⏱ —'
                              : '⏱ ${fmt(e.engineHours!)}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: sub)),
                    ],
                  ),
                  IconButton(
                    key: ValueKey<String>('fuel-del-${e.id}'),
                    visualDensity: VisualDensity.compact,
                    icon: DocklyIcon(DocklyIcons.deleteOutline,
                        size: 16, color: sub),
                    onPressed: () => _confirmDelete(context, ref, e.id),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        // DÜRÜSTLÜK NOTU: veri nerede yaşar, kiminle gezer.
        Text(t.fuelPrivacyNote,
            style: theme.textTheme.bodySmall?.copyWith(
                color: sub, fontStyle: FontStyle.italic, height: 1.4)),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final L10n t = ref.read(l10nProvider);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(t.fuelDeleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancelLabel),
          ),
          FilledButton(
            key: const ValueKey<String>('fuel-del-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.fuelDeleteBtn),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(fuelProvider.notifier).remove(id);
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _FuelAddSheet(),
      ),
    );
  }
}

/// DOLUM EKLE sayfası — iki dokunuşta biter: litre yaz, kaydet.
/// Tutar ve motor saati İSTEĞE BAĞLI; tarih çipleri Bugün/Dün/Takvim.
class _FuelAddSheet extends ConsumerStatefulWidget {
  const _FuelAddSheet();

  @override
  ConsumerState<_FuelAddSheet> createState() => _FuelAddSheetState();
}

class _FuelAddSheetState extends ConsumerState<_FuelAddSheet> {
  late DateTime _day;

  /// 0 = Bugün · 1 = Dün · 2 = takvimden seçildi.
  int _dayChoice = 0;
  final TextEditingController _liters = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _hours = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _day = DateTime.now();
  }

  @override
  void dispose() {
    _liters.dispose();
    _cost.dispose();
    _hours.dispose();
    super.dispose();
  }

  /// '4,2' da '4.2' da okunur (Türk klavyesi virgül basar).
  static double? _num(String raw) {
    final String s = raw.trim().replaceAll(',', '.');
    return s.isEmpty ? null : double.tryParse(s);
  }

  Future<void> _pickDay() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(now) ? now : _day,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = picked;
      _dayChoice = 2;
    });
  }

  Future<void> _save() async {
    final L10n t = ref.read(l10nProvider);
    final double? liters = _num(_liters.text);
    if (liters == null || liters <= 0 || liters > 10000) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.fuelLitersInvalid)));
      return;
    }
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(fuelProvider.notifier).add(
          day: _day,
          liters: liters,
          cost: _num(_cost.text),
          engineHours: _num(_hours.text),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.fuelSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('＋ ${t.fuelAddCta}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const ValueKey<String>('fuel-day-today'),
                  label: Text(t.dateToday),
                  selected: _dayChoice == 0,
                  onSelected: (_) => setState(() {
                    _dayChoice = 0;
                    _day = today;
                  }),
                ),
                ChoiceChip(
                  key: const ValueKey<String>('fuel-day-yesterday'),
                  label: Text(t.dateYesterday),
                  selected: _dayChoice == 1,
                  onSelected: (_) => setState(() {
                    _dayChoice = 1;
                    _day = today.subtract(const Duration(days: 1));
                  }),
                ),
                ChoiceChip(
                  key: const ValueKey<String>('fuel-day-pick'),
                  label: Text(_dayChoice == 2
                      ? '${_day.day}.${_day.month}.${_day.year}'
                      : t.datePickLabel),
                  selected: _dayChoice == 2,
                  onSelected: (_) => _pickDay(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('fuel-liters'),
              controller: _liters,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: t.fuelLiters,
                suffixText: t.fuelLtUnit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('fuel-cost'),
              controller: _cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: t.fuelCost,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('fuel-hours'),
              controller: _hours,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: t.fuelHours,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('fuel-save'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _busy ? null : _save,
              child: Text(_busy ? t.busyLabel : t.saveLabel),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(t.fuelSheetNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
