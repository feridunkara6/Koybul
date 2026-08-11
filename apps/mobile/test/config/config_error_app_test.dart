import 'package:dockly_mobile/config/config_error_app.dart';
import 'package:dockly_mobile/config/flavor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hata ekranı testleri: yanlış yapılandırılmış bir yayın derlemesi ölü bir
/// ekran yerine SEBEBİNİ gösterir.
void main() {
  testWidgets('her kusur için ekran çizilir ve çözümü yazar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final ConfigProblem problem in ConfigProblem.values) {
      await tester.pumpWidget(ConfigErrorApp(
        problem: problem,
        rawApiBaseUrl: 'http://localhost:3000',
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('config-error')), findsOneWidget,
          reason: '$problem');
      expect(find.text('DERLEME YAPILANDIRMASI HATALI'), findsOneWidget,
          reason: '$problem');
      expect(find.text(configProblemText(problem, 'http://localhost:3000').title),
          findsOneWidget,
          reason: '$problem');
      expect(find.byKey(const ValueKey<String>('config-error-fix')),
          findsOneWidget,
          reason: '$problem');
    }
  });

  testWidgets('sorunlu adresin kendisi ekranda görünür (teşhis edilebilsin)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ConfigErrorApp(
      problem: ConfigProblem.localUrlInRelease,
      rawApiBaseUrl: 'http://10.0.2.2:3000',
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('http://10.0.2.2:3000'), findsOneWidget);
  });

  testWidgets('mağaza incelemecisi için tek satır İngilizce vardır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ConfigErrorApp(
      problem: ConfigProblem.missingUrl,
      rawApiBaseUrl: '',
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('This build is misconfigured'), findsOneWidget);
  });
}
