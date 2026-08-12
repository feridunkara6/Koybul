import 'dart:math' as math;

import 'package:dockly_api/dockly_api.dart' show GeoPoint, LocationPin;

/// ÇAKIŞIK İĞNE AYRIŞTIRMA (Faz 2 — denetim bulgusu).
///
/// Veride 10 kayıt çifti BİREBİR aynı koordinatı taşıyor: altısı marinanın
/// içindeki yakıt iskelesi (koordinatı marinadan miras almış), dördü aynı
/// koydaki restoran iskelesi + demirleme alanı. İki iğne aynı noktaya
/// çizilince alttaki HİÇ SEÇİLEMEZ — kullanıcı için o kayıt yok demektir.
///
/// Çözüm bilinçli olarak SUNUM katmanında: kayıtların gerçek koordinatına
/// DOKUNULMAZ ("tahmin/uydurma yok" kuralı — kayıtlı koordinat kaynaklıdır ve
/// detay sayfası onu gösterir). Yalnız haritaya çizilen kopya, çakışan her
/// grup içinde küçük bir halkaya açılır: ilk iğne (kimliğe göre sıralamada
/// baştaki) yerinde kalır, diğerleri ~30 m yarıçapla çevresine dizilir.
/// 30 m, iğnelerin ayrıştığı yakınlaştırmalarda iki iğneyi seçilebilir kılar;
/// düşük yakınlaştırmada zaten kümeleme devrededir.
///
/// Sıralama kimliğe göre olduğundan sonuç DETERMİNİSTİKTİR: aynı veri her
/// açılışta aynı görüntüyü verir.
///
/// Not: iğneden başlatılan rota bu kaydırılmış noktayı kullanır; ~30 m sapma
/// rota motoru için önemsizdir (motor noktayı zaten suya oturtur).
const double _spreadDeg = 0.00028; // ~31 m enlemde; boylamda cos(lat) düzeltilir

List<LocationPin> spreadCoincidentPins(List<LocationPin> pins) {
  if (pins.length < 2) return pins;
  final Map<String, List<int>> byPos = <String, List<int>>{};
  for (int i = 0; i < pins.length; i++) {
    final GeoPoint p = pins[i].position;
    // Anahtar tam değer üzerinden: yalnız BİREBİR aynı koordinat çakışıktır.
    (byPos['${p.lat},${p.lon}'] ??= <int>[]).add(i);
  }
  if (byPos.values.every((List<int> g) => g.length == 1)) return pins;

  final List<LocationPin> out = List<LocationPin>.of(pins);
  for (final List<int> group in byPos.values) {
    if (group.length < 2) continue;
    // Deterministik sıra: kimliğe göre. Baştaki yerinde kalır.
    group.sort((int a, int b) => pins[a].id.compareTo(pins[b].id));
    final GeoPoint center = pins[group.first].position;
    // .toDouble(): num.clamp num döner; double alanına örtük düşürme derleme
    // hatasıdır (strict-casts).
    final double lonScale =
        math.cos(center.lat * math.pi / 180).clamp(0.2, 1.0).toDouble();
    for (int k = 1; k < group.length; k++) {
      // Halkaya diziliş; ilk kaydırılan kuzeydoğuya düşer (45°), sonrakiler
      // halkada eşit aralıkla ilerler.
      final double angle =
          math.pi / 4 + (k - 1) * (2 * math.pi / math.max(group.length - 1, 1));
      final int i = group[k];
      final LocationPin p = pins[i];
      out[i] = LocationPin(
        id: p.id,
        name: p.name,
        type: p.type,
        position: GeoPoint(
          lat: center.lat + _spreadDeg * math.sin(angle),
          lon: center.lon + _spreadDeg * math.cos(angle) / lonScale,
        ),
        ratingAvg: p.ratingAvg,
        priceTier: p.priceTier,
        maxBoatLengthM: p.maxBoatLengthM,
        maxDraftM: p.maxDraftM,
        occupancy: p.occupancy,
      );
    }
  }
  return List<LocationPin>.unmodifiable(out);
}
