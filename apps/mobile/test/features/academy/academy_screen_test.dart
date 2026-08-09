import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/features/academy/data/academy_content.dart';
import 'package:dockly_mobile/features/academy/presentation/academy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AKADEMİ ekranı testleri (v2.0): rehberler listelenir, rehber açılır,
/// dürüstlük notu her iki ekranda da görünür.
void main() {
  testWidgets('liste: 10 rehber satırı + dürüstlük notu',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AcademyScreen()),
    ));
    await tester.pumpAndSettle();

    // İlk satır açılışta görünür.
    expect(find.byKey(const ValueKey<String>('academy-anchor')), findsOneWidget);
    expect(find.text('Demir atma'), findsOneWidget);
    // TEMBEL LİSTE DERSİ (CI 2026-08): alttaki satırlar ve dürüstlük notu
    // ancak kaydırınca kurulur — doğrudan aranırsa "0 widget" bulunur.
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('academy-mayday')), 200);
    expect(find.byKey(const ValueKey<String>('academy-mayday')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('resmî eğitimin'), 200);
    expect(find.textContaining('resmî eğitimin'), findsOneWidget);
  });

  testWidgets('rehbere dokununca adımlar ve kaptan notu açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AcademyScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('academy-anchor')));
    await tester.pumpAndSettle();

    expect(find.text('Uygulama adımları'), findsOneWidget);
    expect(find.textContaining('Zincir boyu kuraldır'), findsOneWidget);
    expect(find.text('Kaptan notu'), findsOneWidget);
    // Dürüstlük notu rehber sayfasında da durur.
    expect(find.textContaining('Karar her zaman kaptanındır'), findsOneWidget);
  });

  testWidgets('dil değişince rehberler o dilde gelir',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        appLocaleProvider
            .overrideWith(() => AppLocaleController(AppLocale.en)),
      ],
      child: const MaterialApp(home: AcademyScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Anchoring'), findsOneWidget);
    expect(find.text('Demir atma'), findsNothing);
    expect(academyGuides(AppLocale.en), hasLength(kAcademyGuideCount));
  });
}
