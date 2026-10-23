import 'package:dockly_api/dockly_api.dart' show AdminDealInput, DealView;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../events/application/events_controller.dart';
import '../../events/presentation/events_screen.dart' show EventAudienceChip;
import '../application/admin_controller.dart';

/// PANEL — FIRSAT YÖNETİMİ (V1, kurucu onayı 2026-10-23).
/// Oluştur + aç/kapat. Yönetici listede kodu hep görür (rol kilidi geçer);
/// kullanıcı tarafındaki kitle kilidi SUNUCUDA kalır.
class AdminDealsScreen extends ConsumerStatefulWidget {
  const AdminDealsScreen({super.key});

  @override
  ConsumerState<AdminDealsScreen> createState() => _AdminDealsScreenState();
}

class _AdminDealsScreenState extends ConsumerState<AdminDealsScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setActive(DealView d, bool isActive) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminGatewayProvider)
          .setDealActive(d.id, isActive: isActive);
      ref.invalidate(dealsProvider);
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<DealView>> deals = ref.watch(dealsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.admDealsRow)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('adm-deal-new'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminDealComposer()),
        ),
        label: Text(t.admDealNew),
      ),
      body: deals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
            child: Text(e is AppFailure ? e.message : '$e',
                textAlign: TextAlign.center)),
        data: (List<DealView> rows) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: <Widget>[
            // Not: pasif fırsat SUNUCU listesinden düşer; panelde yalnız
            // aktifler görünür — pasifi geri açmak V2 (liste ucu gerekir).
            for (final DealView d in rows)
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
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(d.partner.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800)),
                            Text(d.title,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              '${d.benefit}${d.code != null ? ' · ${d.code}' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: DocklyColors.success,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            EventAudienceChip(audience: d.audience, t: t),
                          ],
                        ),
                      ),
                      Column(children: <Widget>[
                        Switch(
                          key: ValueKey<String>('adm-deal-active-${d.id}'),
                          value: true, // listede yalnız aktifler var
                          onChanged:
                              _busy ? null : (bool v) => _setActive(d, v),
                          activeTrackColor: DocklyColors.success,
                        ),
                        Text(t.admDealActiveToggle,
                            style: theme.textTheme.labelSmall),
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

/// Fırsat oluşturma formu.
class AdminDealComposer extends ConsumerStatefulWidget {
  const AdminDealComposer({super.key});

  @override
  ConsumerState<AdminDealComposer> createState() => _AdminDealComposerState();
}

class _AdminDealComposerState extends ConsumerState<AdminDealComposer> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _partner = TextEditingController();
  final TextEditingController _benefit = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _terms = TextEditingController();
  final TextEditingController _place = TextEditingController();
  DateTime? _validUntil;
  String _audience = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _partner.dispose();
    _benefit.dispose();
    _code.dispose();
    _terms.dispose();
    _place.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final L10n t = ref.read(l10nProvider);
    if (_title.text.trim().length < 3 ||
        _partner.text.trim().length < 2 ||
        _benefit.text.trim().length < 2) {
      _snack(t.admValRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminGatewayProvider).createDeal(AdminDealInput(
            title: _title.text.trim(),
            partner: _partner.text.trim(),
            benefit: _benefit.text.trim(),
            audience: _audience,
            code: _code.text.trim().isEmpty ? null : _code.text.trim(),
            validUntil: _validUntil,
            terms: _terms.text.trim().isEmpty ? null : _terms.text.trim(),
            place: _place.text.trim().isEmpty ? null : _place.text.trim(),
          ));
      ref.invalidate(dealsProvider);
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

    Widget field(TextEditingController c, String label, {String? keyValue}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            key: keyValue != null ? ValueKey<String>(keyValue) : null,
            controller: c,
            enabled: !_busy,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.admDealNew)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          field(_partner, t.admFormPartner, keyValue: 'adm-deal-partner'),
          field(_title, t.admFormTitle, keyValue: 'adm-deal-title'),
          field(_benefit, t.admFormBenefit, keyValue: 'adm-deal-benefit'),
          field(_code, t.admFormCode, keyValue: 'adm-deal-code'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: <Widget>[
              Expanded(
                child: Text(
                  '${t.admFormValid}\n'
                  '${_validUntil == null ? '—' : formatEventMoment(_validUntil!.toUtc())}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final DateTime? day = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (day != null) {
                          setState(() => _validUntil =
                              DateTime(day.year, day.month, day.day, 23, 59));
                        }
                      },
                child: Text(t.editLabel),
              ),
            ]),
          ),
          field(_terms, t.admFormTerms),
          field(_place, t.admFormPlace),
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
                key: ValueKey<String>('adm-deal-aud-$code'),
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
            key: const ValueKey<String>('adm-deal-save'),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? t.busyLabel : t.admSaveCta),
          ),
        ],
      ),
    );
  }
}
