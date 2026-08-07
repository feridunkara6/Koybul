import 'package:dockly_mobile/features/boat/presentation/boat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TEKNEM v0 testleri (v2.0): tekne yokken tanımlama daveti görünür.
void main() {
  testWidgets('tekne yok → kimlik kartında tanımlama daveti',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: BoatScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tekneni tanımla'), findsOneWidget);
  });
}
