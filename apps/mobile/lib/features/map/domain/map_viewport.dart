import 'package:dockly_api/dockly_api.dart';

/// Haritanın o anki görünümü — sunucuya gidecek bbox + zoom (docs/23 §9.5).
/// Değer nesnesi: aynı görünüm için tekrar yükleme yapılmasın diye eşitlik taşır.
class MapViewport {
  const MapViewport({required this.bbox, required this.zoom});

  final Bbox bbox;
  final int zoom;

  @override
  bool operator ==(Object other) =>
      other is MapViewport &&
      other.zoom == zoom &&
      other.bbox.minLon == bbox.minLon &&
      other.bbox.minLat == bbox.minLat &&
      other.bbox.maxLon == bbox.maxLon &&
      other.bbox.maxLat == bbox.maxLat;

  @override
  int get hashCode =>
      Object.hash(zoom, bbox.minLon, bbox.minLat, bbox.maxLon, bbox.maxLat);
}

/// Haritaya "bu noktaya odaklan" isteği. `seq` her istekte artar — yüzey aynı
/// noktaya ikinci kez odaklanma isteğini de ayırt edebilsin (değer eşitliği
/// yüzünden yutulmasın). Kaynak: "Konumum" düğmesi ve açılıştaki seyir
/// bölgesi seçimi (onaylı tasarım E5, 2026-08).
class MapFocusRequest {
  const MapFocusRequest({required this.point, required this.seq, this.zoom});

  final GeoPoint point;
  final int seq;

  /// İstenen yakınlaştırma — null ise yüzey varsayılanı uygular
  /// (en az 12: "Konumum" davranışı). Bölge odağı 9 kullanır (körfez ölçeği).
  final double? zoom;
}
