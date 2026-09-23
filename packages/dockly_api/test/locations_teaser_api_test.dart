import 'package:dio/dio.dart';
import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

/// VİTRİN + KEŞİF HAKKI istemci sözleşmesi (P4, premium v3 raporu §3/K2).

Dio _dio(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// Asgari geçerli detay gövdesi; [teaser] doğruysa sunucunun vitrin yanıtını
/// taklit eder (kilitli alanlar BOŞ gelir — sunucu hiç göndermez).
Map<String, dynamic> _detailJson({bool teaser = false, int? remaining}) =>
    <String, dynamic>{
      'id': 'loc-1',
      'slug': 'kille-koyu',
      'type': 'buoy',
      'status': 'published',
      'name': 'Kille Koyu',
      'description': teaser ? null : 'Uzun açıklama',
      'position': <String, dynamic>{'lat': 36.68, 'lon': 28.89},
      'geo': <String, dynamic>{
        'countryCode': 'TR',
        'adminArea': null,
        'waterBody': null,
      },
      'dimensions': <String, dynamic>{
        'maxBoatLengthM': 25.0,
        'maxDraftM': 4.0,
        'depthMinM': 7.0,
        'depthMaxM': 8.0,
        'capacity': teaser ? null : 18,
      },
      'priceTier': 'paid',
      'is24h': false,
      'verifiedAt': null,
      'rating': <String, dynamic>{'avg': 4.4, 'count': 12, 'dimensions': <dynamic>[]},
      'amenities': <dynamic>[],
      'services': <dynamic>[],
      'contacts': teaser
          ? <dynamic>[]
          : <dynamic>[
              <String, dynamic>{'type': 'phone', 'value': '+90', 'isPrimary': true},
            ],
      'hours': <dynamic>[],
      'seasons': <dynamic>[],
      'typeDetails': null,
      'media': <String, dynamic>{'cover': null, 'count': 6},
      'counts': <String, dynamic>{'reviews': 12, 'photos': 6},
      'seabed': 'mud',
      'shelteredDirs': 'K,KB',
      if (teaser) 'access': 'teaser',
      if (remaining != null) 'explorationRemaining': remaining,
    };

void main() {
  group('LocationsApi.detail — vitrin sözleşmesi (P4)', () {
    test('access alanı yoksa full sayılır (eski sunucuyla geriye uyumlu)', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, _detailJson());
      final d = await LocationsApi(_dio(adapter)).detail('kille-koyu');
      expect(d.access, 'full');
      expect(d.isTeaser, isFalse);
      expect(d.explorationRemaining, isNull);
      // Anonim istekte Authorization başlığı GİTMEZ.
      expect(adapter.received.single.headers.containsKey('Authorization'), isFalse);
    });

    test('teaser yanıtı çözülür: access + kalan hak + güvenlik özeti dolu', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, _detailJson(teaser: true, remaining: 2));
      final d = await LocationsApi(_dio(adapter)).detail('kille-koyu');
      expect(d.isTeaser, isTrue);
      expect(d.explorationRemaining, 2);
      // Güvenlik özeti vitrinde açık (K1): derinlik + zemin + korunak.
      expect(d.dimensions.depthMinM, 7.0);
      expect(d.seabed, 'mud');
      expect(d.shelteredDirs, 'K,KB');
      expect(d.contacts, isEmpty); // kilitli alan inmedi
    });

    test('accessToken verilirse Authorization başlığı gider', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, _detailJson());
      await LocationsApi(_dio(adapter)).detail('kille-koyu', accessToken: 'tok-1');
      expect(adapter.received.single.headers['Authorization'], 'Bearer tok-1');
    });
  });

  group('LocationsApi.unlock — keşif hakkı (P4)', () {
    test('tam detay + kalan hak döner; doğru uca, kimlikle gider', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'remaining': 1,
        'detail': _detailJson(),
      });
      final r = await LocationsApi(_dio(adapter))
          .unlock(idOrSlug: 'kille-koyu', accessToken: 'tok-1');
      expect(r.remaining, 1);
      expect(r.detail.name, 'Kille Koyu');
      expect(r.detail.isTeaser, isFalse);

      final req = adapter.received.single;
      expect(req.method, 'POST');
      expect(req.path, '/v1/locations/kille-koyu/unlock');
      expect(req.headers['Authorization'], 'Bearer tok-1');
    });

    test('kota dolunca 403 quota-exceeded → ForbiddenFailure yüzeye çıkar', () async {
      final adapter = FakeAdapter();
      adapter.enqueueProblem(403, <String, dynamic>{
        'type': 'https://api.dockly.app/problems/quota-exceeded',
        'title': 'Aylık keşif hakkı doldu',
        'status': 403,
        'detail': 'Bu ayın keşif hakları doldu.',
      });
      expect(
        () => LocationsApi(_dio(adapter))
            .unlock(idOrSlug: 'kille-koyu', accessToken: 'tok-1'),
        throwsA(isA<ForbiddenFailure>()),
      );
    });
  });

  // --- KİLİTLİ OKUMA UÇLARI (P5, premium v3 §9): yorumlar/notlar kimlikle ---

  group('LocationsApi.reviews — kimlikli okuma (P5)', () {
    test('accessToken verilirse Authorization başlığı gider; verilmezse GİTMEZ', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{'data': <dynamic>[]});
      await LocationsApi(_dio(adapter)).reviews('kille-koyu', accessToken: 'tok-1');
      expect(adapter.received.single.headers['Authorization'], 'Bearer tok-1');

      final adapter2 = FakeAdapter();
      adapter2.enqueueJson(200, <String, dynamic>{'data': <dynamic>[]});
      await LocationsApi(_dio(adapter2)).reviews('kille-koyu');
      expect(adapter2.received.single.headers.containsKey('Authorization'), isFalse);
    });

    test('vitrin kilidi: 403 premium-required → ForbiddenFailure yüzeye çıkar', () async {
      final adapter = FakeAdapter();
      adapter.enqueueProblem(403, <String, dynamic>{
        'type': 'https://api.dockly.app/problems/premium-required',
        'title': 'Bu içerik Premium ile açılır',
        'status': 403,
      });
      expect(
        () => LocationsApi(_dio(adapter)).reviews('kille-koyu'),
        throwsA(isA<ForbiddenFailure>()),
      );
    });
  });

  group('CommunityApi.notesForLocation — kimlikli okuma (P5)', () {
    test('accessToken verilirse Authorization başlığı gider; verilmezse GİTMEZ', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{'data': <dynamic>[]});
      await CommunityApi(_dio(adapter))
          .notesForLocation('11111111-1111-1111-1111-111111111111', accessToken: 'tok-1');
      expect(adapter.received.single.headers['Authorization'], 'Bearer tok-1');

      final adapter2 = FakeAdapter();
      adapter2.enqueueJson(200, <String, dynamic>{'data': <dynamic>[]});
      await CommunityApi(_dio(adapter2))
          .notesForLocation('11111111-1111-1111-1111-111111111111');
      expect(adapter2.received.single.headers.containsKey('Authorization'), isFalse);
    });
  });
}
