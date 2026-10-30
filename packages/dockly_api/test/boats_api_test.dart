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

    test('publicCard: TK-5 alanları çözülür; eski yanıtta varsayılan', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'id': 'b-marti',
        'name': 'Martı',
        'boatTypeCode': 'sailboat',
        'brand': null,
        'model': null,
        'lengthM': null,
        'buildYear': null,
        'marina': null,
        'captain': <String, dynamic>{
          'userId': 'u-1',
          'displayName': 'Kaptan Levent',
          'levelCode': 'guide',
        },
        'favoriteCount': 12,
        'captainFollowers': 34,
        'sisters': <dynamic>[
          <String, dynamic>{
            'id': 's1',
            'name': 'Poyraz',
            'boatTypeCode': 'sailboat',
            'marinaName': 'Yalıkavak Marina',
          },
        ],
      });
      final card = await BoatsApi(_dio(adapter)).publicCard('b-marti');
      expect(card.favoriteCount, 12);
      expect(card.captainFollowers, 34);
      expect(card.sisters.single.name, 'Poyraz');
      expect(card.sisters.single.marinaName, 'Yalıkavak Marina');

      // Eski sunucu yanıtı (alanlar yok) → varsayılanlar, kırılma yok.
      adapter.enqueueJson(200, <String, dynamic>{
        'id': 'b-eski',
        'name': 'Eski',
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
      final old = await BoatsApi(_dio(adapter)).publicCard('b-eski');
      expect(old.favoriteCount, 0);
      expect(old.captainFollowers, 0);
      expect(old.sisters, isEmpty);
    });

    test('FAVORİLE (TK-5): uçlar doğru yola gider; liste çözülür', () async {
      final adapter = FakeAdapter();
      adapter.enqueueEmpty(204);
      adapter.enqueueEmpty(204);
      adapter.enqueueJson(200, <String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': 'b1',
            'name': 'Martı',
            'boatTypeCode': 'sailboat',
            'brand': 'Beneteau',
            'model': 'Oceanis 38.1',
            'marinaName': 'D-Marin Göcek',
          },
          // Teknik rıza kapalı: marka/model null.
          <String, dynamic>{
            'id': 'b2',
            'name': 'Derin',
            'boatTypeCode': 'sailboat',
            'brand': null,
            'model': null,
            'marinaName': null,
          },
        ],
      });
      final api = BoatsApi(_dio(adapter));
      await api.favorite('b1');
      await api.unfavorite('b1');
      final list = await api.favorites();

      expect(adapter.received[0].method, 'POST');
      expect(adapter.received[0].path, '/v1/boats/b1/favorite');
      expect(adapter.received[1].method, 'DELETE');
      expect(adapter.received[1].path, '/v1/boats/b1/favorite');
      expect(adapter.received[2].path, '/v1/boats/favorites');
      expect(list, hasLength(2));
      expect(list.first.brand, 'Beneteau');
      expect(list.last.brand, isNull);
      expect(list.last.name, 'Derin');
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
