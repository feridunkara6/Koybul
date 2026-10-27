import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_state.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/deck/domain/sea_trip_log.dart';
import 'package:dockly_mobile/features/logbook/application/logbook_controller.dart';
import 'package:dockly_mobile/features/logbook/domain/log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/logbook_fakes.dart';
import '../../support/trip_fakes.dart';

/// DEFTER HESAP KAPISI (saha hatası 2026-10-27, "çıkış yapınca defterde
/// kayıtlı rota kalıyor"): asıl kalan şey SEYİRLERDİ — planlanan rota
/// kartları tripLog'da yaşar ve kapı yalnız Rotalarım'daydı. Bu dosya,
/// Defter'in kalan iki rafını (Seyirler + Günlük notları) kayıtlı
/// rotalardakiyle AYNI kurala bağlar: çıkışta boşalır, dönüşte geri gelir,
/// eski kayıt sahiplenilir, başkasının kaydı korunur ama gösterilmez.
void main() {
  SeaTripLog trip(String id, {String? owner, int dateMs = 1000}) => SeaTripLog(
        id: id,
        name: 'Göcek turu',
        status: TripStatus.planned,
        dateMs: dateMs,
        distanceNm: 12,
        stops: 2,
        ownerUid: owner,
      );

  LogEntry note(String id, {String? owner, int dateMs = 1000}) => LogEntry(
        id: id,
        dateMs: dateMs,
        text: 'Poyraz sertti, koy sakindi.',
        ownerUid: owner,
      );

  ProviderContainer container({
    FakeTripStore? trips,
    FakeLogbookStore? logs,
    List<Override> extra = const <Override>[],
  }) {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        tripStoreProvider.overrideWithValue(trips ?? FakeTripStore()),
        logbookStoreProvider.overrideWithValue(logs ?? FakeLogbookStore()),
        if (extra.isEmpty) signedInAuthOverride(),
        ...extra,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('SEYİRLER: çıkışta liste boşalır, aynı hesapla dönünce geri gelir; '
      'disk hiç silinmez', () async {
    final FakeTripStore store = FakeTripStore()
      ..data = <SeaTripLog>[trip('t1', owner: testUser.id)];
    final ProviderContainer c = container(trips: store, extra: <Override>[
      authControllerProvider.overrideWith(
          () => SwitchableAuthController(const Authenticated(testUser))),
    ]);
    c.read(tripLogProvider); // tembel sağlayıcıyı kur (CI dersi 5.6)
    await Future<void>.delayed(Duration.zero);
    expect(c.read(tripLogProvider), hasLength(1));

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Unauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(tripLogProvider), isEmpty); // çıkış → Seyirler boş
    expect(store.data, hasLength(1)); // disk DURUYOR

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Authenticated(testUser));
    c.read(tripLogProvider); // geçiş sonrası da tembel — önce oku
    await Future<void>.delayed(Duration.zero);
    expect(c.read(tripLogProvider).single.id, 't1'); // geri geldi
  });

  test('SEYİRLER: sahipsiz eski kayıt ilk hesaplı açılışta sahiplenilir; '
      'başkasının kaydı gösterilmez ama ekleme sırasında korunur', () async {
    final FakeTripStore store = FakeTripStore()
      ..data = <SeaTripLog>[
        trip('eski'), // kapıdan önce — sahipsiz
        trip('el', owner: 'baska-hesap'),
      ];
    final ProviderContainer c = container(trips: store);
    c.read(tripLogProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(tripLogProvider).single.id, 'eski'); // sahiplenildi
    expect(c.read(tripLogProvider).single.ownerUid, testUser.id);

    await c.read(tripLogProvider.notifier).add(trip('yeni', dateMs: 2000));
    expect(c.read(tripLogProvider), hasLength(2));
    expect(store.data, hasLength(3)); // başkasının kaydı SİLİNMEDİ
    expect(
        store.data.any((SeaTripLog t) => t.ownerUid == 'baska-hesap'), isTrue);
  });

  test('SEYİRLER: misafir plan yazamaz (emniyet kemeri — kapı arayüzde)',
      () async {
    final FakeTripStore store = FakeTripStore();
    final ProviderContainer c = container(trips: store, extra: <Override>[
      authControllerProvider
          .overrideWith(() => FixedAuthController(const Unauthenticated())),
    ]);
    c.read(tripLogProvider);
    await c.read(tripLogProvider.notifier).add(trip('t1'));
    expect(c.read(tripLogProvider), isEmpty);
    expect(store.data, isEmpty);
  });

  test('GÜNLÜK: çıkışta notlar görünmez olur, dönüşte geri gelir; '
      'sahipsiz eski giriş sahiplenilir', () async {
    final FakeLogbookStore store = FakeLogbookStore()
      ..data = <LogEntry>[note('eski')]; // kapıdan önce yazılmış
    final ProviderContainer c = container(logs: store, extra: <Override>[
      authControllerProvider.overrideWith(
          () => SwitchableAuthController(const Authenticated(testUser))),
    ]);
    c.read(logbookProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(logbookProvider).single.ownerUid, testUser.id);

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Unauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(logbookProvider), isEmpty); // çıkış → Notlar boş
    expect(store.data, hasLength(1)); // disk DURUYOR

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Authenticated(testUser));
    c.read(logbookProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(logbookProvider).single.id, 'eski');
  });

  test('GÜNLÜK: başka hesabın girişi gösterilmez; ekleme/silme onu silmez',
      () async {
    final FakeLogbookStore store = FakeLogbookStore()
      ..data = <LogEntry>[note('el', owner: 'baska-hesap')];
    final ProviderContainer c = container(logs: store);
    c.read(logbookProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(logbookProvider), isEmpty);

    await c.read(logbookProvider.notifier).add(note('benim', dateMs: 2000));
    expect(c.read(logbookProvider).single.id, 'benim');
    expect(store.data, hasLength(2)); // yabancı giriş korunur

    await c.read(logbookProvider.notifier).remove('benim');
    expect(store.data.single.ownerUid, 'baska-hesap');
  });

  test('JSON gidiş-dönüş: SAHİP KİMLİĞİ iki modelde de korunur; eski biçim '
      'alan yazmaz', () {
    final SeaTripLog? t = SeaTripLog.fromJson(trip('t1', owner: 'u1').toJson());
    expect(t?.ownerUid, 'u1');
    expect(trip('t1').toJson().containsKey('owner'), isFalse);
    final LogEntry? e = LogEntry.fromJson(note('l1', owner: 'u1').toJson());
    expect(e?.ownerUid, 'u1');
    expect(note('l1').toJson().containsKey('owner'), isFalse);
  });
}
