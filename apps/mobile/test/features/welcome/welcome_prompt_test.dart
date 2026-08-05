import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/map/application/map_controller.dart';
import 'package:dockly_mobile/features/map/presentation/map_surface.dart';
import 'package:dockly_mobile/features/shell/presentation/dockly_shell.dart';
import 'package:dockly_mobile/features/welcome/presentation/welcome_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_map_surface.dart';
import '../../support/map_fakes.dart';
import '../../support/welcome_fakes.dart';

Widget _app({required FakeWelcomeStore store, FakeBoatStorage? boatStorage}) {
  return ProviderScope(
    overrides: <Override>[
      mapLocationsGatewayProvider.overrideWithValue(FakeMapGateway(result: pinResult)),
      mapSurfaceBuilderProvider.overrideWithValue(fakeMapSurfaceBuilder()),
      mapDebounceProvider.overrideWithValue(Duration.zero),
      mapCacheProvider.overrideWithValue(FakeMapCache()),
      welcomeStoreProvider.overrideWithValue(store),
      boatStorageProvider.overrideWithValue(boatStorage ?? FakeBoatStorage()),
    ],
    child: const MaterialApp(home: DocklyShell()),
  );
}

/// ESKİ KARŞILAMA SORUSU — EMEKLİLİK SÖZLEŞMESİ (Paket 2, 2026-08).
///
/// "Teknen kaç metre?" açılır penceresi kabuktan KALDIRILDI: tekne bilgisi
/// artık onaylı açılış akışında (E3–E4, launch_gate_test) soruluyor ve aynı
/// Teknem modeline yazılıyor. Bu dosya eski davranışın GERİ GELMEDİĞİNİ ve
/// paylaşılan yardımcıların doğru kaldığını korur.
void main() {
  testWidgets('kabuk AÇILINCA eski karşılama sorusu ÇIKMAZ (görev E3–E4\'te)',
      (WidgetTester tester) async {
    final FakeWelcomeStore store = FakeWelcomeStore(); // hiç sorulmamış olsa bile
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Hoş geldin, kaptan'), findsNothing);
    expect(find.byType(WelcomeSheetBody), findsNothing);
    // Kabuk depoya DOKUNMAZ: bayrak yazılmaz, sayaç oynamaz.
    expect(store.shown, isFalse);
    expect(store.markCount, 0);
  });

  testWidgets('tekne kayıtlıyken de kabuk sessiz: soru yok, bayrak yazılmaz',
      (WidgetTester tester) async {
    final FakeWelcomeStore store = FakeWelcomeStore();
    await tester.pumpWidget(_app(
      store: store,
      boatStorage: FakeBoatStorage(boat: const MyBoat(lengthM: 15)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hoş geldin, kaptan'), findsNothing);
    expect(store.markCount, 0);
    // Tekne cihazdan geri yüklenmeye devam eder (rozetler çalışsın).
    // Geri yükleme ASENKRON: önce sağlayıcıyı kur, akmasını bekle, sonra oku.
    final ProviderContainer container =
        ProviderScope.containerOf(tester.element(find.byType(DocklyShell)));
    container.read(myBoatProvider);
    await tester.pumpAndSettle();
    expect(container.read(myBoatProvider)?.lengthM, 15);
  });

  test('feetToMeters: 1 ft = 0.3048 m, 1 ondalık', () {
    expect(feetToMeters(39), 11.9);
    expect(feetToMeters(26), 7.9);
    expect(feetToMeters(79), 24.1);
  });
}
