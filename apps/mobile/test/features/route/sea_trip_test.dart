import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/route/data/sea_mask.dart';
import 'package:dockly_mobile/features/route/domain/sea_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:flutter_test/flutter_test.dart';

/// ÇOK DURAKLI ROTA testleri (rota düzenleme 2026-08) — birleştirme ve durak
/// yerleştirme SAF işlevleri + GERÇEK maskeyle iki bacaklı yolculuk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SeaMask mask;

  setUpAll(() async {
    final SeaMask? m = await SeaMask.load();
    expect(m, isNotNull, reason: 'assets/route/sea_mask.bin yüklenmeli');
    mask = m!;
  });

  test('combineTripLegs: tek bacak AYNEN döner (kimlik korunur)', () {
    const SeaRoutePlan leg = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.7, lon: 28.9), GeoPoint(lat: 36.6, lon: 28.9)],
      distanceNm: 6,
      reachedGoal: true,
      viaSea: true,
    );
    expect(identical(combineTripLegs(const <SeaRoutePlan>[leg]), leg), isTrue);
  });

  test('combineTripLegs: eklem noktası bir kez alınır, mesafe toplamdır', () {
    const SeaRoutePlan a = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.0, lon: 28.0), GeoPoint(lat: 36.5, lon: 28.0)],
      distanceNm: 30,
      reachedGoal: true,
      viaSea: true,
    );
    const SeaRoutePlan b = SeaRoutePlan(
      points: <GeoPoint>[GeoPoint(lat: 36.5, lon: 28.0), GeoPoint(lat: 36.5, lon: 28.5)],
      distanceNm: 24,
      reachedGoal: false, // son yaklaşma açığı — birleşikte korunmalı
      viaSea: true,
    );
    final SeaRoutePlan c = combineTripLegs(const <SeaRoutePlan>[a, b]);
    expect(c.points, hasLength(3)); // eklem (36.5,28.0) tek kopya
    expect(c.distanceNm, closeTo(54, 1e-9));
    expect(c.reachedGoal, isFalse);
    expect(c.viaSea, isTrue);
  });

  test('bestStopInsertIndex: durak en az sapma yapan bacağa girer', () {
    const GeoPoint bodrum = GeoPoint(lat: 37.02, lon: 27.40);
    const GeoPoint datca = GeoPoint(lat: 36.70, lon: 27.68);
    const GeoPoint antalya = GeoPoint(lat: 36.55, lon: 30.55);
    const GeoPoint kas = GeoPoint(lat: 36.19, lon: 29.63);
    const GeoPoint gocek = GeoPoint(lat: 36.74, lon: 28.94);
    // Datça, Bodrum→Antalya yolunun BAŞINA girer (Python ile doğrulandı: 0).
    expect(bestStopInsertIndex(bodrum, const <GeoPoint>[antalya], datca), 0);
    // Kaş ve Göcek, Datça→Antalya bacağına girer (Python ile doğrulandı: 1).
    expect(
        bestStopInsertIndex(bodrum, const <GeoPoint>[datca, antalya], kas), 1);
    expect(
        bestStopInsertIndex(bodrum, const <GeoPoint>[datca, antalya], gocek), 1);
  });

  test('nearestWaterCenter: su noktası aynen; kara kıyısı suya kayar; iç kara null', () {
    const GeoPoint aegean = GeoPoint(lat: 38.0, lon: 25.0); // açık deniz
    expect(nearestWaterCenter(mask, aegean), same(aegean));
    // İstanbul içi (karada — sea_router_test ile tutarlı nokta): ~5 km içinde
    // su bulunmalı ve dönen nokta SUDA olmalı.
    const GeoPoint istanbulIci = GeoPoint(lat: 41.03, lon: 28.98);
    expect(mask.isLand(mask.colOf(istanbulIci.lon), mask.rowOf(istanbulIci.lat)), isTrue);
    final GeoPoint? snapped = nearestWaterCenter(mask, istanbulIci, maxR: 40);
    expect(snapped, isNotNull);
    expect(mask.isWater(mask.colOf(snapped!.lon), mask.rowOf(snapped.lat)), isTrue);
    // Ankara: 10 halkada (~5 km) su yok → null (tutamaç iç karaya bırakılamaz).
    expect(nearestWaterCenter(mask, const GeoPoint(lat: 39.9, lon: 32.5)), isNull);
    // Kapsam dışı → null.
    expect(nearestWaterCenter(mask, const GeoPoint(lat: 43.3, lon: 5.4)), isNull);
  });

  test('GERÇEK MASKE: Bodrum→Datça→Göcek iki bacaklı yolculuk — birleşik rota '
      'sürekli, tamamen suda ve mesafe bacakların toplamı', () {
    const GeoPoint bodrum = GeoPoint(lat: 37.02, lon: 27.40);
    const GeoPoint datca = GeoPoint(lat: 36.70, lon: 27.68);
    const GeoPoint gocek = GeoPoint(lat: 36.74, lon: 28.94);
    final SeaRoutePlan leg1 = planSeaRoute(mask, bodrum, datca)!;
    final SeaRoutePlan leg2 = planSeaRoute(mask, datca, gocek)!;
    final SeaRoutePlan trip = combineTripLegs(<SeaRoutePlan>[leg1, leg2]);
    expect(trip.viaSea, isTrue);
    expect(trip.distanceNm, closeTo(leg1.distanceNm + leg2.distanceNm, 1e-9));
    expect(trip.points.first.lat, leg1.points.first.lat);
    expect(trip.points.last.lon, leg2.points.last.lon);
    // Süreklilik: ardışık kırıklıklar arasında kopukluk yok (< 6 nm) —
    // bacak eklemi de dahil (durak noktasında rota kesintisiz görünür).
    for (int i = 1; i < trip.points.length; i++) {
      expect(haversineNm(trip.points[i - 1], trip.points[i]), lessThan(6),
          reason: 'kopukluk: $i');
    }
    // Ara kırıklıklar suda (kaptan kuralı) — uçlar koy işaretine bağlanabilir.
    for (int i = 1; i < trip.points.length - 1; i++) {
      final GeoPoint p = trip.points[i];
      final bool water = mask.isWater(mask.colOf(p.lon), mask.rowOf(p.lat));
      // Eklem noktası (Datça işareti) kıyıda olabilir; diğer tüm kırıklıklar su.
      final bool isJoint = p.lat == datca.lat && p.lon == datca.lon;
      expect(water || isJoint, isTrue, reason: 'karada kırıklık: ${p.lat},${p.lon}');
    }
  });
}
