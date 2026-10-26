import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_state.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/data/shared_prefs_boat_storage.dart';
import 'package:dockly_mobile/features/boat/domain/boat_storage.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/auth_fakes.dart';

/// Bellekte tutan sahte depolama.
class FakeBoatStorage implements BoatStorage {
  MyBoat? stored;

  @override
  Future<MyBoat?> load() async => stored;

  @override
  Future<void> save(MyBoat boat) async => stored = boat;

  @override
  Future<void> clear() async => stored = null;
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

/// HESAP KAPISI (2026-10-26): tekne hesaba bağlı — testlerin varsayılanı
/// "hesap açık" (testUser, id=u1). Misafir/çıkış senaryoları kendi
/// override'ını verir.
ProviderContainer _containerWith(FakeBoatStorage storage,
    {List<Override> extra = const <Override>[]}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      boatStorageProvider.overrideWithValue(storage),
      if (extra.isEmpty) signedInAuthOverride(),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Eklenti mock'u için binding gerekir (gerçek shared_preferences testi).
  TestWidgetsFlutterBinding.ensureInitialized();

  test('set → durumu günceller, depoya SAHİP KİMLİĞİYLE yazar', () async {
    final FakeBoatStorage storage = FakeBoatStorage();
    final ProviderContainer c = _containerWith(storage);
    c.read(myBoatProvider.notifier).set(const MyBoat(lengthM: 12, draftM: 1.8));
    await _tick();
    expect(c.read(myBoatProvider)?.lengthM, 12);
    expect(storage.stored?.draftM, 1.8);
    // HESAP KAPISI: kayıt, oturumdaki hesabın kimliğiyle damgalanır.
    expect(storage.stored?.ownerUid, testUser.id);
  });

  test('build → depodaki KENDİ tekneni geri yükler', () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored =
          MyBoat(lengthM: 10, draftM: 1.5, ownerUid: testUser.id);
    final ProviderContainer c = _containerWith(storage);
    expect(c.read(myBoatProvider), isNull); // build anında null; restore async
    await _tick();
    expect(c.read(myBoatProvider)?.lengthM, 10);
    expect(c.read(myBoatProvider)?.draftM, 1.5);
  });

