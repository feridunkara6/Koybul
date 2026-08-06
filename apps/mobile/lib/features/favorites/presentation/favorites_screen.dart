import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/presentation/tour_targets.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/saved_route.dart';
import '../../route/domain/sea_route.dart' show haversineNm;
import '../../route/domain/sea_trip.dart';
import '../../route/presentation/saved_routes_screen.dart' show SavedRouteCard;
import '../application/favorites_controller.dart';
import '../domain/favorite_location.dart';

/// Favoriler sekmesi (misafir/yerel). İKİ BÖLÜM (kullanıcı isteği 2026-08):
/// KAYITLI ROTALAR (haritada yer imiyle kaydedilenler) + FAVORİ YERLER
/// (kalp ile eklenen limanlar). İkisi de boşsa nasıl eklenir bilgisi.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<FavoriteLocation> favorites = ref.watch(favoritesProvider);
    final List<SavedRoute> routes = ref.watch(savedRoutesProvider);
    // ÖRNEKLİ TUR (kullanıcı isteği 2026-08): turun Kayıtlarım adımında
    // ekran boş kalmaz — ÖRNEK rozetli bir rota kartı gösterilir. Kalıcı
    // hiçbir şey yazılmaz; adım geçince kart kaybolur.
    final bool tourDemo = ref.watch(onboardingControllerProvider
            .select((OnboardingState s) => s.tourStep)) ==
        kTourStepSaved;
    return Scaffold(
      appBar: AppBar(title: Text(t.navFavorites)),
      body: (favorites.isEmpty && routes.isEmpty && !tourDemo)
          ? const _EmptyFavorites()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                if (tourDemo) ...<Widget>[
                  _SectionHeader(title: t.savedRoutesTitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: KeyedSubtree(
                      key: tourKeySavedDemo,
                      child: const _TourDemoRouteCard(),
                    ),
                  ),
                ],
                if (routes.isNotEmpty) ...<Widget>[
                  if (!tourDemo) _SectionHeader(title: t.savedRoutesTitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: <Widget>[
                        for (final SavedRoute r in routes)
                          SavedRouteCard(route: r),
                      ],
                    ),
                  ),
                ],
                if (favorites.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: t.favSectionPlaces),
                  for (int i = 0; i < favorites.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    _FavoriteTile(favorite: favorites[i]),
                  ],
                ],
              ],
            ),
    );
  }
}

/// ÖRNEKLİ TUR kartı: gerçek karta birebir benzer ama ÖRNEK rozetlidir ve
/// dokunulamaz (tur karartması zaten dokunuşu keser; IgnorePointer emniyet).
/// Mesafe uydurma değildir — uçlar arasındaki gerçek kuş uçuşudur.
class _TourDemoRouteCard extends ConsumerWidget {
  const _TourDemoRouteCard();

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
          child: _TourDemoBadge(label: t.tourDemoBadge),
        ),
      ],
    );
  }
}

/// "ÖRNEK" rozeti — turdaki örnek içerik gerçek veriyle karışmasın.
class _TourDemoBadge extends StatelessWidget {
  const _TourDemoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DocklyColors.brandPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Bölüm başlığı — "Kayıtlı Rotalar" / "Favori yerler".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: DocklyColors.text2,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.favorite});

  final FavoriteLocation favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String subtitle = <String>[
      ref.watch(l10nProvider).typeLabel(favorite.type),
      if (favorite.city != null) favorite.city!,
    ].join(' · ');
    return ListTile(
      leading: DocklyTypeAvatar(type: favorite.type),
      title: Text(favorite.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: ref.watch(l10nProvider).favRemoveTooltip,
        icon: const DocklyIcon(DocklyIcons.favorite, color: DocklyColors.error),
        onPressed: () => ref.read(favoritesProvider.notifier).remove(favorite.id),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => LocationDetailScreen(idOrSlug: favorite.id),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends ConsumerWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const DocklyIcon(DocklyIcons.favoriteBorder, size: 48, color: DocklyColors.brandPrimary),
            const SizedBox(height: 12),
            Text(
              ref.watch(l10nProvider).favEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
