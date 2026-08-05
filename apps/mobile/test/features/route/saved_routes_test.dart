import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/saved_routes_fakes.dart';


const SavedRoute _sample = SavedRoute(
  id: 'r1',
  name: 'Datça → Kille Koyu',
  origin: RouteOrigin(pos: GeoPoint(lat: 36.70, lon: 27.70), name: 'Datça'),
  waypoints: <RouteWaypoint>[
    RouteWaypoint(pos: GeoPoint(lat: 36.74, lon: 28.10), id: 'kille', name: 'Kille Koyu'),
  ],
  distanceNm: 26.4,
  savedAtMs: 1000,
);

ProviderContainer _container(FakeSavedRoutesStore store) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      savedRoutesStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// KAYITLI ROTALAR testleri: JSON gidiş-dönüş, bozuk kayıt dayanıklılığı ve
/// kontrolcü ekle/sil/kalıcılık akışı.
void main() {
  test('JSON gidiş-dönüş: başlangıç + duraklar + özet kayıpsız döner', () {
    final SavedRoute? back = SavedRoute.fromJson(_sample.toJson());
    expect(back, isNotNull);
    expect(back!.name, 'Datça → Kille Koyu');
    expect(back.origin.name, 'Datça');
    expect(back.origin.isDevice, isFalse);
    expect(back.origin.pos.lon, 27.70);
    expect(back.waypoints.single.id, 'kille');
    expect(back.waypoints.single.isStop, isTrue);
    expect(back.distanceNm, 26.4);
    expect(back.stopCount, 1);
  });

  test('bozuk kayıt → null (çökme yok); boş ara nokta listesi de reddedilir', () {
    expect(SavedRoute.fromJson('çöp'), isNull);
    expect(SavedRoute.fromJson(<String, dynamic>{'id': 'x'}), isNull);
    final Map<String, dynamic> empty = _sample.toJson()
      ..['wps'] = <Map<String, dynamic>>[];
    expect(SavedRoute.fromJson(empty), isNull);
  });

  test('suggestRouteName: "Başlangıç → Hedef"; hedef adsızsa yalnız başlangıç', () {
    expect(suggestRouteName('Datça', _sample.waypoints), 'Datça → Kille Koyu');
    expect(
      suggestRouteName('Konumum', const <RouteWaypoint>[
        RouteWaypoint(pos: GeoPoint(lat: 36, lon: 28)),
      ]),
      'Konumum',
    );
  });

  test('kontrolcü: ekle başa gelir ve depoya yazılır; sil kalıcıdır', () async {
    final FakeSavedRoutesStore store = FakeSavedRoutesStore();
    final ProviderContainer c = _container(store);
    c.read(savedRoutesProvider); // yüklemeyi tetikle
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider), isEmpty);

    await c.read(savedRoutesProvider.notifier).add(_sample);
    const SavedRoute newer = SavedRoute(
      id: 'r2',
      name: 'Gökova turu',
      origin: RouteOrigin(pos: GeoPoint(lat: 37.0, lon: 28.0), isDevice: true),
      waypoints: <RouteWaypoint>[
        RouteWaypoint(pos: GeoPoint(lat: 36.9, lon: 28.2), id: 'a', name: 'A Koyu'),
      ],
      distanceNm: 41,
      savedAtMs: 2000,
    );
    await c.read(savedRoutesProvider.notifier).add(newer);
    expect(c.read(savedRoutesProvider).first.id, 'r2'); // en yeni başta
    expect(store.data, hasLength(2));

    await c.read(savedRoutesProvider.notifier).remove('r1');
    expect(c.read(savedRoutesProvider).single.id, 'r2');
    expect(store.data.single.id, 'r2');
  });

  test('kontrolcü: açılışta depodaki kayıtlar en-yeni-başta yüklenir', () async {
    final FakeSavedRoutesStore store = FakeSavedRoutesStore()
      ..data = <SavedRoute>[
        _sample, // savedAtMs 1000
        const SavedRoute(
          id: 'r9',
          name: 'Yeni',
          origin: RouteOrigin(pos: GeoPoint(lat: 36, lon: 28)),
          waypoints: <RouteWaypoint>[
            RouteWaypoint(pos: GeoPoint(lat: 36.5, lon: 28.5), id: 'z', name: 'Z'),
          ],
          distanceNm: 5,
          savedAtMs: 9000,
        ),
      ];
    final ProviderContainer c = _container(store);
    c.read(savedRoutesProvider);
    await Future<void>.delayed(Duration.zero);
    final List<SavedRoute> list = c.read(savedRoutesProvider);
    expect(list, hasLength(2));
    expect(list.first.id, 'r9');
  });
  test('YARIŞ KORUMASI (2026-08 hatası): yükleme bitmeden yapılan kayıt '
      'KAYBOLMAZ — bellek ve disk iki kaydı da içerir', () async {
    // Gerçek senaryo: kullanıcı uygulamayı açar açmaz rota kaydeder;
    // sağlayıcı İLK KEZ tam o anda kurulur — diskte eski kayıt vardır.
    final FakeSavedRoutesStore store = FakeSavedRoutesStore()
      ..data = <SavedRoute>[_sample]; // diskte eski kayıt (r1)
    final ProviderContainer c = _container(store);
    const SavedRoute fresh = SavedRoute(
      id: 'r2',
      name: 'Yeni tur',
      origin: RouteOrigin(pos: GeoPoint(lat: 37.0, lon: 28.0), isDevice: true),
      waypoints: <RouteWaypoint>[
        RouteWaypoint(pos: GeoPoint(lat: 36.9, lon: 28.2), id: 'a', name: 'A'),
      ],
      distanceNm: 12,
      savedAtMs: 2000,
    );
    // Yüklemeyi BEKLEMEDEN ekle (kuruluş + ekleme yarışı).
    await c.read(savedRoutesProvider.notifier).add(fresh);
    final List<String> memory =
        c.read(savedRoutesProvider).map((SavedRoute r) => r.id).toList();
    expect(memory, containsAll(<String>['r1', 'r2'])); // bellekte ikisi de
    expect(memory.first, 'r2'); // yeni kayıt başta
    final List<String> disk =
        store.data.map((SavedRoute r) => r.id).toList();
    expect(disk, containsAll(<String>['r1', 'r2'])); // diskte ikisi de
  });
}