  test('clear → durumu ve depoyu temizler', () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored = MyBoat(lengthM: 10, ownerUid: testUser.id);
    final ProviderContainer c = _containerWith(storage);
    await _tick(); // restore çalışsın
    c.read(myBoatProvider.notifier).clear();
    await _tick();
    expect(c.read(myBoatProvider), isNull);
    expect(storage.stored, isNull);
  });

  // ==========================================================================
  // HESAP KAPISI (kurucu kararı 2026-10-26): "hesap olmasa bile teknem kısmı
  // gözüküyor" hatası bir daha YAŞANMASIN — tekne hesapla gezer.
  // ==========================================================================

  test('HESAP KAPISI: misafir oturumda depoda tekne OLSA BİLE görünmez',
      () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored = MyBoat(lengthM: 10, ownerUid: testUser.id);
    final ProviderContainer c = _containerWith(storage, extra: <Override>[
      signedInAuthOverride(user: testGuest),
    ]);
    c.read(myBoatProvider); // CI DERSİ (5.6): sağlayıcı tembel — önce kur
    await _tick();
    expect(c.read(myBoatProvider), isNull); // misafir tekne GÖRMEZ
  });

  test('HESAP KAPISI: misafir set\'i (açılış akışı ölçü cevabı) SAHİPSİZ '
      'saklanır ama GÖSTERİLMEZ; ilk hesapta sahiplenilir', () async {
    final FakeBoatStorage storage = FakeBoatStorage();
    final ProviderContainer c = _containerWith(storage, extra: <Override>[
      signedInAuthOverride(user: testGuest),
    ]);
    await _tick();
    c.read(myBoatProvider.notifier).set(const MyBoat(lengthM: 9));
    await _tick();
    expect(c.read(myBoatProvider), isNull); // kapı delinmez
    expect(storage.stored?.lengthM, 9); // ama cevap çöpe gitmez
    expect(storage.stored?.ownerUid, isNull); // sahipsiz bekler
  });

  test('HESAP KAPISI: sahipsiz ESKİ kayıt ilk hesaplı açılışta sahiplenilir '
      '(kurucunun teknesi kaybolmaz)', () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored = const MyBoat(lengthM: 11, name: 'Martı'); // ownerUid YOK
    final ProviderContainer c = _containerWith(storage);
    // CI DERSİ (5.6 kırmızısı): Riverpod sağlayıcısı TEMBELDİR — ilk read
    // gelmeden build/restore hiç başlamaz; önce kur, sonra akmasını bekle.
    c.read(myBoatProvider);
    await _tick();
    expect(c.read(myBoatProvider)?.name, 'Martı'); // tekne geri geldi
    expect(storage.stored?.ownerUid, testUser.id); // ve artık bu hesabın
  });

  test('HESAP KAPISI: BAŞKA hesabın teknesi ne gösterilir ne silinir',
      () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored = const MyBoat(lengthM: 15, ownerUid: 'baska-hesap');
    final ProviderContainer c = _containerWith(storage);
    c.read(myBoatProvider); // tembel sağlayıcıyı kur
    await _tick();
    expect(c.read(myBoatProvider), isNull); // gösterilmez
    expect(storage.stored?.ownerUid, 'baska-hesap'); // depo DOKUNULMADI
  });

  test('HESAP KAPISI: çıkış yapınca tekne kaybolur, dönünce geri gelir '
      '(depo silinmez)', () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored = MyBoat(lengthM: 12, ownerUid: testUser.id);
    final ProviderContainer c = _containerWith(storage, extra: <Override>[
      authControllerProvider.overrideWith(
          () => SwitchableAuthController(const Authenticated(testUser))),
    ]);
    c.read(myBoatProvider); // tembel sağlayıcıyı kur (CI dersi 5.6)
    await _tick();
    expect(c.read(myBoatProvider)?.lengthM, 12);

    // ÇIKIŞ → tekne anında görünmez; cihazdaki kayıt durur.
    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Unauthenticated());
    await _tick();
    expect(c.read(myBoatProvider), isNull);
    expect(storage.stored?.lengthM, 12);

    // AYNI hesapla DÖNÜŞ → tekne geri gelir. (Tembellik dersi: geçişten
    // sonra da yeniden kuruluş ilk read'de başlar — önce oku, sonra bekle.)
    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Authenticated(testUser));
    c.read(myBoatProvider);
    await _tick();
    expect(c.read(myBoatProvider)?.lengthM, 12);
  });

  test('SharedPrefsBoatStorage: kaydet/yükle/temizle gidiş-dönüş', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SharedPrefsBoatStorage storage = SharedPrefsBoatStorage();

    await storage.save(const MyBoat(lengthM: 14.5, draftM: 2.1));
    final MyBoat? loaded = await storage.load();
    expect(loaded?.lengthM, 14.5);
    expect(loaded?.draftM, 2.1);

    await storage.clear();
    expect(await storage.load(), isNull);
  });

  test('SharedPrefsBoatStorage: SAHİP KİMLİĞİ gidiş-dönüş (hesap kapısı)',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SharedPrefsBoatStorage storage = SharedPrefsBoatStorage();

    await storage.save(const MyBoat(lengthM: 12, ownerUid: 'u1'));
    expect((await storage.load())?.ownerUid, 'u1');

    // Sahipsiz kaydetmek anahtarı SİLER (yarım/bayat kimlik kalmaz).
    await storage.save(const MyBoat(lengthM: 12));
    expect((await storage.load())?.ownerUid, isNull);
  });

  test('SharedPrefsBoatStorage: AD + BAĞLI MARİNA gidiş-dönüş (2026-08)',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SharedPrefsBoatStorage storage = SharedPrefsBoatStorage();

    await storage.save(const MyBoat(
      lengthM: 11,
      name: 'Martı',
      homeMarina:
          HomeMarina(id: 'dm1', name: 'D-Marin Göcek', lat: 36.75, lon: 28.93),
    ));
    final MyBoat? loaded = await storage.load();
    expect(loaded?.name, 'Martı');
    expect(loaded?.homeMarina?.id, 'dm1');
    expect(loaded?.homeMarina?.name, 'D-Marin Göcek');
    expect(loaded?.homeMarina?.lat, 36.75);
    expect(loaded?.homeMarina?.lon, 28.93);

    // Marina kaldırılınca dört anahtar da silinir (yarım kayıt kalmaz).
    await storage.save(const MyBoat(lengthM: 11, name: 'Martı'));
    final MyBoat? cleared = await storage.load();
    expect(cleared?.name, 'Martı');
    expect(cleared?.homeMarina, isNull);
  });

  test('SharedPrefsBoatStorage: YARIM marina kaydı marina yokmuş gibi okunur',
      () async {
    // Dört anahtardan biri eksikse (bozuk/eski kayıt) HomeMarina kurulamaz —
    // yarım koordinatla haritayı yanlış yere odaklamak yerine yok sayılır.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'boat.lengthM': 11.0,
      'boat.marina.id': 'dm1',
      'boat.marina.name': 'D-Marin Göcek',
      // lat/lon YOK
    });
    const SharedPrefsBoatStorage storage = SharedPrefsBoatStorage();
    final MyBoat? loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.homeMarina, isNull);
  });
}
