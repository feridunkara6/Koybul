/// Teknenin BAĞLI OLDUĞU marina (kullanıcı isteği 2026-08: "tekne tanıtırken
/// bağlı olduğu marinayı da sorsun; marina çevresine odaklanabiliriz").
/// Koordinat, seçim anında lokasyon kaydından kopyalanır — açılışta harita
/// bu noktaya odaklanır (GPS yoksa). Kimlik, ileride detay sayfasına
/// bağlamak için saklanır.
class HomeMarina {
  const HomeMarina({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
}

/// Kullanıcının teknesi — hafif, oturum içi model (docs/01-prd §6.2 basitleştirilmiş).
/// Kalıcılık (cihazda hatırlama) bir sonraki küçük adımda eklenecek.
class MyBoat {
  const MyBoat({
    required this.lengthM,
    this.draftM,
    this.brand,
    this.typeId,
    this.name,
    this.homeMarina,
    this.model,
    this.buildYear,
  });

  /// Tekne boyu (m) — zorunlu. İÇ BİRİM her zaman metredir (uyum hesapları
  /// metre üzerinden); karşılama ekranı denizci diliyle FEET sorar ve çevirir.
  final double lengthM;

  /// Su çekimi (m) — opsiyonel (bilinmiyorsa null).
  final double? draftM;

  /// Tekne markası (ör. Beneteau) — opsiyonel, kişiselleştirme için.
  final String? brand;

  /// Tekne tipi kimliği — opsiyonel. KATALOG GENİŞLEMESİ (kurucu onayı
  /// 2026-10-23): sözlük sunucudaki 8 türe tamamlandı — `kBoatTypeIds`.
  /// Eski kayıtlardaki 'sail'|'motor'|'catamaran'|'gulet' aynen geçerlidir.
  final String? typeId;

  /// Teknenin adı (ör. "Martı") — opsiyonel, kişiselleştirme için
  /// (kullanıcı isteği 2026-08).
  final String? name;

  /// Bağlı olduğu marina — opsiyonel. Verilirse harita açılışta bu çevreye
  /// odaklanır (GPS paylaşılmadıysa).
  final HomeMarina? homeMarina;

  /// Model adı (ör. "Oceanis 38.1") — opsiyonel, SERBEST yazı, beyana dayalı
  /// (kurucu onayı 2026-10-23: doğrulanmamış model doğrulanmış gibi sunulmaz).
  final String? model;

  /// Model yılı — opsiyonel. Eski/klasik tekneler dâhil her yıl geçerlidir;
  /// bilinmiyorsa null ("Bilmiyorum" her zaman geçerli bir cevaptır).
  final int? buildYear;
}

/// Tekne türü sözlüğü — SUNUCU sözlüğüyle bire bir ayna (8 tür). Sıra,
/// seçim çiplerinin ekrandaki sırasıdır.
const List<String> kBoatTypeIds = <String>[
  'sail',
  'motor',
  'catamaran',
  'gulet',
  'daily',
  'fishing',
  'rib',
  'super',
];

/// Tür simgesi (illüstrasyon ve çiplerde kullanılan emoji — kendi seçimimiz,
/// lisans derdi olmayan evrensel glifler).
String boatTypeEmoji(String? typeId) {
  switch (typeId) {
    case 'motor':
    case 'super':
      return '🛥️';
    case 'daily':
      return '🚤';
    case 'fishing':
      return '🎣';
    case 'rib':
      return '🛟';
    default:
      return '⛵'; // sail, catamaran, gulet ve bilinmeyen
  }
}

/// Model yılı sınırları — 1850'den (klasikler) gelecek yıla.
const int kBoatYearMin = 1850;
const int kBoatYearMax = 2027;

/// Feet → metre (uluslararası sabit: 1 ft = 0.3048 m), 1 ondalığa yuvarlanır.
double feetToMeters(double feet) => (feet * 0.3048 * 10).roundToDouble() / 10;

/// Bir lokasyona tekne uygunluğu (docs/01-prd §6.5 tekne uyumu).
enum BoatFit { fits, tooBig, unknown }

/// Tekne boy/su çekimini lokasyonun limitleriyle karşılaştırır.
/// - Tekne tanımsızsa ya da lokasyonun hiçbir limiti bilinmiyorsa → `unknown`.
/// - Bilinen bir limit aşılıyorsa → `tooBig`.
/// - Bilinen limitlerin hiçbiri aşılmıyorsa → `fits`.
BoatFit computeBoatFit({
  required MyBoat? boat,
  required double? maxBoatLengthM,
  required double? maxDraftM,
}) {
  if (boat == null) return BoatFit.unknown;
  if (maxBoatLengthM == null && maxDraftM == null) return BoatFit.unknown;
  if (maxBoatLengthM != null && boat.lengthM > maxBoatLengthM) return BoatFit.tooBig;
  if (maxDraftM != null && boat.draftM != null && boat.draftM! > maxDraftM) {
    return BoatFit.tooBig;
  }
  return BoatFit.fits;
}

/// Marka ÖNERİ listesi (katalog Katman 1, kurucu onayı 2026-10-23).
/// Yol gösterir ama SINIRLAMAZ — serbest yazı her zaman geçerlidir. Yaygın
/// üreticiler + Türk tersaneleri; alfabetik değil, kullanım sıklığına yakın.
const List<String> kBoatBrandSuggestions = <String>[
  'Beneteau', 'Jeanneau', 'Bavaria', 'Hanse', 'Dufour', 'Elan',
  'X-Yachts', 'Hallberg-Rassy', 'Najad', 'Moody', 'Westerly', 'Dehler',
  'Grand Soleil', 'Catalina', 'Hunter', 'Comet', 'Sun Odyssey', 'Oceanis',
  'Azimut', 'Princess', 'Sunseeker', 'Ferretti', 'Fairline', 'Sealine',
  'Galeon', 'Cranchi', 'Bayliner', 'Sea Ray', 'Quicksilver', 'Jeanneau Cap Camarat',
  'Lagoon', 'Fountaine Pajot', 'Leopard', 'Bali', 'Nautitech', 'Excess',
  'Zodiac', 'Highfield', 'Brig', 'Grand', 'Boston Whaler', 'Marlin',
  'Vicem', 'Numarine', 'Mengi Yay', 'Sirena', 'Azuree', 'Aegean Yacht',
];
