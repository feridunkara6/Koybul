import 'package:dockly_mobile/features/deria/application/deria_controller.dart';
import 'package:dockly_mobile/features/deria/presentation/deria_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/deria_fakes.dart';

/// DERİA doluluk kutusu testleri (kurucu kararı 2026-08).
///
/// Kilitlenen sözleşmeler: eşlenmemiş/verisiz/bayat → kutu HİÇ yok; canlı
/// veri → sayı + kaynak atfı + rezervasyon düğmesi; 0 boş → dürüstçe 0.
Widget _app(FakeDeriaGateway gw, String slug) {
  return ProviderScope(
    overrides: <Override>[deriaGatewayProvider.overrideWithValue(gw)],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DeriaAvailabilityBox(slug: slug)),
      ),
    ),
  );
}

void main() {
  testWidgets('eşlenmiş koyda sayı, kaynak atfı ve rezervasyon düğmesi görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeDeriaGateway(result: sampleDeria()),
      'boynuzbuku-samandira-sahasi',
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('deria-box')), findsOneWidget);
    expect(find.text('66'), findsOneWidget);
    expect(find.text('/ 84 şamandıra boş'), findsOneWidget);
    expect(find.textContaining('DERİA (Türkiye Çevre Ajansı)'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deria-reserve')), findsOneWidget);
    expect(find.text("DERİA'da rezervasyon yap"), findsOneWidget);
  });

  testWidgets('SIFIR boş dürüstçe gösterilir (kutu gizlenmez)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeDeriaGateway(result: sampleDeria()),
      'gobun-samandira-sahasi',
    ));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('/ 11 şamandıra boş'), findsOneWidget);
  });

  testWidgets('eşlenmemiş kayıtta kutu HİÇ çizilmez',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeDeriaGateway(result: sampleDeria()),
      'd-marin-gocek',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('deria-box')), findsNothing);
  });

  testWidgets('kaynak HATA verirse kutu çizilmez, ekran kırılmaz',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeDeriaGateway(fail: true),
      'boynuzbuku-samandira-sahasi',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('deria-box')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BAYAT veri (45 dk+) gösterilmez — denizde bayat "boş" yalandır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      FakeDeriaGateway(
        result: sampleDeria(
          fetchedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 50)),
        ),
      ),
      'boynuzbuku-samandira-sahasi',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('deria-box')), findsNothing);
  });

  test('deriaCoveFor: bayatlık sınırı tam kDeriaMaxAge', () {
    final DateTime now = DateTime.utc(2026, 8, 12, 12);
    final a = sampleDeria(
        fetchedAt: now.subtract(const Duration(minutes: 44)));
    expect(deriaCoveFor(a, 'tersane-adasi-koyu', now), isNotNull);
    final b = sampleDeria(
        fetchedAt: now.subtract(const Duration(minutes: 46)));
    expect(deriaCoveFor(b, 'tersane-adasi-koyu', now), isNull);
    expect(deriaCoveFor(null, 'tersane-adasi-koyu', now), isNull);
  });
}
