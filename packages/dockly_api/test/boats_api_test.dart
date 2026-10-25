import 'package:dio/dio.dart';
import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

Dio _dio(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('BoatsApi (Hafta 2 — /v1/boats/:id/public Tekne Kartı sözleşmesi)', () {
    test('publicCard: kimliksiz okunur; alanlar çözülür', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'id': 'b-marti',
        'name': 'Martı',
        'boatTypeCode': 'sailboat',
        'brand': 'Beneteau',
        'model': 'Oceanis 38.1',
        'lengthM': 11.5,
        'buildYear': 2019,
        'marina': <String, dynamic>{'id': 'loc-marti', 'name': 'Martı Marina'},
        'captain': <String, dynamic>{
          'userId': 'u-1',
          'displayName': 'Kaptan Levent',
          'levelCode': 'guide',
        },
      });

      final card = await BoatsApi(_dio(adapter)).publicCard('b-marti');
      expect(card.name, 'Martı');
      expect(card.model, 'Oceanis 38.1');
      expect(card.lengthM, 11.5);
      expect(card.marinaName, 'Martı Marina');
      expect(card.captainUserId, 'u-1');
      expect(card.captainLevelCode, 'guide');

      final req = adapter.received.single;
      expect(req.path, '/v1/boats/b-marti/public');
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('publicCard: teknik alanlar rızasızsa null gelir (dürüst eksik)', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'id': 'b-gizli',
        'name': 'Poyraz',
        'boatTypeCode': 'gulet',
        'brand': null,
        'model': null,
        'lengthM': null,
        'buildYear': null,
        'marina': null,
        'captain': <String, dynamic>{
          'userId': 'u-2',
          'displayName': 'Koybul Kaptanı',
          'levelCode': 'new',
        },
      });
      final card = await BoatsApi(_dio(adapter)).publicCard('b-gizli');
      expect(card.brand, isNull);
      expect(card.lengthM, isNull);
      expect(card.marinaName, isNull);
    });

    test('publicCard: 404 not-found olarak eşlenir', () async {
      final adapter = FakeAdapter();
      adapter.enqueueProblem(404, <String, dynamic>{
        'type': 'https://api.koybul.com/problems/not-found',
        'title': 'Bulunamadı',
        'status': 404,
      });
      await expectLater(
        BoatsApi(_dio(adapter)).publicCard('b-yok'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
