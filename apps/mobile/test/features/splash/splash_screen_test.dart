import 'package:dockly_mobile/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _gate(DateTime time, {Duration duration = const Duration(milliseconds: 200)}) {
  return ProviderScope(
    child: MaterialApp(
      home: SplashGate(
        duration: duration,
        now: () => time,
        child: const Scaffold(body: Text('HARITA')),
      ),
    ),
  );
}

/// Marka yüzeyini gündüz/gece varyantına göre bulur.
Finder _splash({required bool night}) => find.byWidgetPredicate(
    (Widget w) => w is BrandSplash && w.night == night);

void main() {
  test('gece kabulü: 19:00 ve sonrası ile 07:00 öncesi gecedir', () {
    expect(splashIsNight(DateTime(2026, 1, 1, 12)), isFalse);
    expect(splashIsNight(DateTime(2026, 1, 1, 18, 59)), isFalse);
    expect(splashIsNight(DateTime(2026, 1, 1, 19)), isTrue);
    expect(splashIsNight(DateTime(2026, 1, 1, 23)), isTrue);
    expect(splashIsNight(DateTime(2026, 1, 1, 5)), isTrue);
    expect(splashIsNight(DateTime(2026, 1, 1, 7)), isFalse);
  });

  testWidgets('gündüz (12:00): aydınlık marka yüzeyi; içerik ARKADA hazırlanır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_gate(DateTime(2026, 7, 13, 12)));
    await tester.pump();

    expect(_splash(night: false), findsOneWidget);
    expect(_splash(night: true), findsNothing);
    // Marka öğeleri: işaret + BÜYÜK K'li yazı + slogan + yükleme noktaları.
    expect(find.byKey(const ValueKey<String>('koybul-mark')), findsOneWidget);
    expect(find.text('Koybul'), findsOneWidget);
    expect(find.text('Denizde yerini bul.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('splash-dots')), findsOneWidget);
    // PERF sözleşmesi: içerik açılış ekranı görünürken de KURULUDUR (arkada
    // yüklenir) — kararma bitince hazır harita karşılar.
    expect(find.text('HARITA'), findsOneWidget);

    // Süre dolar + kararma biter → açılış katmanı ağaçtan tamamen kalkar.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('HARITA'), findsOneWidget);
    expect(find.byType(BrandSplash), findsNothing); // açılış tamamen kalktı
  });

  testWidgets('gece (22:00): koyu marka yüzeyi kullanılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_gate(DateTime(2026, 7, 13, 22)));
    await tester.pump();

    expect(_splash(night: true), findsOneWidget);
    expect(_splash(night: false), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(BrandSplash), findsNothing);
    expect(find.text('HARITA'), findsOneWidget);
  });

  testWidgets('DİKEY (telefon) ekranda aynı tasarım kendini ölçekler',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_gate(DateTime(2026, 7, 13, 12)));
    await tester.pump();

    expect(_splash(night: false), findsOneWidget);
    expect(find.text('Koybul'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('splash-dots')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('HARITA'), findsOneWidget);
  });

  testWidgets('sabaha karşı (05:00) da koyu yüzey kullanılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_gate(DateTime(2026, 7, 13, 5)));
    await tester.pump();
    expect(_splash(night: true), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('HARITA'), findsOneWidget);
  });
}
