import 'package:dockly_api/dockly_api.dart' show DealView, EventView;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../premium/presentation/premium_screen.dart';
import '../application/events_controller.dart';
import 'event_detail_screen.dart';

/// ETKİNLİKLER ana ekranı (onaylı görsel konsept Ekran 6-7).
/// İki bölüm: Etkinlikler (kontenjanlı buluşmalar) | Fırsatlar (iş ortağı
/// kodları). Kitle kilitleri SUNUCUDA — kilitli kod buraya hiç inmez;
/// ekran yalnız kilit rozetini çizer ve doğru kapıya yönlendirir.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.evRowTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(eventsFeedProvider);
          ref.invalidate(dealsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Text(
              t.evLead,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            // Segment — Defter sekmesindeki desenle aynı aile.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  _SegBtn(
                    label: t.evTabEvents,
                    selected: _segment == 0,
                    onTap: () => setState(() => _segment = 0),
                  ),
                  _SegBtn(
                    label: t.evTabDeals,
                    selected: _segment == 1,
                    onTap: () => setState(() => _segment = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_segment == 0) const _EventsTab() else const _DealsTab(),
          ],
        ),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 4,
                        offset: const Offset(0, 1)),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hedef kitle rozeti — altın ⭑ PREMIUM / mavi ÜYELERE / yeşil HERKESE.
class EventAudienceChip extends StatelessWidget {
  const EventAudienceChip({required this.audience, required this.t, super.key});

  final String audience;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (audience) {
      'premium' => (const Color(0xFFFFF7E0), const Color(0xFFB8860B), '⭑ PREMIUM'),
      'members' => (const Color(0xFFE8F1FB), DocklyColors.brandPrimary, t.evAudMembers),
      _ => (const Color(0xFFE6F7F3), const Color(0xFF0B7A6C), t.evAudAll),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

/// Kontenjan çubuğu — yeşil (yer var) → turuncu (son yerler) → kırmızı (dolu).
class EventQuotaBar extends StatelessWidget {
  const EventQuotaBar({required this.e, required this.t, super.key});

  final EventView e;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = e.quota == 0 ? 1 : e.registeredCount / e.quota;
    final Color bar = e.full
        ? DocklyColors.error
        : (ratio >= 0.85 ? DocklyColors.warning : DocklyColors.success);
    final String text = e.full
        ? '${L10n.fmt2(t.evQuotaFmt2, '${e.registeredCount}', '${e.quota}')} — ${t.evFullCap}'
        : '${L10n.fmt2(t.evQuotaFmt2, '${e.registeredCount}', '${e.quota}')} · '
            '${ratio >= 0.85 ? t.evLastSpots : L10n.fmt(t.evRemainingFmt, '${e.remaining}')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(bar),
          ),
        ),
        const SizedBox(height: 4),
        Text(text,
            style: theme.textTheme.labelSmall?.copyWith(
                color: e.full ? DocklyColors.error : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<EventView>> feed = ref.watch(eventsFeedProvider);
    return feed.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => _ErrorBox(
        message: e is AppFailure ? e.message : '$e',
        onRetry: () => ref.invalidate(eventsFeedProvider),
      ),
      data: (List<EventView> events) {
        if (events.isEmpty) {
          return _Empty(icon: '🎟️', text: t.evEmpty);
        }
        return Column(
          children: <Widget>[for (final EventView e in events) _EventCard(e: e, t: t)],
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.e, required this.t});

  final EventView e;
  final L10n t;

  static const List<List<Color>> _tones = <List<Color>>[
    <Color>[DocklyColors.brandDeep, DocklyColors.brandPrimary],
    <Color>[Color(0xFF0B7A6C), DocklyColors.accentTurquoise],
    <Color>[Color(0xFF6243C4), Color(0xFF8E6FF0)],
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    final List<Color> tone = _tones[e.id.hashCode.abs() % _tones.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: e.cancelled ? .6 : 1,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('ev-item-${e.id}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => EventDetailScreen(eventId: e.id)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 64,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: tone),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ),
                        if (e.cancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(t.evCancelledChip,
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: DocklyColors.error)),
                          )
                        else
                          EventAudienceChip(audience: e.audience, t: t),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '📅 ${formatEventMoment(e.startsAt)}   📍 ${e.locationText}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: sub),
                      ),
                      const SizedBox(height: 8),
                      if (e.registered)
                        Text(t.evRegisteredChip,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: DocklyColors.success,
                                fontWeight: FontWeight.w800))
                      else if (!e.cancelled)
                        EventQuotaBar(e: e, t: t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealsTab extends ConsumerWidget {
  const _DealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<DealView>> deals = ref.watch(dealsProvider);
    return deals.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => _ErrorBox(
        message: e is AppFailure ? e.message : '$e',
        onRetry: () => ref.invalidate(dealsProvider),
      ),
      data: (List<DealView> rows) {
        if (rows.isEmpty) return _Empty(icon: '🏷️', text: t.dealEmpty);
        return Column(
          children: <Widget>[for (final DealView d in rows) _DealCard(d: d, t: t)],
        );
      },
    );
  }
}

class _DealCard extends ConsumerWidget {
  const _DealCard({required this.d, required this.t});

  final DealView d;
  final L10n t;

  Future<void> _copy(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: d.code!));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(L10n.fmt(t.dealCopiedFmt, d.code!))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    final List<String> meta = <String>[
      if (d.validUntil != null)
        d.expired
            ? '${L10n.fmt(t.dealValidFmt, formatEventMoment(d.validUntil!))} — ${t.dealExpired}'
            : L10n.fmt(t.dealValidFmt, formatEventMoment(d.validUntil!)),
      if (d.terms != null && d.terms!.isNotEmpty) d.terms!,
      if (d.place != null && d.place!.isNotEmpty) L10n.fmt(t.dealPlaceFmt, d.place!),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: d.expired ? .55 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
                    child: Text(d.partner.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: sub,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .4)),
                  ),
                  EventAudienceChip(audience: d.audience, t: t),
                ],
              ),
              const SizedBox(height: 3),
              Text(d.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(d.benefit,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: DocklyColors.success, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              // KOD KUTUSU: kod sunucudan geldiyse kopyalanır; kilitliyse
              // dürüst rozet + doğru kapı (giriş ya da Premium).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB9CBE2)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        d.code ??
                            (d.locked
                                ? (d.audience == 'premium'
                                    ? '⭑ ${t.dealLockedPremium}'
                                    : t.dealLockedMembers)
                                : (d.expired ? t.dealExpired : '—')),
                        style: d.code != null
                            ? theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800, letterSpacing: 1)
                            : theme.textTheme.labelSmall?.copyWith(color: sub),
                      ),
                    ),
                    if (d.code != null)
                      FilledButton(
                        key: ValueKey<String>('deal-copy-${d.id}'),
                        style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        onPressed: () => _copy(context),
                        child: Text(t.dealCopy),
                      )
                    else if (d.locked)
                      FilledButton(
                        key: ValueKey<String>('deal-unlock-${d.id}'),
                        style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: d.audience == 'premium'
                                ? const Color(0xFFB8860B)
                                : null),
                        onPressed: () {
                          if (d.audience == 'premium') {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const PremiumScreen()),
                            );
                          } else {
                            showSignInSheet(context);
                          }
                        },
                        child: Text(d.audience == 'premium'
                            ? t.dealUnlockCta
                            : t.accCta),
                      ),
                  ],
                ),
              ),
              if (meta.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(meta.join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(color: sub)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorBox extends ConsumerWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: Text(t.retryLabel)),
        ],
      ),
    );
  }
}
