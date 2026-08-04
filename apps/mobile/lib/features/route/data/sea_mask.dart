import 'dart:typed_data';

import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter/services.dart' show rootBundle;

/// Su/kara bit haritası — deniz rotası motorunun zemini (2026-08).
///
/// Kaynak: Natural Earth 10m kara poligonları + küçük adalar (KAMU MALI).
/// Üretim: apps/mobile/tool/generate_sea_mask.py (elle düzenlenmez). Kıyı
/// çizgileri 1 hücre kalınlaştırılır: yarım-hücrelik kara parçaları kaybolmaz
/// ve rota kıyıya yapışamaz (EMNİYET PAYI). Bunun bedeli, çok dar geçitlerin
/// (ör. Kekova iç kanalı) kapalı sayılmasıdır — rota motoru bu durumda koya
/// "en yakın açık suya kadar" rota üretir; bu bilinçli, muhafazakâr bir karar.
///
/// Dosya biçimi: 6 bayt 'KYBSU1' + 5×double LE (lon0, lat0, lon1, lat1,
/// çözünürlük derece) + 2×int32 LE (sütun, satır) + bit-paketli kara maskesi
/// (bit 1 = KARA; en üst satır = kuzey; her satır (sütun+7)/8 bayta yuvarlanır;
/// bayt içinde en soldaki hücre en anlamlı bittir).
class SeaMask {
  SeaMask._({
    required this.lon0,
    required this.lat0,
    required this.lon1,
    required this.lat1,
    required this.res,
    required this.width,
    required this.height,
    required Uint8List bits,
  }) : _bits = bits,
       _stride = (width + 7) >> 3;

  final double lon0, lat0, lon1, lat1, res;
  final int width, height;
  final Uint8List _bits;
  final int _stride;

  static const String assetPath = 'assets/route/sea_mask.bin';
  static const List<int> _magic = <int>[0x4B, 0x59, 0x42, 0x53, 0x55, 0x31]; // KYBSU1

  /// Varlıktan yükler; bozuk/eksikse null (rota kuş uçuşuna düşer, akış bozulmaz).
  static Future<SeaMask?> load() async {
    try {
      final ByteData d = await rootBundle.load(assetPath);
      return parse(d);
    } catch (_) {
      return null;
    }
  }

  /// Ham baytlardan çözer (testlerde de kullanılır). Geçersiz başlık → null.
  static SeaMask? parse(ByteData d) {
    if (d.lengthInBytes < 6 + 40 + 8) return null;
    for (int i = 0; i < 6; i++) {
      if (d.getUint8(i) != _magic[i]) return null;
    }
    int o = 6;
    final double lon0 = d.getFloat64(o, Endian.little);
    final double lat0 = d.getFloat64(o + 8, Endian.little);
    final double lon1 = d.getFloat64(o + 16, Endian.little);
    final double lat1 = d.getFloat64(o + 24, Endian.little);
    final double res = d.getFloat64(o + 32, Endian.little);
    final int w = d.getInt32(o + 40, Endian.little);
    final int h = d.getInt32(o + 44, Endian.little);
    o += 48;
    if (w <= 0 || h <= 0 || res <= 0) return null;
    final int stride = (w + 7) >> 3;
    if (d.lengthInBytes - o < stride * h) return null;
    final Uint8List bits =
        Uint8List.sublistView(d.buffer.asUint8List(d.offsetInBytes), o);
    return SeaMask._(
      lon0: lon0, lat0: lat0, lon1: lon1, lat1: lat1, res: res,
      width: w, height: h, bits: bits,
    );
  }

  /// Hücre KARA mı? (Izgara dışı = kara sayılır — dışarı taşma güvenli olsun.)
  bool isLand(int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= width || cy >= height) return true;
    return (_bits[cy * _stride + (cx >> 3)] >> (7 - (cx & 7))) & 1 == 1;
  }

  bool isWater(int cx, int cy) => !isLand(cx, cy);

  /// Nokta bölge içinde mi? (Sınırda küçük tampon bırakılır.)
  bool covers(GeoPoint p) =>
      p.lon > lon0 + res && p.lon < lon1 - res &&
      p.lat > lat0 + res && p.lat < lat1 - res;

  int colOf(double lon) => ((lon - lon0) / res).floor();
  int rowOf(double lat) => ((lat1 - lat) / res).floor();

  double lonAt(int cx) => lon0 + (cx + 0.5) * res;
  double latAt(int cy) => lat1 - (cy + 0.5) * res;

  GeoPoint centerOf(int cx, int cy) => GeoPoint(lat: latAt(cy), lon: lonAt(cx));
}
