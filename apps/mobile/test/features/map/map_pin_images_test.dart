import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dockly_mobile/features/map/presentation/map_pin_images.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// PİN ROZETLERİ (kurucu bulgusu 2026-09-23: "noktalara yaklaşınca ikonlar
/// belli olmuyor, nokta olarak kalıyor"): her tipin rozeti kayıtlı olmalı ve
/// PNG üretimi GERÇEKTEN çalışmalı — cihazda görünmez pin (kayıtsız iconImage)
/// bu testle yakalanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('her kanonik tipin rozet kimliği ve glifi vardır', () {
    for (final String type in DocklyMapColors.knownTypes) {
      expect(mapPinImageId(type), 'pin-$type');
      expect(mapPinBadgeSpecs(), contains('pin-$type'));
    }
  });

  test('bilinmeyen tip yedeğe düşer — görünmez pin doğmaz', () {
    expect(mapPinImageId('yeni_gelecek_tip'), kUnknownPinImageId);
    expect(mapPinBadgeSpecs(), contains(kUnknownPinImageId));
  });

  test('glif eşlemesi tip semantiğini taşır (docs/09 §1.4 renk + glif)', () {
    expect(mapPinIconFor('private_marina'), DocklyIcons.sailing);
    expect(mapPinIconFor('municipal_marina'), DocklyIcons.sailing);
    expect(mapPinIconFor('municipal_pier'), DocklyIcons.pier);
    expect(mapPinIconFor('guest_mooring'), DocklyIcons.amMooring);
    expect(mapPinIconFor('mooring_point'), DocklyIcons.amMooring);
    expect(mapPinIconFor('restaurant_pier'), DocklyIcons.amRestaurant);
    expect(mapPinIconFor('fuel_pier'), DocklyIcons.amFuel);
    expect(mapPinIconFor('boat_club'), DocklyIcons.flag);
    expect(mapPinIconFor('buoy'), DocklyIcons.lifeBuoy);
  });

  test('rozet dolguları kanonik tip renkleridir', () {
    final Map<String, ({int fillArgb, DocklyIconData icon})> specs =
        mapPinBadgeSpecs();
    for (final String type in DocklyMapColors.knownTypes) {
      expect(specs['pin-$type']!.fillArgb, DocklyMapColors.argbForType(type));
    }
  });

  test('her rozet gerçek, çözülebilir bir PNG olarak çizilir (beklenen boyutta)',
      () async {
    final int px = (kPinBadgeLogicalSize * kPinImageScale).round();
    Future<void> check(String id, Uint8List png) async {
      expect(png, isNotEmpty, reason: id);
      final ui.Codec codec = await ui.instantiateImageCodec(png);
      final ui.FrameInfo frame = await codec.getNextFrame();
      expect(frame.image.width, px, reason: id);
      expect(frame.image.height, px, reason: id);
      frame.image.dispose();
      codec.dispose();
    }

    for (final MapEntry<String, ({int fillArgb, DocklyIconData icon})> spec
        in mapPinBadgeSpecs().entries) {
      await check(
          spec.key,
          await renderPinBadgePng(
              fillArgb: spec.value.fillArgb, icon: spec.value.icon));
    }
    // Rota/imleç rozetleri (Rota Modu 2026-09-23) — glifsiz durak rozeti
    // dahil hepsi çizilebilir olmalı (kayıtsız iconImage = görünmez işaretçi).
    for (final MapEntry<String,
            ({int fillArgb, int ringArgb, DocklyIconData? icon})> spec
        in mapRouteBadgeSpecs().entries) {
      await check(
          spec.key,
          await renderPinBadgePng(
            fillArgb: spec.value.fillArgb,
            ringArgb: spec.value.ringArgb,
            icon: spec.value.icon,
          ));
    }
  });
}
