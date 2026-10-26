import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_state.dart';
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
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

/// HESAP KAPISI (2026-10-26): kayıtlı rotalar hesaba bağlı — testlerin
/// varsayılanı "hesap açık" (testUser). Misafir/çıkış senaryoları kendi
/// override'ını verir.
ProviderContainer _container(FakeSavedRoutesStore store,
    {List<Override> extra = const <Override>[]}) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      savedRoutesStoreProvider.overrideWithValue(store),
      if (extra.isEmpty) signedInAuthOverride(),
      ...extra,
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

  // ==========================================================================
  // HESAP KAPISI (kurucu kararı 2026-10-26): kayıtlı rotalar hesapla gezer.
  // ==========================================================================

  test('HESAP KAPISI: misafirde liste BOŞ görünür; depo dokunulmaz; '
      'add de yazmaz (emniyet kemeri)', () async {
    final FakeSavedRoutesStore store = FakeSavedRoutesStore()
      ..data = <SavedRoute>[_sample];
    final ProviderContainer c = _container(store, extra: <Override>[
      signedInAuthOverride(user: testGuest),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider), isEmpty); // misafir rota GÖRMEZ
    await c.read(savedRoutesProvider.notifier).add(_sample.withOwner(null));
    expect(c.read(savedRoutesProvider), isEmpty);
    expect(store.data.single.id, 'r1'); // depo DOKUNULMADI
  });

  test('HESAP KAPISI: sahipsiz ESKİ kayıtlar ilk hesaplı açılışta '
      'sahiplenilir (kimsenin rotası uçmaz)', () async {
    final FakeSavedRoutesStore store = FakeSavedRoutesStore()
      ..data = <SavedRoute>[_sample]; // ownerUid YOK
    final ProviderContainer c = _container(store);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider).single.id, 'r1'); // geri geldi
    expect(c.read(savedRoutesProvider).single.ownerUid, testUser.id);
    await Future<void>.delayed(Duration.zero); // sahiplenme diske yazılsın
    expect(store.data.single.ownerUid, testUser.id); // artık bu hesabın
  });

  test('HESAP KAPISI: başka hesabın rotası GÖSTERİLMEZ ama ekleme/silme '
      'sırasında diskte KORUNUR', () async {
    final SavedRoute foreign = _sample.withOwner('baska-hesap');
    final FakeSavedRoutesStore store = FakeSavedRoutesStore()
      ..data = <SavedRoute>[foreign];
    final ProviderContainer c = _container(store);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider), isEmpty); // gösterilmez

    // Bu hesap yeni rota ekler → kendi listesinde tek; diskte İKİSİ birden.
    const SavedRoute mine = SavedRoute(
      id: 'r2',
      name: 'Benim turum',
      origin: RouteOrigin(pos: GeoPoint(lat: 37.0, lon: 28.0)),
      waypoints: <RouteWaypoint>[
        RouteWaypoint(pos: GeoPoint(lat: 36.9, lon: 28.2), id: 'a', name: 'A'),
      ],
      distanceNm: 12,
      savedAtMs: 2000,
    );
    await c.read(savedRoutesProvider.notifier).add(mine);
    expect(c.read(savedRoutesProvider).single.id, 'r2');
    expect(store.data, hasLength(2)); // başkasının kaydı SİLİNMEDİ
    expect(store.data.any((SavedRoute r) => r.ownerUid == 'baska-hesap'),
        isTrue);
  });

  test('HESAP KAPISI: çıkışta liste boşalır, aynı hesapla dönünce geri gelir',
      () async {
    final FakeSavedRoutesStore store = FakeSavedRoutesStore()
      ..data = <SavedRoute>[_sample.withOwner(testUser.id)];
    final ProviderContainer c = _container(store, extra: <Override>[
      authControllerProvider.overrideWith(
          () => SwitchableAuthController(const Authenticated(testUser))),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider), hasLength(1));

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Unauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider), isEmpty); // çıkış → kayboldu
    expect(store.data, hasLength(1)); // disk DURUYOR

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Authenticated(testUser));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedRoutesProvider).single.id, 'r1'); // geri geldi
  });

  test('JSON gidiş-dönüş: SAHİP KİMLİĞİ korunur (hesap kapısı)', () {
    final SavedRoute? back =
        SavedRoute.fromJson(_sample.withOwner('u1').toJson());
    expect(back?.ownerUid, 'u1');
    // Sahipsiz eski kayıt alanı hiç yazmaz — eski biçim bozulmaz.
    expect(_sample.toJson().containsKey('owner'), isFalse);
  });
}
