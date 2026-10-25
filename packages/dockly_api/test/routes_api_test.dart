import 'package:dio/dio.dart';
import 'package:dockly_api/dockly_api.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

Dio _dio(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> _summary() => <String, dynamic>{
      'id': 'r1',
      'name': '12 Adalar klasiği',
      'authorId': 'u-1',
      'authorName': 'Meltem Y.',
      'startName': 'Göcek',
      'endName': 'Bedri Rahmi',
      'stopCount': 4,
      'distanceNm': 14.0,
      'durationHours': 4.0,
      'season': 'Nisan-Ekim',
      'saveCount': 23,
      'doneCount': 4,
      'createdAt': '2026-10-20T08:00:00.000Z',
    };

void main() {
  group('RoutesApi (Hafta 3 — /v1/routes sözleşmesi)', () {
    test('list: data zarfını çözer; kimlik gönderilmez', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'data': <Map<String, dynamic>>[_summary()],
      });

      final routes = await RoutesApi(_dio(adapter)).list(sort: 'popular');
      expect(routes, hasLength(1));
      expect(routes.single.name, '12 Adalar klasiği');
      expect(routes.single.distanceNm, 14.0);
      expect(routes.single.authorId, 'u-1');

      final req = adapter.received.single;
      expect(req.path, '/v1/routes');
      expect(req.queryParameters['sort'], 'popular');
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('detail: duraklar ve bakan durumu çözülür; token taşınır', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        ..._summary(),
        'body': 'Öğlen meltemi güçlenmeden Yassıca molasını verin.',
        'boatSuggestion': null,
        'status': 'approved',
        'mine': false,
        'savedByMe': true,
        'doneByMe': false,
        'stops': <Map<String, dynamic>>[
          <String, dynamic>{
            'seq': 1,
            'locationId': 'loc-gocek',
            'name': 'Göcek',
            'typeCode': 'private_marina',
          },
          <String, dynamic>{
            'seq': 2,
            'locationId': 'loc-yassica',
            'name': 'Yassıca Adaları',
            'typeCode': 'mooring_point',
          },
        ],
      });

      final d = await RoutesApi(_dio(adapter)).detail('r1', accessToken: 'tok-1');
      expect(d.summary.id, 'r1');
      expect(d.stops, hasLength(2));
      expect(d.stops.first.name, 'Göcek');
      expect(d.savedByMe, isTrue);
      expect(adapter.received.single.headers['Authorization'], 'Bearer tok-1');
    });

    test('create: gövde sözleşmeye birebir; boş opsiyoneller GÖNDERİLMEZ', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(201, <String, dynamic>{'id': 'r9', 'status': 'pending'});

      final res = await RoutesApi(_dio(adapter)).create(
        accessToken: 'tok-2',
        name: 'Sarsala turu',
        body: 'B' * 40,
        distanceNm: 8.1,
        stopLocationIds: <String>['loc-a', 'loc-b'],
      );
      expect(res.status, 'pending');

      final req = adapter.received.single;
      expect(req.method, 'POST');
      expect(req.path, '/v1/routes');
      final Map<String, dynamic> sent = req.data as Map<String, dynamic>;
      expect(sent['stopLocationIds'], <String>['loc-a', 'loc-b']);
      expect(sent['distanceNm'], 8.1);
      // Verilmeyen opsiyoneller gövdede HİÇ yok (sunucu strict()).
      expect(sent.containsKey('season'), isFalse);
      expect(sent.containsKey('boatSuggestion'), isFalse);
      expect(sent.containsKey('durationHours'), isFalse);
    });

    test('toggleSave/toggleDone: doğru uçlara gider, sonuç çözülür', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{'saved': true, 'saveCount': 24});
      adapter.enqueueJson(200, <String, dynamic>{'done': true, 'doneCount': 5});

      final api = RoutesApi(_dio(adapter));
      final s = await api.toggleSave(accessToken: 'tok', routeId: 'r1');
      expect(s.saved, isTrue);
      expect(s.saveCount, 24);
      final d = await api.toggleDone(accessToken: 'tok', routeId: 'r1');
      expect(d.done, isTrue);

      expect(adapter.received[0].path, '/v1/routes/r1/save');
      expect(adapter.received[1].path, '/v1/routes/r1/done');
    });
  });
}
