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
  });

  /// Tekne boyu (m) — zorunlu. İÇ BİRİM her zaman metredir (uyum hesapları
  /// metre üzerinden); karşılama ekranı denizci diliyle FEET sorar ve çevirir.
  final double lengthM;

  /// Su çekimi (m) — opsiyonel (bilinmiyorsa null).
  final double? draftM;

  /// Tekne markası (ör. Beneteau) — opsiyonel, kişiselleştirme için.
  final String? brand;

  /// Tekne tipi kimliği — opsiyonel (onaylı açılış tasarımı E3, 2026-08):
  /// 'sail' | 'motor' | 'catamaran' | 'gulet'. Rüzgâr vurguları ve ileride
  /// rezervasyon ön-dolumu için saklanır; bilinmiyorsa null.
  final String? typeId;

  /// Teknenin adı (ör. "Martı") — opsiyonel, kişiselleştirme için
  /// (kullanıcı isteği 2026-08).
  final String? name;

  /// Bağlı olduğu marina — opsiyonel. Verilirse harita açılışta bu çevreye
  /// odaklanır (GPS paylaşılmadıysa).
  final HomeMarina? homeMarina;
}

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
