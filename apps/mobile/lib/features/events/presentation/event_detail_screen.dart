import 'package:dockly_api/dockly_api.dart' show EventView;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../premium/presentation/premium_screen.dart';
import '../application/events_controller.dart';
import 'events_screen.dart' show EventAudienceChip, EventQuotaBar;

/// ETKİNLİK DETAYI (onaylı görsel konsept Ekran 8-9-10).
///
/// Dört dürüst durum: kayıt açık → "Kayıt ol"; kayıtlı → yeşil onay + iptal;
/// dolu → pasif düğme + "iptal olursa yer açılır" notu (bekleme listesi V2);
/// iptal → kırmızı şerit. Kontenjan ve kitle kararı SUNUCUNUN — düğme açık
/// görünse bile son sözü sunucu söyler ve ekran tazelenir.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register(EventView e) async {
    final L10n t = ref.read(l10nProvider);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ({bool registered, int remaining}) res =
          await ref.read(eventsGatewayProvider).register(widget.eventId);
      _snack(L10n.fmt(t.evRegisteredFmt, '${res.remaining}'));
    } on GuestNotAllowedFailure catch (f) {
      _snack(f.message);
      if (mounted) await showSignInSheet(context);
    } on AuthFailure {
      if (mounted) await showSignInSheet(context);
    } on ForbiddenFailure catch (f) {
      // Premium kitlesi ya da dolu kontenjan — mesaj sunucudan, dürüstçe.
      _snack(f.message);
      if (e.audience == 'premium' && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
        );
      }
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      ref.invalidate(eventsFeedProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final L10n t = ref.read(l10nProvider);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(eventsGatewayProvider).cancel(widget.eventId);
      _snack(t.evCancelDone);
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      ref.invalidate(eventsFeedProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<EventView> detail =
        ref.watch(eventDetailProvider(widget.eventId));
    return Scaffold(
      appBar: AppBar(title: Text(t.evRowTitle)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is AppFailure ? e.message : '$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (EventView e) => _body(context, t, e),
      ),
    );
  }

  Widget _body(BuildContext context, L10n t, EventView e) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    // GEÇMİŞ ETKİNLİK (kurucu onayı 2026-10-25): eşik listeyle ve sunucuyla
    // aynıdır (-1 gün). Geçmişte kayıt alanı yerine dürüst kapanış notu
    // gösterilir; sunucu register() zaten 'not-open' derdi — arayüz o
    // kapıya hiç göndermiyor.
    final bool past = !e.cancelled &&
        (e.endsAt ?? e.startsAt)
            .isBefore(DateTime.now().subtract(const Duration(days: 1)));

    Widget info(String icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 22, child: Text(icon)),
              Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        if (e.cancelled)
          Container(
            key: const ValueKey<String>('ev-cancelled'),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEBEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(t.evCancelledBanner,
                style: const TextStyle(
                    color: DocklyColors.error, fontWeight: FontWeight.w800)),
          ),
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(e.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  EventAudienceChip(audience: e.audience, t: t),
                ],
              ),
              const SizedBox(height: 8),
              Text(e.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              info('📅',
                  '${formatEventMoment(e.startsAt)}${e.endsAt != null ? ' – ${formatEventMoment(e.endsAt!)}' : ''}'),
              if (e.registrationDeadline != null)
                info('⏳',
                    L10n.fmt(t.evDeadlineFmt, formatEventMoment(e.registrationDeadline!))),
              info('📍', e.locationText),
              if (e.conditions != null && e.conditions!.isNotEmpty)
                info('👥', e.conditions!),
              if (e.priceNote != null && e.priceNote!.isNotEmpty)
                info('💰', e.priceNote!),
              info('🧭', L10n.fmt(t.evOrganizerFmt, e.organizer)),
              const SizedBox(height: 4),
              if (past)
                Text(
                  L10n.fmt2(
                      t.evPastDoneFmt, '${e.registeredCount}', '${e.quota}'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: sub, fontWeight: FontWeight.w800),
                )
              else if (!e.cancelled)
                EventQuotaBar(e: e, t: t),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (e.cancelled)
          const SizedBox.shrink()
        else if (past)
          Container(
            key: const ValueKey<String>('ev-past'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(t.evPastNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: sub, fontWeight: FontWeight.w700)),
          )
        else if (e.registered) ...<Widget>[
          Container(
            key: const ValueKey<String>('ev-registered'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2FBF6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFE8D2)),
            ),
            child: Text(t.evRegisteredChip,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: DocklyColors.success, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey<String>('ev-cancel'),
            onPressed: _busy ? null : _cancel,
            style: OutlinedButton.styleFrom(foregroundColor: DocklyColors.error),
            child: Text(_busy ? t.busyLabel : t.evCancelCta),
          ),
        ] else if (e.full) ...<Widget>[
          FilledButton(
            key: const ValueKey<String>('ev-register'),
            onPressed: null,
            child: Text(t.evFullCap),
          ),
          const SizedBox(height: 6),
          Text(t.evFullNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: sub)),
        ] else
          FilledButton(
            key: const ValueKey<String>('ev-register'),
            onPressed: _busy ? null : () => _register(e),
            child: Text(_busy ? t.busyLabel : t.evRegisterCta),
          ),
      ],
    );
  }
}
