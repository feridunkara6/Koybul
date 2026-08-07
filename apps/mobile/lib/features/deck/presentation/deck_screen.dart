import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../logbook/presentation/logbook_screen.dart'
    show LogbookBody, showLogEntryEditor;
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/presentation/tour_targets.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/saved_route.dart';
import '../../route/domain/sea_route.dart' show haversineNm;
import '../../route/domain/sea_trip.dart';
import '../../route/presentation/saved_routes_screen.dart' show SavedRouteCard;
import '../application/trip_log_controller.dart';
import '../domain/sea_trip_log.dart';

/// DEFTER sekmesi (v2.0 vizyonu, kurucu onayı 2026-08): denizcinin arşivi.
/// Üç bölüm: SEYİRLER (tamamlanan seyirler + sezon özeti) · ROTALARIM ·
/// NOTLAR (eski Günlük). Seyir kaydı akışı: rota kartında "Seyri başlat" →
/// burada "Seyri bitir" ya da rota kartından bitir — kayıt buraya işlenir.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  int _seg = 0; // 0 = Seyirler · 1 = Rotalarım · 2 = Notlar

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    // ÖRNEKLİ TUR: Defter adımında Rotalarım segmenti gösterilir ve ÖRNEK
    // rozetli kart eklenir (kalıcı değildir; adım geçince kaybolur).
    final bool tourDemo = ref.watch(onboardingControllerProvider
            .select((OnboardingState s) => s.tourStep)) ==
        kTourStepSaved;
    final int seg = tourDemo ? 1 : _seg;
    return Scaffold(
      appBar: AppBar(title: Text(t.navDeck)),
      // Not ekleme yalnız Notlar segmentinde (heroTag: Günlük ekranındaki
      // FAB ile Hero çakışması olmasın — ikisi de açık olabilir).
      floatingActionButton: seg == 2
          ? FloatingActionButton.extended(
              heroTag: 'deck-note-fab',
              key: const ValueKey<String>('deck-note-new'),
              onPressed: () => showLogEntryEditor(context, ref),
              icon: const DocklyIcon(DocklyIcons.edit,
                  size: 18, color: Colors.white),
              label: Text(t.logbookNew),
              backgroundColor: DocklyColors.brandPrimary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: <Widget>[
                _SegChip(
                  label: t.deckTabTrips,
                  selected: seg == 0,
                  onTap: () => setState(() => _seg = 0),
                ),
                const SizedBox(width: 8),
                _SegChip(
                  label: t.deckTabRoutes,
                  selected: seg == 1,
                  onTap: () => setState(() => _seg = 1),
                ),
                const SizedBox(width: 8),
                _SegChip(
                  label: t.deckTabNotes,
                  selected: seg == 2,
                  onTap: () => setState(() => _seg = 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: seg == 0
                ? const _TripsTab()
                : seg == 1
                    ? _RoutesTab(tourDemo: tourDemo)
                    : const LogbookBody(),
          ),
        ],
      ),
    );
  }
}

/// SEYİRLER bölümü: süren seyir (varsa) + sezon özeti + tamamlanan seyirler.
class _TripsTab extends ConsumerWidget {
  const _TripsTab();

  /// Dakikayı "%s sa %s dk" / "%s dk" biçiminde yazar (rota süresiyle aynı dil).
  static String _fmtDuration(L10n t, int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return h > 0 ? L10n.fmt2(t.etaHmFmt, '$h', '$m') : L10n.fmt(t.etaMFmt, '$m');
  }

