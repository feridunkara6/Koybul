import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/map/domain/map_viewport.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/map/presentation/web_map_surface.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

Finder _docklyIcon(DocklyIconData d) =>
    find.byWidgetPredicate((Widget w) => w is DocklyIcon && w.data == d);

const MapSurfaceData _data = MapSurfaceData(
  pins: <LocationPin>[
    // 15 m tekneye SIĞAN marina (40 m limit)
    LocationPin(
      id: 'fits',
      name: 'D-Marin Göcek',
      type: 'private_marina',
      position: GeoPoint(lat: 36.75, lon: 28.93),
      ratingAvg: 4.8,
      priceTier: 'paid',
      maxBoatLengthM: 40,
      maxDraftM: 5,
    ),
    // 15 m tekneye SIĞMAYAN iskele (8 m limit)
    LocationPin(
      id: 'big',
      name: 'Küçük İskele',
      type: 'municipal_pier',
      position: GeoPoint(lat: 36.80, lon: 28.90),
      ratingAvg: null,
      priceTier: 'unknown',
      maxBoatLengthM: 8,
      maxDraftM: 1,
    ),
  ],
  clusters: <Cluster>[
    // Türkiye balonu (mavi) — İstanbul çevresi.
    Cluster(
      position: GeoPoint(lat: 40.9, lon: 29.05),
      count: 33,
      bbox: Bbox(minLon: 28.8, minLat: 40.0, maxLon: 30.2, maxLat: 41.4),
      countryCode: 'TR',
    ),
    // Yunanistan balonu (turkuaz) — Sakız/Chios çevresi.
    Cluster(
      position: GeoPoint(lat: 38.5, lon: 26.5),
      count: 12,
      bbox: Bbox(minLon: 25.8, minLat: 37.8, maxLon: 27.2, maxLat: 39.2),
      countryCode: 'GR',
    ),
  ],
  selectedPinId: null,
);

Widget _app(MapSurfaceCallbacks callbacks, {MyBoat? boat}) {
  return ProviderScope(
    overrides: <Override>[
      if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => webMapSurfaceBuilder(context, _data, callbacks),
        ),
      ),
    ),
  );
}

MapSurfaceCallbacks _callbacks(void Function(MapViewport) onViewport) =>
    MapSurfaceCallbacks(
      onViewportChanged: onViewport,
      onPinTap: (String _) {},
      onClusterTap: (_) {},
    );

void main() {
  testWidgets('web yüzeyi gerçek harita çizer: cluster sayısı görünür, görünüm bildirilir',
      (WidgetTester tester) async {
    MapViewport? reported;
    await tester.pumpWidget(_app(_callbacks((MapViewport v) => reported = v)));
    await tester.pump(); // postFrame callback çalışsın (açılış görünümü)

    expect(find.byType(FlutterMap), findsOneWidget);
    // Ülke balonları: sayı + ülke kodu (TR mavi, GR turkuaz).
    expect(find.text('33'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('GR'), findsOneWidget);

    expect(reported, isNotNull);
    // bbox her kenarı ≤ 5° olmalı (sunucu sınırı — aksi halde 422).
    expect(reported!.bbox.maxLat - reported!.bbox.minLat, lessThanOrEqualTo(5.0));
    expect(reported!.bbox.maxLon - reported!.bbox.minLon, lessThanOrEqualTo(5.0));
  });

  testWidgets('tekne tanımlıysa pinlerde uyum rozeti: yeşil (sığar) + turuncu (sığmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      _callbacks((MapViewport _) {}),
      boat: const MyBoat(lengthM: 15, draftM: 2),
    ));
    await tester.pump();

    // 40 m limitli marinada yeşil onay, 8 m limitli iskelede turuncu uyarı.
    expect(_docklyIcon(DocklyIcons.checkCircle), findsOneWidget);
    expect(_docklyIcon(DocklyIcons.errorOutline), findsOneWidget);
  });

  testWidgets('tekne tanımsızsa pinlerde rozet çıkmaz', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_callbacks((MapViewport _) {})));
    await tester.pump();

    expect(_docklyIcon(DocklyIcons.checkCircle), findsNothing);
    expect(_docklyIcon(DocklyIcons.errorOutline), findsNothing);
  });

  // --- KULLANICI DOSTU SÜRÜKLEME (2026-08): tutamaç noktası üretimi ---
  group('legHandlePoints', () {
    // 1° enlem ≈ 60 nm — mesafeleri enlem farkıyla kurmak kolay.
    const GeoPoint a = GeoPoint(lat: 36.0, lon: 26.0);

    test('0,5 nm altı bacakta tutamaç YOK (kalabalık olmaz)', () {
      const GeoPoint b = GeoPoint(lat: 36.005, lon: 26.0); // ~0,3 nm
      expect(legHandlePoints(const <GeoPoint>[a, b]), isEmpty);
      expect(legHandlePoints(const <GeoPoint>[a]), isEmpty);
    });

    test('kısa bacak 1, orta bacak 3, uzun bacak 5 tutamaç', () {
      const GeoPoint kisa = GeoPoint(lat: 36.02, lon: 26.0); // ~1,2 nm
      const GeoPoint orta = GeoPoint(lat: 36.1, lon: 26.0); // ~6 nm
      const GeoPoint uzun = GeoPoint(lat: 36.5, lon: 26.0); // ~30 nm
      expect(legHandlePoints(const <GeoPoint>[a, kisa]), hasLength(1));
      expect(legHandlePoints(const <GeoPoint>[a, orta]), hasLength(3));
      expect(legHandlePoints(const <GeoPoint>[a, uzun]), hasLength(5));
    });

    test('2 kırıklı düz bacakta noktalar eşit aralıklı ve çizgi ÜZERİNDE', () {
      const GeoPoint uzun = GeoPoint(lat: 36.5, lon: 26.0); // ~30 nm kuzeye
      final List<GeoPoint> hs = legHandlePoints(const <GeoPoint>[a, uzun]);
      expect(hs, hasLength(5));
      for (int i = 0; i < hs.length; i++) {
        expect(hs[i].lon, 26.0); // düz meridyen — çizgiden sapma yok
        // k/(n+1) kesirleri: 1/6, 2/6, … 5/6.
        expect(hs[i].lat, closeTo(36.0 + 0.5 * (i + 1) / 6, 1e-9));
      }
      // Sıralı artar (monotonluk — tutamaçlar üst üste binmez).
      for (int i = 1; i < hs.length; i++) {
        expect(hs[i].lat, greaterThan(hs[i - 1].lat));
      }
    });

    test('çok kırıklı bacakta tutamaçlar toplam yol boyunca dağılır', () {
      // İki eşit parça: 36.0→36.1→36.2 (~12 nm) → 5 tutamaç; ortadaki tam
      // kırılma noktasına (36.1) düşer.
      const GeoPoint m = GeoPoint(lat: 36.1, lon: 26.0);
      const GeoPoint b = GeoPoint(lat: 36.2, lon: 26.0);
      final List<GeoPoint> hs = legHandlePoints(const <GeoPoint>[a, m, b]);
      expect(hs, hasLength(5));
      expect(hs[2].lat, closeTo(36.1, 1e-6)); // 3/6 = tam orta
    });
  });
}
