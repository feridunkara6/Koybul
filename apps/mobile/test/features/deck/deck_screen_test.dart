import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/deck/domain/sea_trip_log.dart';
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
import '../../support/trip_fakes.dart';

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

Widget _app({
  List<SavedRoute> routes = const <SavedRoute>[],
  List<LogEntry> notes = const <LogEntry>[],
  FakeTripStore? trips,
}) {
  final FakeLogbookStore logs = FakeLogbookStore()..data = List<LogEntry>.of(notes);
  return ProviderScope(
    overrides: <Override>[
      savedRoutesStoreProvider.overrideWithValue(
          FakeSavedRoutesStore()..data = List<SavedRoute>.of(routes)),
      logbookStoreProvider.overrideWithValue(logs),
      tripStoreProvider.overrideWithValue(trips ?? FakeTripStore()),
    ],
    child: const MaterialApp(home: DeckScreen()),
  );
}

/// DEFTER testleri (v2.0, kurucu onayı 2026-08): Seyirler + Rotalarım + Notlar.
void main() {
  testWidgets('Seyirler açılışta: kayıt yoksa dürüst boş durum',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Henüz seyir kaydı yok'), findsOneWidget);
  });

  testWidgets('Seyirler: tamamlanan seyir adı/süresiyle listelenir; '
      'sezon kartı toplamları gösterir', (WidgetTester tester) async {
    final int year = DateTime.now().year;
    final int base = DateTime(year, 6, 1, 10).millisecondsSinceEpoch;
    final FakeTripStore store = FakeTripStore()
      ..data = <SeaTripLog>[
        SeaTripLog(
          id: 't1',
          name: 'Göcek → Bedri Rahmi',
          startMs: base,
          endMs: base + 90 * 60000, // 1 sa 30 dk
          distanceNm: 6.2,
          stops: 1,
        ),
      ];
    await tester.pumpWidget(_app(trips: store));
    await tester.pumpAndSettle();

    expect(find.text('Göcek → Bedri Rahmi'), findsOneWidget);
    expect(find.textContaining('1 sa 30 dk'), findsWidgets); // kart + sezon
    expect(find.text('$year sezonu'), findsOneWidget);
    // ≈ mesafe hem seyir kartında hem sezon özetinde görünür. (CI dersi:
    // çıplak '6.2' araması "1.6.2026" tarihini de yakalıyordu — ≈ ile ara.)
    expect(find.textContaining('≈ 6.2'), findsNWidgets(2));
  });

  testWidgets('SÜREN seyir Defter\'den bitirilebilir: kayıt listeye düşer',
      (WidgetTester tester) async {
    final FakeTripStore store = FakeTripStore()
      ..active = ActiveTrip(
        name: 'Datça turu',
        startMs: DateTime.now()
            .subtract(const Duration(minutes: 45))
            .millisecondsSinceEpoch,
        distanceNm: 12,
        stops: 1,
      );
    await tester.pumpWidget(_app(trips: store));
    await tester.pumpAndSettle();

    expect(find.textContaining('Seyir sürüyor'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('trip-finish-deck')));
    await tester.pumpAndSettle();

    // Süren kart gitti; tamamlanan seyir listede; depo temizlendi.
    expect(find.textContaining('Seyir sürüyor'), findsNothing);
    expect(find.text('Datça turu'), findsOneWidget);
    expect(store.active, isNull);
    expect(store.data, hasLength(1));
    expect(store.data.first.durationMin, greaterThanOrEqualTo(45));

    // Snackbar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('Rotalarım: kayıtlı rota İSMİYLE listelenir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(routes: <SavedRoute>[_route]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rotalarım'));
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
