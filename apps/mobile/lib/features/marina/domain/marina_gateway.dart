import 'package:dockly_api/dockly_api.dart' show MarinaCommunity, MyMarinaBoat;

/// MARİNA TOPLULUĞU ağ geçidi arayüzü (V1 — kurucu onayı 2026-10-23).
/// Gerçek implementasyon `data/api_marina_gateway.dart`; testlerde sahtesi.
abstract interface class MarinaGateway {
  /// Sunucuya kayıtlı teknem (yoksa null). Hesap ister.
  Future<MyMarinaBoat?> myBoat();

  /// Tekneyi kaydet/güncelle — topluluğa katılım ve rıza anahtarları.
  /// Hafta 2: model + yapım yılı da gider (Tekne Kartı çizimi için).
  Future<MyMarinaBoat> upsertMyBoat({
    required String name,
    required String boatTypeCode,
    required double lengthM,
    String? brand,
    String? model,
    int? buildYear,
    required String marinaLocationId,
    required bool visible,
    required bool shareSpecs,
    /// 0024: hikâye yalnız [storySet] true iken gönderilir — gönderilmeyen
    /// alan sunucudaki mevcut hikâyeye dokunmaz.
    bool storySet,
    String? story,
  });

  /// Topluluk: sayılar herkese; liste sunucunun erişim kararına göre.
  Future<MarinaCommunity> community(String locationId);
}
