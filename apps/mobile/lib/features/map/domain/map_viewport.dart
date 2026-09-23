import 'package:dockly_api/dockly_api.dart';

/// Sunucunun kabul ettiği en büyük bbox kenarı 5° (docs/23 §9.5) — istemci
/// güvenli payla 4.8° ister. GERÇEK CİHAZ DERSİ (2026-09, TestFlight testi):
/// telefonda açılış kamerası tüm Türkiye'yi gösterir (~11°); ham görünümü
/// olduğu gibi gönderince sunucu 422 "Geçersiz bbox" döndürüyor ve harita
/// hiç dolmuyordu. Görünüm MERKEZİNDEN kırpılır — uzak kenar balonları o
/// yakınlıkta zaten okunmaz; kullanıcı yaklaştıkça tam veri gelir.
const double kMaxBboxEdgeDegrees = 4.8;

/// Haritanın o anki görünümü — sunucuya gidecek bbox + zoom (docs/23 §9.5).
/// Değer nesnesi: aynı görünüm için tekrar yükleme yapılmasın diye eşitlik taşır.
class MapViewport {
  const MapViewport({required this.bbox, required this.zoom});

  final Bbox bbox;
  final int zoom;

  /// ÖNDEN GENİŞ GETİRME (perf, kurucu bulgusu 2026-09-23: "kaydırınca
  /// noktalar beklemeden dolmalı"): sunucudan görünenden [factor] kat geniş
  /// alan istenir — küçük kaydırmalar bu alanın İÇİNDE kaldığı sürece ağa hiç
  /// çıkılmaz, noktalar bellekten anında gelir. Kenarlar yine sunucu tavanını
  /// ([maxEdgeDegrees]) aşmaz; merkez sabittir.
  MapViewport expandedForFetch({
    double factor = 1.7,
    double maxEdgeDegrees = kMaxBboxEdgeDegrees,
  }) {
    final double lonSpan = bbox.maxLon - bbox.minLon;
    final double latSpan = bbox.maxLat - bbox.minLat;
    double newLon = lonSpan * factor;
    double newLat = latSpan * factor;
    if (newLon > maxEdgeDegrees) newLon = maxEdgeDegrees;
    if (newLat > maxEdgeDegrees) newLat = maxEdgeDegrees;
    // 1e-9 payı KAYAN NOKTA TOZU içindir (CI dersi 2026-09-24): 34.8-30.0
    // gibi farklar tam 4.8 çıkmaz (4.7999...97) ve tavandaki görünüm boşu
    // boşuna yeniden kurulurdu — eşitlik bozulur, gereksiz yükleme doğardı.
    if (newLon <= lonSpan + 1e-9 && newLat <= latSpan + 1e-9) return this;
    final double cLon = (bbox.minLon + bbox.maxLon) / 2;
    final double cLat = (bbox.minLat + bbox.maxLat) / 2;
    return MapViewport(
      zoom: zoom,
      bbox: Bbox(
        minLon: cLon - newLon / 2,
        maxLon: cLon + newLon / 2,
        minLat: cLat - newLat / 2,
        maxLat: cLat + newLat / 2,
      ),
    );
  }

  /// Sunucu tavanına sığan görünüm: kenarlardan biri [maxEdgeDegrees]'i
  /// aşıyorsa bbox MERKEZİ SABİT kalarak o eksende kırpılır; sığıyorsa
  /// nesne OLDUĞU GİBİ döner (eşitlik bozulmaz, gereksiz yeniden yükleme yok).
  MapViewport clamped({double maxEdgeDegrees = kMaxBboxEdgeDegrees}) {
    final double lonSpan = bbox.maxLon - bbox.minLon;
    final double latSpan = bbox.maxLat - bbox.minLat;
    if (lonSpan <= maxEdgeDegrees && latSpan <= maxEdgeDegrees) return this;

    final double half = maxEdgeDegrees / 2;
    final double cLon = (bbox.minLon + bbox.maxLon) / 2;
    final double cLat = (bbox.minLat + bbox.maxLat) / 2;
    return MapViewport(
      zoom: zoom,
      bbox: Bbox(
        minLon: lonSpan > maxEdgeDegrees ? cLon - half : bbox.minLon,
        maxLon: lonSpan > maxEdgeDegrees ? cLon + half : bbox.maxLon,
        minLat: latSpan > maxEdgeDegrees ? cLat - half : bbox.minLat,
        maxLat: latSpan > maxEdgeDegrees ? cLat + half : bbox.maxLat,
      ),
    );
  }

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
