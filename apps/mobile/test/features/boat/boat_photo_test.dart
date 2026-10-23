import 'dart:io';

import 'package:dockly_mobile/features/boat/application/boat_photo_controller.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_photo_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/boat_photo_fakes.dart';

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

/// 1×1 saydam PNG — testin ÜRETTİĞİ geçerli örnek dosya (dışarıdan görsel
/// alınmaz; gerçek fotoğraf yerine teknik yer tutucu).
const List<int> _tinyPng = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0b, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7a, 0x5e, 0xab, 0x3f, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];

/// Geçici klasöre örnek fotoğraf yazar; test bitince klasör silinir.
String _writeTempPhoto() {
  final Directory dir = Directory.systemTemp.createTempSync('koybul_boat');
  addTearDown(() => dir.deleteSync(recursive: true));
  final File f = File('${dir.path}/tekne_fotografi.png');
  f.writeAsBytesSync(_tinyPng);
  return f.path;
}

Widget _app(FakeBoatPhotoStore store, {MyBoat? boat}) => ProviderScope(
      overrides: <Override>[
        boatPhotoStoreProvider.overrideWithValue(store),
        if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
      ],
      child: const MaterialApp(home: Scaffold(body: BoatPhotoHeader())),
    );

/// Gerçek dosya IO'su (Image.file okuma/çözme) fake-async içinde askıda
/// kalmasın diye kısa bir gerçek-zaman nefesi verir.
Future<void> _settleIo(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump();
}

/// TEKNE FOTOĞRAFI testleri (Teknem paketi, kurucu onayı 2026-10-23):
/// kaynak çipi HER ZAMAN doğruyu söyler; fotoğraf yalnız cihazda durur.
void main() {
  testWidgets('fotoğraf yokken: tür illüstrasyonu + dürüst kaynak çipi; alt '
      'sayfada "illüstrasyona dön" seçeneği YOK', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeBoatPhotoStore(),
      boat: const MyBoat(lengthM: 10, typeId: 'motor'),
    ));
    await tester.pumpAndSettle();

    // Emoji dönemi kapandı (Çizim Kütüphanesi Paket 1): türün DOLGULU
    // teknik çizimi gösterilir — anahtar tür kimliğini taşır.
    expect(find.byKey(const ValueKey<String>('boat-art-motor')),
        findsOneWidget);
    expect(find.textContaining('TİP ÇİZİMİ'), findsOneWidget);
    expect(find.textContaining('SENİN FOTOĞRAFIN'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Galeriden seç'), findsOneWidget);
    // Silinecek fotoğraf yok → seçenek de yok (yalancı düğme olmaz).
    expect(find.byKey(const ValueKey<String>('boat-photo-clear')), findsNothing);
    // Gizlilik sözü her açılışta görünür.
    expect(find.textContaining('yalnız senin cihazında'), findsOneWidget);
  });

  testWidgets('kayıtlı fotoğraf: "SENİN FOTOĞRAFIN" çipi; illüstrasyona dönünce '
      'çip dürüstçe geri döner', (WidgetTester tester) async {
    final FakeBoatPhotoStore store =
        FakeBoatPhotoStore(stored: _writeTempPhoto());
    await tester.pumpWidget(_app(
      store,
      boat: const MyBoat(lengthM: 10, typeId: 'sail'),
    ));
    await tester.pumpAndSettle();
    await _settleIo(tester);

    expect(find.textContaining('SENİN FOTOĞRAFIN'), findsOneWidget);
    expect(find.textContaining('TİP ÇİZİMİ'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-btn')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey<String>('boat-photo-clear')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-clear')));
    await tester.pumpAndSettle();

    expect(store.clearCount, 1);
    expect(find.textContaining('TİP ÇİZİMİ'), findsOneWidget);
    expect(find.textContaining('SENİN FOTOĞRAFIN'), findsNothing);
  });

  testWidgets('galeriden seçim: alt sayfa kapanır ve çip "SENİN FOTOĞRAFIN" '
      'olur', (WidgetTester tester) async {
    final FakeBoatPhotoStore store =
        FakeBoatPhotoStore(nextPick: _writeTempPhoto());
    await tester.pumpWidget(_app(
      store,
      boat: const MyBoat(lengthM: 10, typeId: 'sail'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('TİP ÇİZİMİ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-gallery')));
    await tester.pumpAndSettle();
    await _settleIo(tester);

    expect(find.text('Galeriden seç'), findsNothing); // alt sayfa kapandı
    expect(find.textContaining('SENİN FOTOĞRAFIN'), findsOneWidget);
  });

  testWidgets('MODEL ÇİZİMİ: marka+model eşleşince modele özel çizim + '
      'dürüst rozet + BORDA ADI katmanı', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeBoatPhotoStore(),
      boat: const MyBoat(
        lengthM: 11.5,
        name: 'Martı',
        brand: 'Beneteau',
        model: 'Oceanis 38.1',
        typeId: 'sail',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('boat-art-model-oceanis_38')),
        findsOneWidget);
    expect(find.textContaining('MODEL ÇİZİMİ'), findsOneWidget);
    expect(find.textContaining('TİP ÇİZİMİ'), findsNothing);
    // Borda adı AYRI katmanda, çizimin üstünde (kurucu isteği).
    expect(find.byKey(const ValueKey<String>('boat-art-name')), findsOneWidget);
    expect(find.text('Martı'), findsOneWidget);
  });

  testWidgets('bilinmeyen model TÜR çizimine düşer; ad girilmemişse borda '
      'adı yazılmaz (uydurma yok)', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeBoatPhotoStore(),
      boat: const MyBoat(
        lengthM: 12,
        brand: 'Najad',
        model: '390',
        typeId: 'sail',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('boat-art-sail')), findsOneWidget);
    expect(find.textContaining('TİP ÇİZİMİ'), findsOneWidget);
    expect(find.textContaining('MODEL ÇİZİMİ'), findsNothing);
    expect(find.byKey(const ValueKey<String>('boat-art-name')), findsNothing);
  });

  testWidgets('GULET boy varyantı: 24 m gulet büyük çizimi alır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeBoatPhotoStore(),
      boat: const MyBoat(lengthM: 24, typeId: 'gulet'),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('boat-art-gulet_buyuk')),
        findsOneWidget);
    expect(find.textContaining('TİP ÇİZİMİ'), findsOneWidget);
  });

  testWidgets('seçimden VAZGEÇMEK mevcut durumu değiştirmez',
      (WidgetTester tester) async {
    final FakeBoatPhotoStore store = FakeBoatPhotoStore(); // nextPick yok
    await tester.pumpWidget(_app(
      store,
      boat: const MyBoat(lengthM: 10, typeId: 'sail'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('boat-photo-camera')));
    await tester.pumpAndSettle();

    expect(find.textContaining('TİP ÇİZİMİ'), findsOneWidget);
    expect(find.textContaining('SENİN FOTOĞRAFIN'), findsNothing);
  });
}
