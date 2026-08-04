import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/domain/map_cache.dart';
import 'package:dockly_mobile/features/map/presentation/location_bottom_card.dart';
import 'package:dockly_mobile/features/map/presentation/map_screen.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';

import 'package:dockly_mobile/features/location/application/location_controller.dart';

import 'package:dockly_mobile/features/onboarding/application/onboarding_controller.dart';

import '../../support/fake_map_surface.dart';
import '../../support/location_fakes.dart';
import '../../support/map_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/search_fakes.dart';

/// İkonlar artık SVG tabanlı [DocklyIcon]; ikon verisiyle bulunur.
Finder _docklyIcon(DocklyIconData d) =>
    find.byWidgetPredicate((Widget w) => w is DocklyIcon && w.data == d);

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

Widget _app(
  FakeMapGateway gateway, {
  FakeMapCache? cache,
  MyBoat? boat,
  FakeNearbyGateway? nearby,
  FakeLocationService? location,
}) {
  return ProviderScope(
    overrides: <Override>[
      if (location != null) locationServiceProvider.overrideWithValue(location),
      mapLocationsGatewayProvider.overrideWithValue(gateway),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      // Önbellek HER ZAMAN sahte: gerçek shared_preferences testler arasında
      // sızıntı yapar (önceki testin kaydettiği veri sonrakinde "çevrimdışı
      // görünüm" tetikler). Varsayılan: boş sahte önbellek.
      mapCacheProvider.overrideWithValue(cache ?? FakeMapCache()),
      // Yakın-liman rayı da HER ZAMAN sahte (varsayılan boş → ray gizli) —
      // gerçek ağ geçidi testte HTTP'ye çıkardı.
      nearbyGatewayProvider.overrideWithValue(nearby ?? FakeNearbyGateway()),
      // Tanıtım (2026-08) bu testlerin konusu değil — "görüldü" kabul edilir.
      onboardingStoreProvider.overrideWithValue(doneOnboardingStore()),
      if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

const ValueKey<String> _pinKey = ValueKey<String>('pin-loc-1');

void main() {
  testWidgets('açılışta görünüm bildirilir → marker çizilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    expect(find.byKey(_pinKey), findsOneWidget);
  });

  testWidgets('pin dokunma → seçim gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('selection')), findsOneWidget);
    expect(find.text('secili:loc-1'), findsOneWidget);
  });

  testWidgets('pin dokunma → alt detay kartı belirir; kapatınca kaybolur', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    expect(find.byKey(LocationBottomCard.cardKey), findsNothing);

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LocationBottomCard.cardKey), findsOneWidget);
    // Tip etiketi üstteki filtre çipinde de geçer; kartın İÇİNDE aranır.
    expect(
      find.descendant(
        of: find.byKey(LocationBottomCard.cardKey),
        matching: find.text('Özel Marina'),
      ),
      findsOneWidget,
    );

    await tester.tap(_docklyIcon(DocklyIcons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(LocationBottomCard.cardKey), findsNothing);
  });

  testWidgets('liste görünümüne geçince liman listesi görünür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing); // harita modu (sahte yüzey ListTile kullanmaz)

    await tester.tap(_docklyIcon(DocklyIcons.viewList));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget); // liste modu, tek pin
    expect(_docklyIcon(DocklyIcons.mapOutlined), findsOneWidget); // haritaya dön ikonu
  });

  testWidgets('tekne tanımlıysa alt kartta uyum rozeti görünür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      boat: const MyBoat(lengthM: 15, draftM: 2),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    // testPin limiti 40 m → 15 m tekne sığar.
    expect(find.text('Teknen sığar'), findsOneWidget);
  });

  testWidgets('tip çipine dokununca filtre sunucuya geçer', (WidgetTester tester) async {
    final FakeMapGateway gateway = FakeMapGateway(result: pinResult);
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Özel Marina'));
    await tester.pumpAndSettle();
    expect(gateway.typeArgs.last, <String>['private_marina']);
  });

  testWidgets('ilk yüklemede dost mesaj gösterilir (sunucu uyanıyor)', (WidgetTester tester) async {
    final FakeMapGateway gateway = FakeMapGateway()..pending = Completer<MapResult>();
    await tester.pumpWidget(_app(gateway));
    // Süreli pump: sahte-saat ilerlesin ki debounce zamanlayıcısı ateşlensin
    // (bare pump() zamanlayıcıları ÇALIŞTIRMAZ — saat ilerlemez).
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(); // durum değişikliği ekrana yansır
    expect(find.textContaining('Limanlar yükleniyor'), findsOneWidget);
    gateway.pending!.complete(pinResult); // testi temiz bitir
    await tester.pumpAndSettle();
  });

  testWidgets('boş bölge → boş görünüm', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(
      result: const MapResult(
        clusters: <Cluster>[],
        locations: <LocationPin>[],
        truncated: false,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('henüz liman yok'), findsOneWidget);
  });

  testWidgets('truncated → yakınlaştırma ipucu', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(
      result: const MapResult(
        clusters: <Cluster>[],
        locations: <LocationPin>[testPin],
        truncated: true,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('yakınlaştırın'), findsOneWidget);
  });

  testWidgets('ağ yokken önbellek doluysa → çevrimdışı şerit + son limanlar', (WidgetTester tester) async {
    final FakeMapCache cache = FakeMapCache(
      cached: CachedMap(
        pins: pinResult.locations,
        clusters: const <Cluster>[],
        savedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(_app(FakeMapGateway(error: const NetworkFailure()), cache: cache));
    await tester.pumpAndSettle();

    expect(find.textContaining('Çevrimdışı'), findsOneWidget);
    expect(find.byKey(_pinKey), findsOneWidget); // son görülen liman haritada
    expect(find.text('Tekrar dene'), findsNothing); // tam-ekran hata YOK
  });

  testWidgets('yakın rayı VARSAYILAN GİZLİ: şerit var, kartlar yok; dokununca açılır', (WidgetTester tester) async {
    final FakeNearbyGateway nearby = FakeNearbyGateway(results: <LocationSummary>[
      sampleSummary('n1', 'Marina Symi', ratingAvg: 4.7, distanceNm: 2.1),
      sampleSummary('n2', 'Gökkaya Koyu', type: 'mooring_point', distanceNm: 5.4),
    ]);
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult), nearby: nearby));
    await tester.pumpAndSettle();

    // Varsayılan: yalnız başlık şeridi görünür, kartlar GİZLİ.
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsOneWidget);
    expect(find.text('Marina Symi'), findsNothing);

    // Şeride dokun → kartlar açılır (ad + tip · ★puan · mesafe formatı).
    await tester.tap(find.text('Yakınımdaki Bağlanma Noktaları'));
    await tester.pumpAndSettle();
    expect(find.text('Marina Symi'), findsOneWidget);
    expect(find.text('Gökkaya Koyu'), findsOneWidget);
    expect(find.textContaining('★ 4.7'), findsOneWidget);
    expect(find.textContaining('2.1 nm'), findsOneWidget);

    // Tekrar dokun → yeniden gizlenir.
    await tester.tap(find.text('Yakınımdaki Bağlanma Noktaları'));
    await tester.pumpAndSettle();
    expect(find.text('Marina Symi'), findsNothing);
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsOneWidget);
  });

  testWidgets('pin seçilince yakın rayı gizlenir (yerini detay kartı alır)', (WidgetTester tester) async {
    final FakeNearbyGateway nearby = FakeNearbyGateway(results: <LocationSummary>[
      sampleSummary('n1', 'Marina Symi', distanceNm: 2.1),
    ]);
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult), nearby: nearby));
    await tester.pumpAndSettle();
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsOneWidget);

    await tester.tap(find.byKey(_pinKey));
    await tester.pumpAndSettle();
    expect(find.text('Yakınımdaki Bağlanma Noktaları'), findsNothing);
    expect(find.byKey(LocationBottomCard.cardKey), findsOneWidget);
  });

  testWidgets('hata → hata görünümü + retry başarıyla toparlar', (WidgetTester tester) async {
    final gateway = FakeMapGateway(error: const NetworkFailure());
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byKey(_pinKey), findsNothing);

    gateway.error = null;
    gateway.result = pinResult;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.byKey(_pinKey), findsOneWidget);
  });

  testWidgets('Teknem sığar filtresi: sığmayan pin gizlenir, bilinmeyen kalır',
      (WidgetTester tester) async {
    const LocationPin small = LocationPin(
      id: 'loc-small',
      name: 'Küçük İskele',
      type: 'municipal_pier',
      position: GeoPoint(lat: 36.76, lon: 28.94),
      ratingAvg: null,
      priceTier: 'unknown',
      maxBoatLengthM: 8, // 15 m tekne SIĞMAZ
      maxDraftM: 1,
    );
    const LocationPin unknownLimits = LocationPin(
      id: 'loc-unknown',
      name: 'Bilinmeyen Koy',
      type: 'mooring_point',
      position: GeoPoint(lat: 36.77, lon: 28.95),
      ratingAvg: null,
      priceTier: 'free',
      // limit alanları null → BİLİNMEYEN: filtre gizleyemez (0-uydurma UI hali)
    );
    const MapResult threePins = MapResult(
      clusters: <Cluster>[],
      locations: <LocationPin>[testPin, small, unknownLimits],
      truncated: false,
    );
    await tester.pumpWidget(_app(
      FakeMapGateway(result: threePins),
      boat: const MyBoat(lengthM: 15, draftM: 2),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-small')), findsOneWidget);

    await tester.tap(find.text('Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.byKey(_pinKey), findsOneWidget); // 40 m limit → sığar, kalır
    expect(find.byKey(const ValueKey<String>('pin-loc-small')), findsNothing);
    expect(find.byKey(const ValueKey<String>('pin-loc-unknown')), findsOneWidget);

    // Tekrar dokun → filtre kapanır, pin geri gelir.
    await tester.tap(find.text('Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pin-loc-small')), findsOneWidget);
  });

  testWidgets('Teknem sığar: tekne tanımlı değilse tekne sayfası açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeMapGateway(result: pinResult)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teknem sığar'));
    await tester.pumpAndSettle();
    expect(find.text('Tekneni tanımla'), findsOneWidget); // tekne sayfası
  });

  testWidgets('Konumum → haritada yelkenli imleç + kamera odak isteği',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: FakeLocationService(const GeoPoint(lat: 38.4, lon: 27.1)),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('device-boat')), findsNothing);

    await tester.tap(find.byTooltip('Konumum'));
    await tester.pumpAndSettle();

    // Tekne imleci yüzeye geçti + kamera odak isteği üretildi.
    expect(find.byKey(const ValueKey<String>('device-boat')), findsOneWidget);
    expect(find.text('ben:38.4,27.1'), findsOneWidget);
    expect(find.text('odak:38.4,27.1,1'), findsOneWidget);
    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Konum alınamazsa imleç çizilmez, bilgi mesajı çıkar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeMapGateway(result: pinResult),
      location: FakeLocationService(null),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Konumum'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('device-boat')), findsNothing);
    expect(find.textContaining('Konum alınamadı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
