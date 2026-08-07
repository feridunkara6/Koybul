import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/today/presentation/today_screen.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/checklist_fakes.dart';
import '../../support/weather_fakes.dart';

/// BUGÜN v0 testleri (v2.0): konum yokken dürüst yönlendirme; kontrol
/// listesi düğmesi listeyi açar.
void main() {
  testWidgets('konum yokken hava kartı yerine yönlendirme metni',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
        checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('konumunu paylaş'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('today-checklist')), findsOneWidget);

    // Düğme kontrol listesini açar.
    await tester.tap(find.byKey(const ValueKey<String>('today-checklist')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('checklist-0')), findsOneWidget);
  });
}
