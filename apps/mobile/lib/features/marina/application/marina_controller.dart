import 'package:dockly_api/dockly_api.dart' show MarinaCommunity, MyMarinaBoat;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_marina_gateway.dart';
import '../domain/marina_gateway.dart';

/// MARİNA TOPLULUĞU orkestrasyonu (V1 — kurucu onayı 2026-10-23).
///
/// KATILIM AÇIK RIZAYLA olur: telefondaki tekne kendiliğinden sunucuya
/// gönderilmez; kullanıcı Marinam kartındaki "Topluluğa katıl" düğmesine
/// basınca kaydedilir (KVKK dostu varsayılan). Görünürlük ve paylaşım
/// anahtarları da sunucuda tutulur — tek doğruluk kaynağı sunucudur.

final Provider<MarinaGateway> marinaGatewayProvider = Provider<MarinaGateway>((ref) {
  return ApiMarinaGateway(
    ref.watch(marinaApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Sunucuya kayıtlı teknem — Marinam kartının doğruluk kaynağı.
/// autoDispose: sekmeden çıkınca salınır; katılım/anahtar sonrası invalidate.
final AutoDisposeFutureProvider<MyMarinaBoat?> myServerBoatProvider =
    FutureProvider.autoDispose<MyMarinaBoat?>((ref) {
  return ref.watch(marinaGatewayProvider).myBoat();
});

/// Marina topluluğu (sayılar + erişime göre liste) — marina kimliğiyle aile.
final AutoDisposeFutureProviderFamily<MarinaCommunity, String> marinaCommunityProvider =
    FutureProvider.autoDispose.family<MarinaCommunity, String>((ref, String locationId) {
  return ref.watch(marinaGatewayProvider).community(locationId);
});

/// Yerel tekne tipi kodu → sunucu sözlüğü (boat_types.code).
/// Bilinmeyen/boş tip null döner — UYDURMA TİP GÖNDERİLMEZ; katılım, kullanıcı
/// tip seçene dek kibarca bekletilir.
String? serverBoatTypeCode(String? localTypeId) {
  switch (localTypeId) {
    case 'sail':
      return 'sailboat';
    case 'motor':
      return 'motor_yacht';
    case 'catamaran':
      return 'catamaran';
    case 'gulet':
      return 'gulet';
    // KATALOG GENİŞLEMESİ (2026-10-23): sözlük 8 türe tamamlandı.
    case 'daily':
      return 'daily_boat';
    case 'fishing':
      return 'fishing_boat';
    case 'rib':
      return 'rib';
    case 'super':
      return 'superyacht';
    default:
      return null;
  }
}
