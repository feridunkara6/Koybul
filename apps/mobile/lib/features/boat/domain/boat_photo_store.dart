/// TEKNE FOTOĞRAFI deposu arayüzü (kurucu onayı 2026-10-23, karar A).
///
/// GİZLİLİK SÖZLEŞMESİ: fotoğraf YALNIZ CİHAZDA saklanır — sunucuya hiç
/// gitmez, marina topluluğunda veya başka kullanıcılara gösterilmez.
/// (İleride "marinada fotoğrafımı göster" açık rızasıyla sunucu yolu AYRICA
/// değerlendirilir — bu arayüz o karara ipotek koymaz.)
///
/// KORUMA SÖZLEŞMESİ: fotoğraf eklemek/değiştirmek/silmek bakım kayıtlarına,
/// tekne bilgisine ve marina kaydına DOKUNMAZ — bu depo yalnız görsel dosyayı
/// bilir, başka hiçbir veriye erişimi yoktur.
abstract interface class BoatPhotoStore {
  /// Kayıtlı fotoğrafın dosya yolu; yoksa null (tip illüstrasyonu çizilir).
  Future<String?> load();

  /// Kamera/galeriden seçtirir, cihaza kaydeder, yeni yolu döndürür.
  /// Kullanıcı vazgeçerse null döner (mevcut fotoğraf DEĞİŞMEZ).
  Future<String?> pick({required bool fromCamera});

  /// Fotoğrafı siler (tip illüstrasyonuna dönülür).
  Future<void> clear();
}
