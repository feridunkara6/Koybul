import 'package:dockly_api/dockly_api.dart' show FavoriteBoatRef;

/// FAVORİLE geçidi (TK-5, kurucu onayı 2026-10-30) — testlerde sahteyle
/// değiştirilebilsin diye ince arayüz (takip/marina geçitleriyle aynı desen).
abstract class FavoritesGateway {
  /// Kişinin favori listesi — yalnız HÂLÂ görünür tekneler iner.
  Future<List<FavoriteBoatRef>> favorites();

  /// İdempotent; görünmez/kendi teknesi sunucuda `not-found` alır.
  Future<void> favorite(String boatId);

  Future<void> unfavorite(String boatId);
}
