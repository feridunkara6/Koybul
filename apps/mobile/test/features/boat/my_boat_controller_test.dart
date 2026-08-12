import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/data/shared_prefs_boat_storage.dart';
import 'package:dockly_mobile/features/boat/domain/boat_storage.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

ProviderContainer _containerWith(FakeBoatStorage storage) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[boatStorageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Eklenti mock'u için binding gerekir (gerçek shared_preferences testi).
  TestWidgetsFlutterBinding.ensureInitialized();

  test('set → durumu günceller ve depoya yazar', () async {
    final FakeBoatStorage storage = FakeBoatStorage();
    final ProviderContainer c = _containerWith(storage);
    c.read(myBoatProvider.notifier).set(const MyBoat(lengthM: 12, draftM: 1.8));
    await _tick();
    expect(c.read(myBoatProvider)?.lengthM, 12);
    expect(storage.stored?.draftM, 1.8);
  });

  test('build → depodaki tekneyi geri yükler', () async {
    final FakeBoatStorage storage = FakeBoatStorage()
      ..stored = const MyBoat(lengthM: 10, draftM: 1.5);
    final ProviderContainer c = _containerWith(storage);
    expect(c.read(myBoatProvider), isNull); // build anında null; restore async
    await _tick();
    expect(c.read(myBoatProvider)?.lengthM, 10);
    expect(c.read(myBoatProvider)?.draftM, 1.5);
  });

  test('clear → durumu ve depoyu temizler', () async {
    final FakeBoatStorage storage = FakeBoatStorage()..stored = const MyBoat(lengthM: 10);
    final ProviderContainer c = _containerWith(storage);
    await _tick(); // restore çalışsın
    c.read(myBoatProvider.notifier).clear();
    await _tick();
    expect(c.read(myBoatProvider), isNull);
    expect(storage.stored, isNull);
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
