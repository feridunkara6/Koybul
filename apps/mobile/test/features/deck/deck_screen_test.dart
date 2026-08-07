import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/deck/presentation/deck_screen.dart';
import 'package:dockly_mobile/features/logbook/application/logbook_controller.dart';
import 'package:dockly_mobile/features/logbook/domain/log_entry.dart';
import 'package:dockly_mobile/features/route/application/saved_routes_controller.dart';
import 'package:dockly_mobile/features/route/domain/saved_route.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/logbook_fakes.dart';
import '../../support/saved_routes_fakes.dart';

const SavedRoute _route = SavedRoute(
  id: 'r1',
  name: 'Datça turu',
  origin: RouteOrigin(pos: GeoPoint(lat: 36.70, lon: 27.70), name: 'Datça'),
  waypoints: <RouteWaypoint>[
    RouteWaypoint(pos: GeoPoint(lat: 36.75, lon: 28.93), id: 'loc-1', name: 'Göcek'),
  ],
  distanceNm: 20,
  savedAtMs: 1000,
);

Widget _app({List<SavedRoute> routes = const <SavedRoute>[], List<LogEntry> notes = const <LogEntry>[]}) {
  final FakeLogbookStore logs = FakeLogbookStore()..data = List<LogEntry>.of(notes);
  return ProviderScope(
    overrides: <Override>[
      savedRoutesStoreProvider.overrideWithValue(
          FakeSavedRoutesStore()..data = List<SavedRoute>.of(routes)),
      logbookStoreProvider.overrideWithValue(logs),
    ],
    child: const MaterialApp(home: DeckScreen()),
  );
}

/// DEFTER v0 testleri (v2.0, kurucu onayı 2026-08): Rotalarım + Notlar.
void main() {
  testWidgets('Rotalarım: kayıtlı rota İSMİYLE listelenir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(routes: <SavedRoute>[_route]));
    await tester.pumpAndSettle();

    expect(find.text('Datça turu'), findsOneWidget);
    expect(find.text('Haritada aç'), findsOneWidget);
  });

  testWidgets('Notlar segmenti: günlük kaydı görünür; FAB yeni not açar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(notes: <LogEntry>[
      const LogEntry(id: 'l1', dateMs: 1700000000000, text: 'Sakin bir akşam.'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notlar'));
    await tester.pumpAndSettle();
    expect(find.text('Sakin bir akşam.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deck-note-new')), findsOneWidget);
  });
}
