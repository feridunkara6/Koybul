import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dockly_ui/dockly_ui.dart'
    show DocklyIconData, DocklyIcons, DocklyMapColors;
import 'package:flutter_svg/flutter_svg.dart'
    show PictureInfo, SvgStringLoader, vg;

/// HARİTA PİN ROZETLERİ (kurucu bulgusu 2026-09-23: "noktalara yaklaşınca
/// ikonlar belli olmuyor, nokta olarak kalıyor").
///
/// Yakın zoom'da pin artık düz renkli daire değil, TİP ROZETİ'dir: tip renginde
/// daire + beyaz halka + tipi anlatan beyaz çizgi ikon (yelken, çapa, iskele,
/// çatal-bıçak, pompa, flama, can simidi). Renk semantiği docs/09 §1.4'teki
/// kanonik tablodan değişmeden gelir; ikon yalnız EKLENİR.
///
/// Teknik yol: her tip için rozet BİR KEZ ekran dışında PNG'ye çizilir
/// ([renderPinBadgePng]) ve Mapbox stiline resim olarak kaydedilir; pinler
/// `PointAnnotation(iconImage: ...)` ile bu resmi kullanır. Böylece 150 pinlik
/// görünümde bile ekstra maliyet yok — tek çizim, sınırsız kullanım.

/// Rozetin mantıksal (dp) çapı. Eski düz daire 18 dp idi (7 yarıçap + 2 halka);
/// rozet ikon taşıdığı için biraz büyür ki glif okunsun. Seçili pin çizimle
/// değil `iconSize` ölçeğiyle büyütülür (bkz. mapbox_map_surface).
const double kPinBadgeLogicalSize = 26;

/// PNG, keskinlik için 3× yoğunlukta üretilir (Mapbox `addStyleImage(scale: 3)`
/// ile geri ölçeklenir — Retina'da bulanıklık olmaz).
const double kPinImageScale = 3;

/// Bilinmeyen/yeni `location_type` için kayıtlı yedek rozet kimliği.
const String kUnknownPinImageId = 'pin-unknown';

/// `location_type` → rozet glifi. Renk zaten tipi kodlar (docs/09 §1.4);
/// glif tipe SEMANTİK ipucu ekler: marinalar yelken, bağlama noktaları çapa,
/// iskeleler kazıklı iskele, restoran çatal-bıçak, yakıt pompa, kulüp flama,
/// şamandıra can simidi. Bilinmeyen tip → yer imi (place).
DocklyIconData mapPinIconFor(String type) {
  switch (type) {
    case 'private_marina':
    case 'municipal_marina':
      return DocklyIcons.sailing;
    case 'municipal_pier':
      return DocklyIcons.pier;
    case 'guest_mooring':
    case 'mooring_point':
      return DocklyIcons.amMooring; // çapa
    case 'restaurant_pier':
      return DocklyIcons.amRestaurant;
    case 'fuel_pier':
      return DocklyIcons.amFuel;
    case 'boat_club':
      return DocklyIcons.flag; // kulüp flaması
    case 'buoy':
      return DocklyIcons.lifeBuoy;
    default:
      return DocklyIcons.place;
  }
}

/// Pinin kullanacağı stil resmi kimliği. Bilinmeyen tip kayıtsız bir kimliğe
/// işaret edip GÖRÜNMEZ pin doğurmasın diye yedeğe düşer.
String mapPinImageId(String type) =>
    DocklyMapColors.knownTypes.contains(type) ? 'pin-$type' : kUnknownPinImageId;

/// Stile kaydedilecek tüm rozetler: kimlik → (dolgu rengi, glif).
/// Kanonik tipler + bilinmeyen-tip yedeği.
Map<String, ({int fillArgb, DocklyIconData icon})> mapPinBadgeSpecs() =>
    <String, ({int fillArgb, DocklyIconData icon})>{
      for (final String type in DocklyMapColors.knownTypes)
        'pin-$type': (
          fillArgb: DocklyMapColors.argbForType(type),
          icon: mapPinIconFor(type),
        ),
      kUnknownPinImageId: (
        fillArgb: DocklyMapColors.argbForType('__unknown__'),
        icon: DocklyIcons.place,
      ),
    };

