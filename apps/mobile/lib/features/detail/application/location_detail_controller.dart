import 'package:dockly_api/dockly_api.dart' show LocationDetail, LocationsApi;
import 'package:dockly_core/dockly_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_location_detail_gateway.dart';
import '../domain/location_detail_gateway.dart';

/// Detay ağ geçidi sağlayıcısı — testte sahte ile override edilir.
/// P4: oturum varsa istek kimlikli gider (vitrin/tam kararı sunucuda).
final Provider<LocationDetailGateway> locationDetailGatewayProvider =
    Provider<LocationDetailGateway>(
  (ref) => ApiLocationDetailGateway(
    ref.watch(locationsApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  ),
);

/// Lokasyon detayını id/slug başına getiren sağlayıcı (S-09). AsyncValue ile
/// yükleme/hata/veri durumlarını taşır; hata `AppFailure` olarak yayılır.
///
/// P4: oturum durumu İZLENİR — giriş/çıkışta detay kendiliğinden yeniden
/// çekilir (misafirken vitrin gören kullanıcı, giriş yapınca hakkı neyse onu
/// görür; ekranda bayat kilit/bayat tam veri kalmaz).
final locationDetailProvider = FutureProvider.family<LocationDetail, String>(
  (ref, String idOrSlug) {
    ref.watch(authControllerProvider);
    return ref.watch(locationDetailGatewayProvider).fetch(idOrSlug);
  },
);

/// KEŞİF HAKKI kapısı (P4, premium v3 raporu K2) — testte sahteyle değiştirilir.
abstract interface class KesifGateway {
  /// Koyu bu ay için tam açar; KALAN hak sayısını döndürür.
  /// Tavan doluysa sunucunun 403'ü `ForbiddenFailure` olarak fırlar.
  Future<int> unlock(String idOrSlug);
}

class ApiKesifGateway implements KesifGateway {
  ApiKesifGateway(this._api, this._tokenProvider);

  final LocationsApi _api;
  final Future<String?> Function() _tokenProvider;

  @override
  Future<int> unlock(String idOrSlug) async {
    final String? token = await _tokenProvider();
    if (token == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    final r = await _api.unlock(idOrSlug: idOrSlug, accessToken: token);
    return r.remaining;
  }
}

final Provider<KesifGateway> kesifGatewayProvider = Provider<KesifGateway>((ref) {
  return ApiKesifGateway(
    ref.watch(locationsApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});
