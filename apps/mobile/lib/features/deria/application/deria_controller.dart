import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/api_deria_gateway.dart';
import '../domain/deria_gateway.dart';

/// Ağ geçidi sağlayıcısı — testte sahte ile override edilir.
final Provider<DeriaGateway> deriaGatewayProvider = Provider<DeriaGateway>(
  (ref) => ApiDeriaGateway(DeriaApi(ref.watch(docklyClientProvider).dio)),
);

/// Göstergenin bayatlık tavanı. Sunucu zaten 30 dk'dan eski veri SUNMAZ;
/// burası ikinci emniyettir (istemci saati/önbelleği için).
const Duration kDeriaMaxAge = Duration(minutes: 45);

/// DERİA doluluk verisi — tüm koylar tek istekte gelir (sunucuda 5 dk
/// önbellekli). Detay ekranı kendi slug'ını `forSlug` ile süzer.
///
/// Hata = null yerine hata yayılır ama TÜKETİCİ `valueOrNull` ile okur:
/// doluluk süsleme verisidir, detay sayfasını asla kırmaz.
final deriaAvailabilityProvider =
    FutureProvider.autoDispose<DeriaAvailability>((ref) async {
  // keepAlive/Timer AWAIT'TEN ÖNCE kurulur (inceleme bulgusu): istek uçuştayken
  // ekran kapanırsa sağlayıcı düşer; await SONRASI ref kullanmak StateError
  // fırlatırdı. Timer + cancel ayrıca "bekleyen zamanlayıcı" CI dersini uygular
  // (iptal edilemeyen Future.delayed testleri kırar).
  final KeepAliveLink link = ref.keepAlive();
  final Timer timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  try {
    // Önbelleğin ömrü: 5 dk sonra kendiliğinden düşer (yeni bakışta tazelenir).
    return await ref.watch(deriaGatewayProvider).availability();
  } catch (_) {
    // Hata önbelleğe 5 dk kilitlenmesin: bir sonraki bakış yeniden denesin.
    timer.cancel();
    link.close();
    rethrow;
  }
});

/// Bir kaydın gösterilebilir doluluğu; yoksa/bayatsa null → kutu çizilmez.
DeriaCove? deriaCoveFor(DeriaAvailability? a, String slug, DateTime now) {
  if (a == null) return null;
  if (now.difference(a.fetchedAt) > kDeriaMaxAge) return null;
  return a.forSlug(slug);
}
