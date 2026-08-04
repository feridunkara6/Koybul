import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/route/data/sea_mask.dart';
import 'package:dockly_mobile/features/route/domain/sea_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// AKILLI DENİZ ROTASI testleri — GERÇEK maske varlığıyla koşar (flutter test
/// pubspec varlıklarını yükleyebilir). Böylece "rota karadan geçmiyor"
/// güvencesi kâğıt üstünde değil, gerçek kıyı verisi üzerinde doğrulanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SeaMask mask;

  setUpAll(() async {
    final SeaMask? m = await SeaMask.load();
    expect(m, isNotNull, reason: 'assets/route/sea_mask.bin yüklenmeli');
    mask = m!;
  });

  test('maske başlığı: bölge Ege-Akdeniz-Marmara-İyon penceresini kapsar', () {
    expect(mask.lon0, lessThan(20.2)); // Lakka (Paksos) içeride
    expect(mask.lon1, greaterThan(36.0)); // doğu Akdeniz kıyısı
    expect(mask.lat0, lessThan(35.0));
    expect(mask.lat1, greaterThan(41.0)); // İstanbul-Marmara
    expect(mask.width, greaterThan(1000));
    expect(mask.height, greaterThan(500));
  });

  test('maske örneklemi: açık deniz SU, kara içi KARA', () {
    expect(mask.isWater(mask.colOf(25.0), mask.rowOf(38.0)), isTrue); // Ege
    expect(mask.isWater(mask.colOf(28.6), mask.rowOf(40.7)), isTrue); // Marmara
    expect(mask.isLand(mask.colOf(27.60), mask.rowOf(36.73)), isTrue); // Datça sırtı
    expect(mask.isLand(mask.colOf(32.5), mask.rowOf(39.9)), isTrue); // Ankara
  });

  test('Bodrum→Datça: rota yarımadayı DOLAŞIR ve ara noktalar tamamen suda', () {
    const GeoPoint from = GeoPoint(lat: 37.02, lon: 27.40); // Bodrum önü
    const GeoPoint to = GeoPoint(lat: 36.70, lon: 27.68); // Datça önü (güney)
    final SeaRoutePlan? plan = planSeaRoute(mask, from, to);
    expect(plan, isNotNull);
    expect(plan!.viaSea, isTrue);
    final double straight = haversineNm(from, to);
    // Kuş uçuşu karadan geçer; deniz rotası belirgin daha uzun olmalı.
    expect(plan.distanceNm, greaterThan(straight * 1.15));
    expect(plan.points.length, greaterThanOrEqualTo(3));
    for (int i = 1; i < plan.points.length - 1; i++) {
      final GeoPoint p = plan.points[i];
      expect(mask.isWater(mask.colOf(p.lon), mask.rowOf(p.lat)), isTrue,
          reason: 'rota kırıklığı karada olamaz: ${p.lat},${p.lon}');
    }
  });

  test('Göcek→Fethiye: kısa körfez rotası makul (kuş uçuşunun 2.5 katını aşmaz)', () {
    const GeoPoint from = GeoPoint(lat: 36.74, lon: 28.94);
    const GeoPoint to = GeoPoint(lat: 36.65, lon: 29.10);
    final SeaRoutePlan? plan = planSeaRoute(mask, from, to);
    expect(plan, isNotNull);
    expect(plan!.viaSea, isTrue);
    final double straight = haversineNm(from, to);
    expect(plan.distanceNm, greaterThanOrEqualTo(straight * 0.99));
    expect(plan.distanceNm, lessThan(straight * 2.5));
  });

  test('determinizm: aynı girdi aynı rotayı üretir (0-uydurma ilkesi)', () {
    const GeoPoint from = GeoPoint(lat: 37.02, lon: 27.40);
    const GeoPoint to = GeoPoint(lat: 36.70, lon: 27.68);
    final SeaRoutePlan a = planSeaRoute(mask, from, to)!;
    final SeaRoutePlan b = planSeaRoute(mask, from, to)!;
    expect(a.points.length, b.points.length);
    expect(a.distanceNm, b.distanceNm);
    expect(a.reachedGoal, b.reachedGoal);
  });

  test('bölge dışı nokta → null (çağıran kuş uçuşu yedeğine düşer)', () {
    const GeoPoint marseille = GeoPoint(lat: 43.3, lon: 5.4);
    const GeoPoint bodrum = GeoPoint(lat: 37.02, lon: 27.40);
    expect(planSeaRoute(mask, marseille, bodrum), isNull);
    expect(planSeaRoute(mask, bodrum, marseille), isNull);
  });

  test('aynı nokta → sıfıra yakın mesafe, geçerli plan', () {
    const GeoPoint p = GeoPoint(lat: 37.02, lon: 27.40);
    final SeaRoutePlan? plan = planSeaRoute(mask, p, p);
    expect(plan, isNotNull);
    expect(plan!.distanceNm, lessThan(0.5));
    expect(plan.points.length, greaterThanOrEqualTo(2));
  });

  test('kara-içi hedef (Ankara) → anlamlı rota yok (null)', () {
    const GeoPoint aegean = GeoPoint(lat: 38.0, lon: 25.0);
    const GeoPoint ankara = GeoPoint(lat: 39.9, lon: 32.5);
    expect(planSeaRoute(mask, aegean, ankara), isNull);
  });

  test('directLinePlan: dürüst kuş uçuşu yedeği (viaSea=false)', () {
    const GeoPoint a = GeoPoint(lat: 36.0, lon: 28.0);
    const GeoPoint b = GeoPoint(lat: 37.0, lon: 28.0);
    final SeaRoutePlan plan = directLinePlan(a, b);
    expect(plan.viaSea, isFalse);
    expect(plan.reachedGoal, isTrue);
    expect(plan.points, hasLength(2));
    expect(plan.distanceNm, closeTo(60.0, 0.6)); // 1° enlem ≈ 60 nm
  });
}
