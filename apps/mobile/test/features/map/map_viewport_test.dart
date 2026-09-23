import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

/// SUNUCU BBOX TAVANI (gerçek cihaz dersi 2026-09, TestFlight testi):
/// telefonda açılış kamerası tüm Türkiye'yi gösterir; ham bbox 5° sunucu
/// sınırını aşınca 422 dönüyor ve harita HİÇ dolmuyordu. Sözleşme: görünüm
/// merkez sabit kalarak tavana kırpılır; sığan görünüm OLDUĞU GİBİ kalır.
void main() {
  test('sığan görünüm AYNI nesne döner (eşitlik bozulmaz, tekrar yükleme yok)', () {
    const MapViewport v = MapViewport(
      bbox: Bbox(minLon: 28.9, minLat: 36.7, maxLon: 29.0, maxLat: 36.8),
      zoom: 13,
    );
    expect(identical(v.clamped(), v), isTrue);
  });

  test('tüm Türkiye görünümü (açılış, ~11°) merkez sabit kalarak tavana kırpılır', () {
    // Açılış kamerası: merkez (35.2, 39.0), zoom 5 — kenarlar tavanı aşar.
    const MapViewport v = MapViewport(
      bbox: Bbox(minLon: 29.6, minLat: 35.5, maxLon: 40.8, maxLat: 42.5),
      zoom: 5,
    );
    final MapViewport c = v.clamped();
    expect(c.zoom, 5);
    // Merkez korunur.
    expect((c.bbox.minLon + c.bbox.maxLon) / 2, closeTo(35.2, 1e-9));
    expect((c.bbox.minLat + c.bbox.maxLat) / 2, closeTo(39.0, 1e-9));
    // Kenarlar tavanda (sunucu 5° kabul eder; istemci 4.8° güvenli payla ister).
    expect(c.bbox.maxLon - c.bbox.minLon, closeTo(kMaxBboxEdgeDegrees, 1e-9));
    expect(c.bbox.maxLat - c.bbox.minLat, closeTo(kMaxBboxEdgeDegrees, 1e-9));
  });

  test('expandedForFetch (perf): merkez sabit büyür, zoom korunur', () {
    const MapViewport v = MapViewport(
      bbox: Bbox(minLon: 28.9, minLat: 36.7, maxLon: 29.0, maxLat: 36.8),
      zoom: 13,
    );
    final MapViewport f = v.expandedForFetch(factor: 1.35);
    expect(f.zoom, 13);
    expect((f.bbox.minLon + f.bbox.maxLon) / 2, closeTo(28.95, 1e-9));
    expect((f.bbox.minLat + f.bbox.maxLat) / 2, closeTo(36.75, 1e-9));
    expect(f.bbox.maxLon - f.bbox.minLon, closeTo(0.135, 1e-9));
    // Görüneni kapsar.
    expect(f.bbox.minLon, lessThan(v.bbox.minLon));
    expect(f.bbox.maxLat, greaterThan(v.bbox.maxLat));
  });

  test('expandedForFetch: tavandaki görünüm OLDUĞU GİBİ kalır (aynı nesne)', () {
    const MapViewport v = MapViewport(
      bbox: Bbox(minLon: 30.0, minLat: 36.0, maxLon: 34.8, maxLat: 40.8),
      zoom: 5,
    );
    expect(identical(v.expandedForFetch(), v), isTrue);
  });

  test('tek ekseni aşan görünümde diğer eksen OLDUĞU GİBİ kalır', () {
    const MapViewport v = MapViewport(
      bbox: Bbox(minLon: 26.0, minLat: 36.0, maxLon: 34.0, maxLat: 37.0),
      zoom: 6,
    );
    final MapViewport c = v.clamped();
    expect(c.bbox.maxLon - c.bbox.minLon, closeTo(kMaxBboxEdgeDegrees, 1e-9));
    expect((c.bbox.minLon + c.bbox.maxLon) / 2, closeTo(30.0, 1e-9));
    expect(c.bbox.minLat, 36.0); // enlem zaten sığıyor — dokunulmaz
    expect(c.bbox.maxLat, 37.0);
  });
}
