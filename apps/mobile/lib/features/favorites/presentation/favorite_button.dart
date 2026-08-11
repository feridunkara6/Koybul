import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/favorites_controller.dart';
import '../domain/favorite_location.dart';

/// Bir lokasyonu favorilere ekleyip çıkaran kalp düğmesi (detay ekranı başlığı).
/// Favoriyse dolu kırmızı kalp, değilse çizgi kalp gösterir.
///
/// ÜYELİK KAPISI KALDIRILDI (Faz 1, denetim bulgusu). Eski davranış bir söz
/// veriyordu: "giriş yap, listen her cihazında seninle olur". Bu söz doğru
/// değildi — favoriler yalnızca telefonda, `favorites.v1` anahtarında
/// duruyor; sunucuya hiç gönderilmiyor (gizlilik metnimiz de bunu böyle
/// yazıyor). Yani kullanıcı hiç almadığı bir şeyin bedelini ödüyordu ve bunu
/// ilk iki dakikada, en kritik anda ödüyordu.
///
/// Doğrusu ikisinden biriydi: ya sözü tut (sunucuya taşı), ya kapıyı kaldır.
/// Sunucuya taşımak Faz 4 işi (hesap-veri göçü); kapıyı kaldırmak bugün
/// doğru olan. Favori artık hesapsız çalışır ve arayüz cihazda kaldığını
/// açıkça söyler.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({required this.favorite, super.key});

  final FavoriteLocation favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFav = ref.watch(
      favoritesProvider.select(
        (List<FavoriteLocation> list) =>
            list.any((FavoriteLocation f) => f.id == favorite.id),
      ),
    );
    void toggleAndNotify() {
      final FavoritesController controller = ref.read(favoritesProvider.notifier);
      controller.toggle(favorite);
      final bool nowFav = controller.isFavorite(favorite.id);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(nowFav
                ? ref.read(l10nProvider).favAdded
                : ref.read(l10nProvider).favRemoved),
            duration: const Duration(seconds: 2),
          ),
        );
    }

    return IconButton(
      tooltip: isFav ? 'Favorilerden çıkar' : 'Favorilere ekle',
      icon: DocklyIcon(
        isFav ? DocklyIcons.favorite : DocklyIcons.favoriteBorder,
        color: isFav ? DocklyColors.error : null,
      ),
      onPressed: toggleAndNotify,
    );
  }
}
