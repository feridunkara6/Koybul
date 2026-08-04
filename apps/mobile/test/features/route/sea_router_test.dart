import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/route/data/sea_mask.dart';
import 'package:dockly_mobile/features/route/data/tr_coast_grid.dart';
import 'package:dockly_mobile/features/route/domain/sea_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// AKILLI DENİZ ROTASI testleri — GERÇEK maske varlığıyla koşar (flutter test
/// pubspec varlıklarını yükleyebilir). Böylece "rota karadan geçmiyor"
/// güvencesi kâğıt üstünde değil, gerçek kıyı verisi üzerinde doğrulanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SeaMask mask;
  late TrCoastGrid waters;

  setUpAll(() async {
    final SeaMask? m = await SeaMask.load();
    expect(m, isNotNull, reason: 'assets/route/sea_mask.bin yüklenmeli');
    mask = m!;
    final TrCoastGrid? w = await TrCoastGrid.load();
    expect(w, isNotNull, reason: 'assets/route/tr_coast_dist.bin yüklenmeli');
    waters = w!;
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

  test('İstanbul→Antalya: TAM BÖLGE aşaması Çanakkale üzerinden DENİZ rotası bulur', () {
    const GeoPoint istanbul = GeoPoint(lat: 41.02, lon: 28.98);
    const GeoPoint antalya = GeoPoint(lat: 36.55, lon: 30.55);
    final SeaRoutePlan? plan = planSeaRoute(mask, istanbul, antalya);
    expect(plan, isNotNull, reason: 'uzun rota tam-bölge aşamasıyla çözülmeli');
    expect(plan!.viaSea, isTrue);
    expect(plan.reachedGoal, isTrue);
    final double straight = haversineNm(istanbul, antalya); // ~278 nm (karadan!)
    expect(plan.distanceNm, greaterThan(straight * 1.5)); // deniz yolu ~584 nm
    expect(plan.distanceNm, lessThan(straight * 3.0));
    // Rota Çanakkale'den geçmeli: 26.0-26.6 boylam aralığına kırıklık düşer.
    expect(
      plan.points.any((GeoPoint p) => p.lon > 25.8 && p.lon < 26.8 && p.lat > 39.8),
      isTrue,
      reason: 'rota Çanakkale Boğazı bölgesinden geçmeli',
    );
    // Hiçbir ara kırıklık karada olamaz (kaptan kuralı).
    for (int i = 1; i < plan.points.length - 1; i++) {
      final GeoPoint p = plan.points[i];
      expect(mask.isWater(mask.colOf(p.lon), mask.rowOf(p.lat)), isTrue,
          reason: 'karada kırıklık: ${p.lat},${p.lon}');
    }
  });

  test('karasuları ızgarası: Antalya TR kıyısı, Simi Yunan tarafı', () {
    expect(waters.distTrNm(const GeoPoint(lat: 36.55, lon: 30.55)), lessThanOrEqualTo(1.0));
    expect(waters.greekSide(const GeoPoint(lat: 36.55, lon: 30.55)), isFalse);
    expect(waters.greekSide(const GeoPoint(lat: 36.62, lon: 27.84)), isTrue); // Simi
    expect(waters.greekSide(const GeoPoint(lat: 38.35, lon: 26.35)), isFalse); // Çeşme kanalı TR yakası
  });

  test('KARADAKİ BAŞLANGIÇ: rota en yakın kıyı suyundan başlar, eve çizgi çekilmez', () {
    // Kullanıcının yaşadığı senaryo: GPS şehir içinde (İstanbul, karada) —
    // eski davranış karadan denize düz çizgi çekiyordu; artık yasak.
    const GeoPoint istanbulIci = GeoPoint(lat: 41.03, lon: 28.98);
    const GeoPoint erdek = GeoPoint(lat: 40.55, lon: 27.75); // Marmara suyu
    expect(mask.isLand(mask.colOf(istanbulIci.lon), mask.rowOf(istanbulIci.lat)), isTrue);
    final SeaRoutePlan? plan = planSeaRoute(mask, istanbulIci, erdek);
    expect(plan, isNotNull);
    final GeoPoint first = plan!.points.first;
    expect(first.lat == istanbulIci.lat && first.lon == istanbulIci.lon, isFalse,
        reason: 'çizgi karadaki ham konumdan BAŞLAYAMAZ');
    expect(mask.isWater(mask.colOf(first.lon), mask.rowOf(first.lat)), isTrue,
        reason: 'çizginin ilk noktası suda olmalı');
    // Tüm ara kırıklıklar da suda (kaptan kuralı).
    for (int i = 0; i < plan.points.length - 1; i++) {
      final GeoPoint q = plan.points[i];
      expect(mask.isWater(mask.colOf(q.lon), mask.rowOf(q.lat)), isTrue);
    }
  });

  test('TÜRK KARASULARI TERCİHİ: TR hedefte Yunan-tarafı kırıklıkları azalır; Yunan hedefte serbest', () {
    const GeoPoint cesme = GeoPoint(lat: 38.32, lon: 26.28);
    const GeoPoint antalya = GeoPoint(lat: 36.55, lon: 30.55);
    int greekCount(SeaRoutePlan p) =>
        p.points.where((GeoPoint q) => waters.greekSide(q)).length;
    final SeaRoutePlan tercihli = planSeaRoute(mask, cesme, antalya, waters: waters)!;
    final SeaRoutePlan serbest = planSeaRoute(mask, cesme, antalya)!;
    expect(tercihli.reachedGoal, isTrue);
    // Tercihli rota Yunan tarafında daha az bulunur (yumuşak kural).
    expect(greekCount(tercihli), lessThanOrEqualTo(greekCount(serbest)));
    // Yunan hedefi (Simi): tercih otomatik KAPALI — rota kısa ve serbest.
    const GeoPoint datca = GeoPoint(lat: 36.71, lon: 27.60);
    const GeoPoint simi = GeoPoint(lat: 36.62, lon: 27.84);
    final SeaRoutePlan simiPlan = planSeaRoute(mask, datca, simi, waters: waters)!;
    expect(simiPlan.reachedGoal, isTrue);
    expect(simiPlan.distanceNm, lessThan(30));
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
