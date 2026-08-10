import 'package:dockly_api/dockly_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/flavor.dart';
import 'l10n/app_locale.dart';

/// Uygulama-geneli çekirdek sağlayıcılar (docs/26 §4). Feature modülleri bunlara
/// bağlanır; böylece bootstrap ↔ feature döngüsel bağımlılığı oluşmaz.

/// Kökten enjekte edilen yapılandırma (bootstrap override eder).
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider override edilmeli'),
);

/// Config'e bağlı Dio istemcisi. Seçili uygulama dilini Accept-Language ile
/// sunucuya iletir (sunucu koy açıklamalarını bu dilde döner — location_i18n).
/// Dil değişince istemci yeniden kurulur; ona bağlı tüm sağlayıcılar (detay,
/// arama, hava) kendiliğinden yeni dille tazelenir.
final Provider<DocklyClient> docklyClientProvider = Provider<DocklyClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final AppLocale locale = ref.watch(appLocaleProvider);
  final DocklyClient client =
      DocklyClient(baseUrl: config.apiBaseUrl, locale: locale.name);
  // Dil değişiminde eski istemci kibarca kapanır (bekleyen istek biter, yenisi açılmaz).
  ref.onDispose(() => client.dio.close());
  return client;
});

/// Auth API istemcisi.
final Provider<AuthApi> authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(docklyClientProvider).dio);
});

/// Lokasyon (harita/nearby/detay) API istemcisi — anonim uçlar.
final Provider<LocationsApi> locationsApiProvider = Provider<LocationsApi>((ref) {
  return LocationsApi(ref.watch(docklyClientProvider).dio);
});

/// Topluluk (Kaptan Notları, yorum yazma, şikâyet) API istemcisi.
/// Okuma uçları anonim; yazma uçları access token ister.
final Provider<CommunityApi> communityApiProvider = Provider<CommunityApi>((ref) {
  return CommunityApi(ref.watch(docklyClientProvider).dio);
});

/// Denizci profili (seviye, puan, rozet, katkı dökümü) ve moderasyon
/// istemcisi. TÜM uçları hesap ister; misafirde çağrılmaz.
final Provider<ReputationApi> reputationApiProvider = Provider<ReputationApi>((ref) {
  return ReputationApi(ref.watch(docklyClientProvider).dio);
});

/// Rüzgâr/hava tahmini API istemcisi — anonim uç (MET Norway, sunucu proksili).
final Provider<WeatherApi> weatherApiProvider = Provider<WeatherApi>((ref) {
  return WeatherApi(ref.watch(docklyClientProvider).dio);
});