  static String _fmtNm(double nm) =>
      nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<SeaTripLog> trips = ref.watch(tripLogProvider);
    final ActiveTrip? active = ref.watch(activeTripProvider);
    if (trips.isEmpty && active == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.tripsEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    // SEZON ÖZETİ: içinde bulunulan yılın seyirleri (0-uydurma: yalnız
    // gerçekten kaydedilen seyirler sayılır).
    final int year = DateTime.now().year;
    final List<SeaTripLog> season = <SeaTripLog>[
      for (final SeaTripLog x in trips)
        if (DateTime.fromMillisecondsSinceEpoch(x.endMs).year == year) x,
    ];
    double seasonNm = 0;
    int seasonMin = 0;
    for (final SeaTripLog x in season) {
      seasonNm += x.distanceNm;
      seasonMin += x.durationMin;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
      children: <Widget>[
        if (active != null) _ActiveTripCard(active: active),
        if (season.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF0E3052), Color(0xFF071626)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  L10n.fmt(t.tripSeasonFmt, '$year'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7FE3D9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SeasonStat(
                        caption: t.deckTabTrips,
                        value: '${season.length}',
                      ),
                    ),
                    Expanded(
                      child: _SeasonStat(
                        caption: t.routeStatDistance,
                        value: '≈ ${_fmtNm(seasonNm)} ${t.nmUnit}',
                      ),
                    ),
                    Expanded(
                      child: _SeasonStat(
                        caption: t.routeStatDuration,
                        value: _fmtDuration(t, seasonMin),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        for (final SeaTripLog x in trips) _TripCard(trip: x),
      ],
    );
  }
}

/// Sezon kartı hücresi: küçük başlık + belirgin beyaz değer.
class _SeasonStat extends StatelessWidget {
  const _SeasonStat({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            caption,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFB8CBE0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// SÜREN SEYİR kartı: başlangıç bilgisi + "Seyri bitir" — rota kartı
/// kapansa/sayfa yenilense bile seyir buradan bitirilebilir.
class _ActiveTripCard extends ConsumerWidget {
  const _ActiveTripCard({required this.active});

  final ActiveTrip active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime s = DateTime.fromMillisecondsSinceEpoch(active.startMs);
    final String started = '${s.day}.${s.month}.${s.year} · '
        '${s.hour.toString().padLeft(2, '0')}:'
        '${s.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DocklyColors.brandPrimary.withValues(alpha: 0.08),
        border: Border.all(
          color: DocklyColors.brandPrimary.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const DocklyIcon(DocklyIcons.sailing,
                  size: 16, color: DocklyColors.brandPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${t.tripActiveLabel} — ${active.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            L10n.fmt(t.tripStartedFmt, started),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey<String>('trip-finish-deck'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () async {
                final SeaTripLog? trip =
                    await ref.read(activeTripProvider.notifier).finish();
                if (trip == null || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.tripSavedSnack)),
                );
              },
              child: Text(t.tripFinishBtn),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tamamlanan seyir kartı: ad + tarih + gerçek süre + plan mesafesi (≈).
class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip});

  final SeaTripLog trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(trip.endMs);
    final String date = '${d.day}.${d.month}.${d.year}';
    final String stats = <String>[
      _TripsTab._fmtDuration(t, trip.durationMin),
      if (trip.distanceNm > 0)
        '≈ ${_TripsTab._fmtNm(trip.distanceNm)} ${t.nmUnit}',
      if (trip.stops > 0) '${t.routeStatStops}: ${trip.stops}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(date,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: DocklyColors.brandPrimary,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(trip.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(stats, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: t.tripDeleteTooltip,
            icon: DocklyIcon(DocklyIcons.deleteOutline,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () =>
                ref.read(tripLogProvider.notifier).remove(trip.id),
          ),
        ],
      ),
    );
  }
}

/// Segment çipi — Defter içi sekme (Rotalarım / Notlar).
class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? DocklyColors.brandPrimary.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? DocklyColors.brandPrimary.withValues(alpha: 0.5)
                : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? DocklyColors.brandPrimary : null,
          ),
        ),
      ),
    );
  }
}

class _RoutesTab extends ConsumerWidget {
  const _RoutesTab({required this.tourDemo});

  final bool tourDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<SavedRoute> routes = ref.watch(savedRoutesProvider);
    if (routes.isEmpty && !tourDemo) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.savedEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: <Widget>[
        if (tourDemo)
          KeyedSubtree(
            key: tourKeySavedDemo,
            child: const _DeckDemoRouteCard(),
          ),
        for (final SavedRoute r in routes) SavedRouteCard(route: r),
      ],
    );
  }
}

/// ÖRNEKLİ TUR kartı (Defter adımı): gerçek karta birebir benzer, ÖRNEK
/// rozetlidir, dokunulamaz ve kalıcı değildir. Mesafe gerçek kuş uçuşudur.
class _DeckDemoRouteCard extends ConsumerWidget {
  const _DeckDemoRouteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final SavedRoute demo = SavedRoute(
      id: 'tour-demo-route',
      // "Göcek" özel addır — çevrilmez (koy isimleri kuralı).
      name: t.tourDemoRouteName,
      origin: const RouteOrigin(pos: kTourDemoOrigin, name: 'Göcek'),
      waypoints: <RouteWaypoint>[
        RouteWaypoint(pos: kTourDemoDest, name: t.tourDemoStop),
      ],
      distanceNm: haversineNm(kTourDemoOrigin, kTourDemoDest),
      savedAtMs: 0,
    );
    return Stack(
      children: <Widget>[
        IgnorePointer(child: SavedRouteCard(route: demo)),
        Positioned(
          top: 6,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DocklyColors.brandPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t.tourDemoBadge,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
