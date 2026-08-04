import 'dart:typed_data';

import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter/services.dart' show rootBundle;

/// TÜRK KARASULARI TERCİHİ ızgarası (kaptan kuralı, 2026-08).
///
/// Kaynak: Natural Earth 10m ülke sınırları (KAMU MALI) — üretim:
/// apps/mobile/tool/generate_tr_waters_grid.py. Her ~2 km hücre için iki bilgi:
///  · Türk karasına kuş uçuşu uzaklık (nm, 63,5'te doyar) — bit 0-6 (×2)
///  · "Yunan tarafı" bayrağı: Yunan karası Türk karasından DAHA YAKIN — bit 7
///
/// SINIR ÇİZMEZ: bu veri resmî karasuları/sınır iddiası değildir; yalnız
/// "hangi kıyıya daha yakın" geometrisidir ve rota TERCİHİ (yasak değil,
/// yumuşak maliyet) için kullanılır. Hedef Yunan adasıysa tercih kapanır.
///
/// Dosya biçimi: 'KYBTR2' + 5×double LE (lon0, lat0, lon1, lat1, çözünürlük)
/// + 2×int32 LE (sütun, satır) + satır-satır bayt ızgarası (üst satır kuzey).
class TrCoastGrid {
  TrCoastGrid._({
    required this.lon0,
    required this.lat0,
    required this.lon1,
    required this.lat1,
    required this.res,
    required this.width,
    required this.height,
    required Uint8List cells,
  }) : _cells = cells;

  final double lon0, lat0, lon1, lat1, res;
  final int width, height;
  final Uint8List _cells;

  static const String assetPath = 'assets/route/tr_coast_dist.bin';
  static const List<int> _magic = <int>[0x4B, 0x59, 0x42, 0x54, 0x52, 0x32]; // KYBTR2

  static Future<TrCoastGrid?> load() async {
    try {
      final ByteData d = await rootBundle.load(assetPath);
      return parse(d);
    } catch (_) {
      return null;
    }
  }

  static TrCoastGrid? parse(ByteData d) {
    if (d.lengthInBytes < 6 + 48 + 1) return null;
    for (int i = 0; i < 6; i++) {
      if (d.getUint8(i) != _magic[i]) return null;
    }
    const int o = 6;
    final double lon0 = d.getFloat64(o, Endian.little);
    final double lat0 = d.getFloat64(o + 8, Endian.little);
    final double lon1 = d.getFloat64(o + 16, Endian.little);
    final double lat1 = d.getFloat64(o + 24, Endian.little);
    final double res = d.getFloat64(o + 32, Endian.little);
    final int w = d.getInt32(o + 40, Endian.little);
    final int h = d.getInt32(o + 44, Endian.little);
    if (w <= 0 || h <= 0 || res <= 0) return null;
    if (d.lengthInBytes - (o + 48) < w * h) return null;
    return TrCoastGrid._(
      lon0: lon0, lat0: lat0, lon1: lon1, lat1: lat1, res: res,
      width: w, height: h,
      cells: Uint8List.sublistView(
          d.buffer.asUint8List(d.offsetInBytes), o + 48),
    );
  }

  int _byteAt(double lat, double lon) {
    int cx = ((lon - lon0) / res).floor();
    int cy = ((lat1 - lat) / res).floor();
    if (cx < 0) cx = 0;
    if (cy < 0) cy = 0;
    if (cx >= width) cx = width - 1;
    if (cy >= height) cy = height - 1;
    return _cells[cy * width + cx];
  }

  /// Türk karasına kuş uçuşu uzaklık (nm; 63,5'te doyar).
  double distTrNm(GeoPoint p) => (_byteAt(p.lat, p.lon) & 0x7F) / 2.0;

  /// Yunan karası Türk karasından daha mı yakın? ("Yunan tarafı")
  bool greekSide(GeoPoint p) => (_byteAt(p.lat, p.lon) & 0x80) != 0;

  /// Izgara koordinatıyla hızlı erişim (A* iç döngüsü için).
  bool greekSideAt(double lat, double lon) => (_byteAt(lat, lon) & 0x80) != 0;
}
