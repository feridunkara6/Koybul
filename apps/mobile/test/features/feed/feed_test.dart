import 'package:dockly_api/dockly_api.dart' show FeedItem, GeoPoint;
import 'package:dockly_mobile/features/deck/domain/sea_trip_log.dart';
import 'package:dockly_mobile/features/deck/domain/trip_share_payload.dart';
import 'package:dockly_mobile/features/feed/application/feed_controller.dart';
import 'package:dockly_mobile/features/feed/domain/feed_gateway.dart';
import 'package:dockly_mobile/features/feed/presentation/feed_screen.dart';
import 'package:dockly_mobile/features/feed/presentation/today_feed_section.dart';
import 'package:dockly_mobile/features/route/domain/sea_trip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// TAKİP AKIŞI + SEYİR PAYLAŞIMI testleri (SP-3b, kurucu onayı 2026-10-31).
/// Kural (docs/15): ağ yok — geçit sahtesi + sağlayıcı override.

FeedItem trip({int pruva = 2, bool mine = false}) => FeedItem(
      kind: 'trip',
      id: 't-1',
      authorId: 'u-2',
      authorName: 'Kaptan Levent',
      levelCode: 'guide',
      createdAt: '2026-10-30T10:00:00.000Z',
      endName: 'Göcek', // başlangıç Konumum'du — paylaşılmadı
      distanceNm: 18.5,
      durationMin: 240,
      stopCount: 2,
      sailedOn: '2026-10-30',
      pruvaCount: pruva,
      myPruva: mine,
    );

const FeedItem note = FeedItem(
  kind: 'note',
  id: 'n-1',
  authorId: 'u-3',
  authorName: 'Kaptan Aylin',
  levelCode: 'new',
  createdAt: '2026-10-29T10:00:00.000Z',
  locationId: 'l-1',
  locationName: 'Kille Koyu',
  noteKind: 'experience',
  body: 'Akşam poyraza döner, tonoz şart.',
);

const FeedItem route = FeedItem(
  kind: 'route',
  id: 'r-1',
  authorId: 'u-2',
  authorName: 'Kaptan Levent',
  levelCode: 'guide',
  createdAt: '2026-10-28T10:00:00.000Z',
  routeName: 'Gökova batı turu',
  stopCount: 4,
  saveCount: 18,
);

class FakeFeedGateway implements FeedGateway {
  FakeFeedGateway({this.rows = const <FeedItem>[]});

  List<FeedItem> rows;
  final List<String> pruvaCalls = <String>[];
  final List<Map<String, Object?>> shares = <Map<String, Object?>>[];
  bool reactedNow = true;

  @override
  Future<List<FeedItem>> following() async => rows;

  @override
  Future<({bool reacted, int pruvaCount})> togglePruva(String tripId) async {
    pruvaCalls.add(tripId);
    return (reacted: reactedNow, pruvaCount: reactedNow ? 3 : 1);
  }

  @override
  Future<String> shareTrip({
    String? startName,
    String? endName,
    required double distanceNm,
    int? durationMin,
    required int stopCount,
    required String sailedOn,
  }) async {
    shares.add(<String, Object?>{
      'startName': startName,
      'endName': endName,
      'distanceNm': distanceNm,
      'durationMin': durationMin,
      'stopCount': stopCount,
      'sailedOn': sailedOn,
    });
    return 'srv-1';
  }
}

