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

/// DEFTER sekmesi v0 (v2.0 vizyonu, kurucu onayı 2026-08): denizcinin arşivi.
/// v0 = Rotalarım + Notlar (eski Günlük). "Seyirler" ve sezon kartı, seyir
/// kayıt akışıyla ("Seyri başlat/bitir") sonraki pakette gelir — boş vaat
/// sekmesi ÇİZİLMEZ (0-uydurma ilkesinin arayüz hali).
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  int _seg = 0; // 0 = Rotalarım · 1 = Notlar

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    // ÖRNEKLİ TUR: Defter adımında Rotalarım segmenti gösterilir ve ÖRNEK
    // rozetli kart eklenir (kalıcı değildir; adım geçince kaybolur).
    final bool tourDemo = ref.watch(onboardingControllerProvider
            .select((OnboardingState s) => s.tourStep)) ==
        kTourStepSaved;
    final int seg = tourDemo ? 0 : _seg;
    return Scaffold(
      appBar: AppBar(title: Text(t.navDeck)),
      // Not ekleme yalnız Notlar segmentinde (heroTag: Günlük ekranındaki
      // FAB ile Hero çakışması olmasın — ikisi de açık olabilir).
      floatingActionButton: seg == 1
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
                  label: t.deckTabRoutes,
                  selected: seg == 0,
                  onTap: () => setState(() => _seg = 0),
                ),
                const SizedBox(width: 8),
                _SegChip(
                  label: t.deckTabNotes,
                  selected: seg == 1,
                  onTap: () => setState(() => _seg = 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: seg == 0
                ? _RoutesTab(tourDemo: tourDemo)
                : const LogbookBody(),
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
