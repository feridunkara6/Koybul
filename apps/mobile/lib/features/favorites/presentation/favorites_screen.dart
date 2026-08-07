import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/saved_route.dart';
import '../../route/presentation/saved_routes_screen.dart' show SavedRouteCard;
import '../application/favorites_controller.dart';
import '../domain/favorite_location.dart';

/// KAYITLARIM ekranı (misafir/yerel; v2.0'da sekmeden Profil'e indi). İKİ
/// BÖLÜM (kullanıcı isteği 2026-08): KAYITLI ROTALAR + FAVORİ YERLER (kalp
/// ile eklenen limanlar). İkisi de boşsa nasıl eklenir bilgisi. Geçiş dönemi
/// bitince rotalar yalnız Defter'de kalacak, burası favori yerlere ayrılacak.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<FavoriteLocation> favorites = ref.watch(favoritesProvider);
    final List<SavedRoute> routes = ref.watch(savedRoutesProvider);
    // NOT (v2.0, 2026-08): turun örnek rota kartı artık DEFTER sekmesinde
    // (deck_screen.dart) — buradaki eski kanca kaldırıldı; aynı GlobalKey
    // iki yerde yaşayamaz (çift-anahtar çökmesi riski).
    return Scaffold(
      appBar: AppBar(title: Text(t.navFavorites)),
      body: (favorites.isEmpty && routes.isEmpty)
          ? const _EmptyFavorites()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                if (routes.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: t.savedRoutesTitle),
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