/// ROTA/İMLEÇ ROZETLERİ (Rota Modu, kurucu onayı 2026-09-23): rota çizgisinin
/// başı-sonu ve GPS imleci de pin rozetleriyle aynı boru hattından üretilir.
/// - route-start: lacivert + yelken (başlangıç)
/// - route-dest : yeşil + flama (varış)
/// - route-stop : beyaz + marka halkası (numara annotation metniyle basılır)
/// - device-boat: marka mavisi + yelken (kaptanın GPS konumu)
const String kRouteStartImageId = 'route-start';
const String kRouteDestImageId = 'route-dest';
const String kRouteStopImageId = 'route-stop';
const String kDeviceBoatImageId = 'device-boat';

Map<String, ({int fillArgb, int ringArgb, DocklyIconData? icon})>
    mapRouteBadgeSpecs() =>
        <String, ({int fillArgb, int ringArgb, DocklyIconData? icon})>{
          kRouteStartImageId: (
            fillArgb: 0xFF0A2540, // DocklyColors.brandDeep
            ringArgb: DocklyMapColors.strokeArgb,
            icon: DocklyIcons.sailing,
          ),
          kRouteDestImageId: (
            fillArgb: 0xFF30A46C, // DocklyColors.success
            ringArgb: DocklyMapColors.strokeArgb,
            icon: DocklyIcons.flag,
          ),
          kRouteStopImageId: (
            fillArgb: 0xFFFFFFFF,
            ringArgb: 0xFF0C7BDC, // DocklyColors.brandPrimary
            icon: null, // numara, annotation metni olarak üstüne basılır
          ),
          kDeviceBoatImageId: (
            fillArgb: 0xFF0C7BDC,
            ringArgb: DocklyMapColors.strokeArgb,
            icon: DocklyIcons.sailing,
          ),
        };

/// Tek bir rozeti PNG baytlarına çizer: dolgu dairesi + [ringArgb] halka +
/// (varsa) ortalanmış beyaz glif. Glif SVG'si bozuk çıkarsa (beklenmez)
/// rozet düz renkli daire olarak kalır — pin asla görünmez olmaz.
Future<Uint8List> renderPinBadgePng({
  required int fillArgb,
  DocklyIconData? icon,
  int ringArgb = DocklyMapColors.strokeArgb,
}) async {
  final int px = (kPinBadgeLogicalSize * kPinImageScale).round(); // 78
  const double strokeW = 2 * kPinImageScale; // beyaz halka: 2 dp
  final double half = px / 2;
  // Halka, dış kenardan taşmasın: yarıçap = yarı boy - halka/2 (- 1px pay).
  final double radius = half - strokeW / 2 - 1;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Offset center = ui.Offset(half, half);

  canvas.drawCircle(center, radius, ui.Paint()..color = ui.Color(fillArgb));
  canvas.drawCircle(
    center,
    radius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..color = ui.Color(ringArgb),
  );

  if (icon == null) {
    // Glifsiz rozet (ör. numaralı durak zemini) — daire yeterli.
    final ui.Image image0 = await recorder.endRecording().toImage(px, px);
    try {
      final ByteData? bytes0 =
          await image0.toByteData(format: ui.ImageByteFormat.png);
      if (bytes0 == null) throw StateError('Pin rozeti PNG kodlanamadı');
      return bytes0.buffer.asUint8List();
    } finally {
      image0.dispose();
    }
  }

  try {
    final PictureInfo glyph =
        await vg.loadPicture(SvgStringLoader(icon.svgMarkup), null);
    // Glif rozet çapının ~%54'ü — halkaya değmeden rahat okunur.
    final double glyphSize = px * 0.54;
    final double scale = glyphSize / 24; // ikon grid'i 24×24
    final ui.Rect bounds = ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble());
    // saveLayer + srcIn: glif hangi renkte çizilmiş olursa olsun beyaza boyanır
    // (DocklyIcon widget'ının yaptığı tintlemenin tuval karşılığı).
    canvas.saveLayer(
      bounds,
      ui.Paint()
        ..colorFilter = const ui.ColorFilter.mode(
          ui.Color(DocklyMapColors.strokeArgb),
          ui.BlendMode.srcIn,
        ),
    );
    canvas.translate(half - glyphSize / 2, half - glyphSize / 2);
    canvas.scale(scale, scale);
    canvas.drawPicture(glyph.picture);
    canvas.restore();
    glyph.picture.dispose();
  } catch (_) {
    // Glif çizilemedi — düz renkli rozetle devam (eski görünümden kötü değil).
  }

  final ui.Image image = await recorder.endRecording().toImage(px, px);
  try {
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Pin rozeti PNG kodlanamadı');
    }
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
