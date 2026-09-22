import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

Dio _dio(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('PremiumApi (P3 — /v1/premium sözleşmesi)', () {
    test('me: gövdeyi çözer, Authorization taşır', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'premium': <String, dynamic>{
          'active': true,
          'until': '2027-09-21T12:00:00.000Z',
          'productId': 'koybul.premium.yillik',
        },
        'exploration': <String, dynamic>{
          'remaining': 2,
          'limit': 3,
          'monthKey': '2026-09',
        },
      });

      final me = await PremiumApi(_dio(adapter)).me('tok-1');
      expect(me.active, isTrue);
      expect(me.until, DateTime.parse('2027-09-21T12:00:00.000Z'));
      expect(me.productId, 'koybul.premium.yillik');
      expect(me.explorationRemaining, 2);
      expect(me.explorationLimit, 3);
      expect(me.monthKey, '2026-09');

      expect(adapter.received.single.path, '/v1/premium/me');
      expect(adapter.received.single.headers['Authorization'], 'Bearer tok-1');
    });

    test('me: hiç abone olmamış kullanıcıda until/productId null gelir', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'premium': <String, dynamic>{'active': false, 'until': null, 'productId': null},
        'exploration': <String, dynamic>{'remaining': 3, 'limit': 3, 'monthKey': '2026-09'},
      });
      final me = await PremiumApi(_dio(adapter)).me('tok-1');
      expect(me.active, isFalse);
      expect(me.until, isNull);
      expect(me.productId, isNull);
      expect(me.explorationRemaining, 3);
    });

    test('linkApple: işlem kimliğini gönderir, doğrulanmış durumu döner', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'active': true,
        'until': '2027-09-21T12:00:00.000Z',
        'productId': 'koybul.premium.aylik',
      });

      final r = await PremiumApi(_dio(adapter))
          .linkApple(accessToken: 'tok-1', transactionId: 'tx-123');
      expect(r.active, isTrue);
      expect(r.productId, 'koybul.premium.aylik');

      final req = adapter.received.single;
      expect(req.path, '/v1/premium/apple/link');
      expect(req.data, <String, dynamic>{'originalTransactionId': 'tx-123'});
    });

    test('linkApple: problem+json AppFailure olarak yüzeye çıkar (409 örneği)', () async {
      final adapter = FakeAdapter();
      adapter.enqueueProblem(409, <String, dynamic>{
        'type': 'https://api.dockly.app/problems/conflict-state',
        'title': 'Geçersiz durum geçişi',
        'status': 409,
        'detail': 'Bu abonelik başka bir Koybul hesabına bağlı.',
      });

      expect(
        () => PremiumApi(_dio(adapter))
            .linkApple(accessToken: 'tok-1', transactionId: 'tx-1'),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });
}
