import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sabit tekne döndüren kontrolcü (depolamaya gitmez).
class _FixedBoat extends MyBoatController {
  _FixedBoat(this._boat);
  final MyBoat _boat;
  @override
  MyBoat? build() => _boat;
}

Widget _app({MyBoat? boat}) {
  return ProviderScope(
    overrides: <Override>[
      if (boat != null) myBoatProvider.overrideWith(() => _FixedBoat(boat)),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

void main() {
  testWidgets('tekne yoksa "Tekneni tanımla" daveti gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Teknem'), findsOneWidget);
    expect(find.text('Tekneni tanımla'), findsOneWidget);
  });

  testWidgets('tekne varsa boy ve su çekimi gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(boat: const MyBoat(lengthM: 12, draftM: 1.8)));
    await tester.pumpAndSettle();
    expect(find.text('Boy 12 m'), findsOneWidget);
    expect(find.text('Su çekimi 1.8 m'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Kaldır'), findsOneWidget);
  });

  testWidgets('Acil Durum kartı en üstte; dokununca sayfa açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Acil Durum'), findsOneWidget);
    await tester.tap(find.text('Acil Durum'));
    await tester.pumpAndSettle();

    expect(find.text('Tehlikede misin?'), findsOneWidget); // Acil Durum sayfası
    expect(find.text('158'), findsOneWidget);
  });

  testWidgets('Düzenle → tekne tanımlama sayfası açılır', (WidgetTester tester) async {
    await tester.pumpWidget(_app(boat: const MyBoat(lengthM: 12)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('Tekneni tanımla'), findsOneWidget); // alt sayfa başlığı
  });

  testWidgets('YASAL satırı var ve yasal metinlere götürür (Faz 0)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik ve yasal metinler'), findsOneWidget);
    await tester.tap(find.text('Gizlilik ve yasal metinler'));
    await tester.pumpAndSettle();
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
  });

  testWidgets('BOŞ "Taleplerim" ekranı kaldırıldı (mağaza ret riski)',
      (WidgetTester tester) async {
    // İçi "yakında" yazan bir menü girişiydi; Apple olmayan özelliği duyuran
    // uygulamayı reddediyor. Geri gelirse bu test kırılsın.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Taleplerim'), findsNothing);
  });
}