Widget _app(Widget child, FakeFeedGateway gw, {bool signedIn = true}) =>
    ProviderScope(
      overrides: <Override>[
        feedGatewayProvider.overrideWithValue(gw),
        if (signedIn) signedInAuthOverride(),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('akış: üç tür kart çizilir — seyir (başlangıçsız), not, rota',
      (WidgetTester tester) async {
    final FakeFeedGateway gw =
        FakeFeedGateway(rows: <FeedItem>[trip(), note, route]);
    await tester.pumpWidget(_app(const FeedScreen(), gw));
    await tester.pumpAndSettle();

    // Seyir: Konumum paylaşılmadı → yalnız varış adı görünür.
    expect(find.text('Göcek'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
    expect(find.textContaining('18.5'), findsOneWidget);
    // Not: koy adı + kırpılmış gövde.
    expect(find.textContaining('Kille Koyu'), findsOneWidget);
    expect(find.textContaining('tonoz şart'), findsOneWidget);
    // Rota: ad görünür.
    expect(find.text('Gökova batı turu'), findsOneWidget);
    // Pruvan neta sayacı.
    expect(find.textContaining('Pruvan neta'), findsOneWidget);
  });

  testWidgets('Pruvan neta: dokununca geçit çağrılır, sayaç yerinde güncellenir',
      (WidgetTester tester) async {
    final FakeFeedGateway gw = FakeFeedGateway(rows: <FeedItem>[trip()]);
    await tester.pumpWidget(_app(const FeedScreen(), gw));
    await tester.pumpAndSettle();

    expect(find.text('Pruvan neta · 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('feed-pruva-t-1')));
    await tester.pumpAndSettle();

    expect(gw.pruvaCalls, <String>['t-1']);
    expect(find.text('Pruvan neta · 3'), findsOneWidget);
  });

  testWidgets('akış boş: dürüst boş durum metni', (WidgetTester tester) async {
    final FakeFeedGateway gw = FakeFeedGateway();
    await tester.pumpWidget(_app(const FeedScreen(), gw));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('feed-empty')), findsOneWidget);
  });

  // NOT: iki durum AYRI testtir — aynı ProviderScope ağacında override
  // sayısı değiştirilemez (Riverpod kuralı; CI dersi 2026-10-31).
  testWidgets('Bugün bölümü: misafirde HİÇ çizilmez', (WidgetTester tester) async {
    final FakeFeedGateway gw = FakeFeedGateway(rows: <FeedItem>[trip(), note]);
    await tester.pumpWidget(_app(
        const Scaffold(body: SingleChildScrollView(child: TodayFeedSection())),
        gw,
        signedIn: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('today-feed-all')), findsNothing);
  });

  testWidgets('Bugün bölümü: üyede önizleme + "Tümünü gör" köprüsü',
      (WidgetTester tester) async {
    final FakeFeedGateway gw = FakeFeedGateway(rows: <FeedItem>[trip(), note]);
    await tester.pumpWidget(_app(
        const Scaffold(body: SingleChildScrollView(child: TodayFeedSection())),
        gw));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('today-feed-all')), findsOneWidget);
    expect(find.text('Gökova batı turu'), findsNothing); // listede yok
    expect(find.textContaining('Kille Koyu'), findsOneWidget);
  });

  group('buildTripSharePayload (gizlilik kuralı)', () {
    SeaTripLog log({RouteOrigin? origin}) => SeaTripLog(
          id: 's-1',
          name: 'Konumum → Göcek',
          status: TripStatus.done,
          dateMs: 0,
          distanceNm: 18.5,
          stops: 2,
          routeOrigin: origin,
          routeWaypoints: const <RouteWaypoint>[
            RouteWaypoint(pos: GeoPoint(lat: 36.7, lon: 28.9), id: 'l-1', name: 'Kille Koyu'),
            RouteWaypoint(pos: GeoPoint(lat: 36.75, lon: 28.93), id: 'l-2', name: 'Göcek'),
          ],
        );

    test('Konumum başlangıcı PAYLAŞILMAZ — startName null', () {
      final TripSharePayload p = buildTripSharePayload(
        trip: log(
            origin: const RouteOrigin(
                pos: GeoPoint(lat: 36.6, lon: 28.8), isDevice: true)),
        durMin: 240,
        day: DateTime(2026, 10, 30),
      );
      expect(p.startName, isNull);
      expect(p.endName, 'Göcek');
      expect(p.sailedOn, '2026-10-30');
      expect(p.distanceNm, 18.5);
      expect(p.stopCount, 2);
    });

    test('koy başlangıcı adıyla paylaşılır', () {
      final TripSharePayload p = buildTripSharePayload(
        trip: log(
            origin: const RouteOrigin(
                pos: GeoPoint(lat: 36.6, lon: 28.8), name: 'Sarsala')),
        durMin: null,
        day: DateTime(2026, 1, 5),
      );
      expect(p.startName, 'Sarsala');
      expect(p.durationMin, isNull);
      expect(p.sailedOn, '2026-01-05');
    });
  });
}
