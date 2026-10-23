import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/boat_storage.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bellekte tutan sahte depolama (gerçek shared_preferences teste girmez).
class _FakeBoatStorage implements BoatStorage {
  MyBoat? stored;

  @override
  Future<MyBoat?> load() async => stored;

  @override
  Future<void> save(MyBoat boat) async => stored = boat;

  @override
  Future<void> clear() async => stored = null;
}

/// Alt sayfayı gerçek akışla (düğmeden) açan taşıyıcı.
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey<String>('open-sheet'),
            onPressed: () => showBoatSheet(context),
            child: const Text('aç'),
          ),
        ),
      );
}

Widget _app(_FakeBoatStorage storage) => ProviderScope(
      overrides: <Override>[
        boatStorageProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(home: _Launcher()),
    );

Future<void> _openSheet(WidgetTester tester, _FakeBoatStorage storage) async {
  // Alt sayfa içeriği uzun (katalog alanları) — görünür alan büyütülür
  // (CI dersi: lazy liste/kaydırma testlerinde dar görünüm eleman bulamaz).
  tester.view.physicalSize = const Size(800, 1900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(storage));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('open-sheet')));
  await tester.pumpAndSettle();
}

/// TEKNE KATALOĞU formu testleri (Teknem paketi, kurucu onayı 2026-10-23):
/// tüm katalog alanları OPSİYONEL — "bilmiyorum" geçerli cevaptır.
void main() {
  testWidgets('katalog alanları kaydedilir: tür çipi + marka + model + yıl',
      (WidgetTester tester) async {
    final _FakeBoatStorage storage = _FakeBoatStorage();
    await _openSheet(tester, storage);

    expect(find.text('Tekne türü'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('boat-type-sail')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey<String>('boat-brand-field')), 'Beneteau');
    await tester.pumpAndSettle();
    // Öneri listesi yazarken yol gösterir (2+ harf) — ama zorlamaz.
    expect(find.text('Beneteau'), findsWidgets);
    await tester.enterText(
        find.byKey(const ValueKey<String>('boat-model-field')), 'Oceanis 38.1');
    await tester.enterText(
        find.byKey(const ValueKey<String>('boat-year-field')), '2017');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tekne boyu (m)'), '11.5');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final MyBoat? saved = storage.stored;
    expect(saved, isNotNull);
    expect(saved!.lengthM, 11.5);
    expect(saved.typeId, 'sail');
    expect(saved.brand, 'Beneteau');
    expect(saved.model, 'Oceanis 38.1');
    expect(saved.buildYear, 2017);
    // Alt sayfa kapandı.
    expect(find.text('Tekne türü'), findsNothing);
  });

  testWidgets('GEÇERSİZ yıl kaydettirmez; boş yıl "bilinmiyor" olarak geçerli',
      (WidgetTester tester) async {
    final _FakeBoatStorage storage = _FakeBoatStorage();
    await _openSheet(tester, storage);

    await tester.enterText(
        find.widgetWithText(TextField, 'Tekne boyu (m)'), '9');
    await tester.enterText(
        find.byKey(const ValueKey<String>('boat-year-field')), '1200');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Sınır dışı yıl: dürüst hata, kayıt YOK, sayfa açık kalır.
    expect(
        find.text('Model yılı 1850-2027 arasında olmalı — bilinmiyorsa boş '
            'bırak.'),
        findsOneWidget);
    expect(storage.stored, isNull);

    // Yıl boşaltılınca kayıt geçer — yıl null (uydurma yıl yazılmaz).
    await tester.enterText(
        find.byKey(const ValueKey<String>('boat-year-field')), '');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(storage.stored, isNotNull);
    expect(storage.stored!.lengthM, 9);
    expect(storage.stored!.buildYear, isNull);
    expect(storage.stored!.typeId, isNull); // tür seçilmedi — uydurulmaz
  });
}
