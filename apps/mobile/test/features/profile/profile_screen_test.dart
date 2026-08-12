import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/deck/presentation/deck_screen.dart'
    show deckSegmentProvider;
import 'package:dockly_mobile/features/logbook/presentation/logbook_screen.dart';
import 'package:dockly_mobile/features/profile/presentation/profile_screen.dart';
import 'package:dockly_mobile/features/shell/application/shell_tab_provider.dart';
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

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
      listen: false,
    );

void main() {
  testWidgets('TEK EV (UX P1 2026-08): tekne KARTI Profil\'den kalktı; '
      '"Teknem" köprüsü sekmeye götürür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(boat: const MyBoat(lengthM: 12, draftM: 1.8)));
    await tester.pumpAndSettle();

    // Kart yok: boy/su çekimi/Düzenle/Kaldır artık yalnız Teknem sekmesinde.
    expect(find.text('Boy 12 m'), findsNothing);
    expect(find.text('Su çekimi 1.8 m'), findsNothing);
    expect(find.text('Düzenle'), findsNothing);
    expect(find.text('Kaldır'), findsNothing);

    // Köprü var ve Teknem sekmesine (dizin 3) geçirir.
    expect(find.text('Teknem'), findsOneWidget);
    await tester.tap(find.text('Teknem'));
    await tester.pump();
    expect(_containerOf(tester).read(shellTabProvider), 3);
  });

  testWidgets('TEK EV: "Kaptanın Günlüğü" satırı ayrı ekran AÇMAZ — '
      'Defter/Notlar\'a yönlendirir', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaptanın Günlüğü'));
    await tester.pumpAndSettle();

    // İkinci kapı (ayrı LogbookScreen) AÇILMADI…
    expect(find.byType(LogbookScreen), findsNothing);
    // …yönlendirme kuruldu: Defter sekmesi (2) + Notlar bölümü (2).
    final ProviderContainer c = _containerOf(tester);
    expect(c.read(shellTabProvider), 2);
    expect(c.read(deckSegmentProvider), 2);
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
