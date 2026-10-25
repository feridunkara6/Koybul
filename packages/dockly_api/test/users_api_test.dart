import 'package:dio/dio.dart';
import 'package:dockly_api/dockly_api.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

Dio _dio(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('UsersApi (Sosyalleşme Hafta 1A — /v1/users/me profil sözleşmesi)', () {
    Map<String, dynamic> body({
      String name = 'Kaptan Feri',
      String? bio = 'Hafta sonu denizcisiyim.',
      int? exp = 8,
    }) =>
        <String, dynamic>{
          'id': 'u-1',
          'email': 'feri@example.com',
          'profile': <String, dynamic>{
            'displayName': name,
            'fullName': null,
            'bio': bio,
            'experienceYears': exp,
          },
        };

    test('me: profili çözer, Authorization taşır', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, body());

      final me = await UsersApi(_dio(adapter)).me('tok-1');
      expect(me.id, 'u-1');
      expect(me.displayName, 'Kaptan Feri');
      expect(me.bio, 'Hafta sonu denizcisiyim.');
      expect(me.experienceYears, 8);

      expect(adapter.received.single.path, '/v1/users/me');
      expect(adapter.received.single.method, 'GET');
      expect(adapter.received.single.headers['Authorization'], 'Bearer tok-1');
    });

    test('me: bio ve deneyim hiç girilmemişse null kalır (uydurma yok)', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, body(bio: null, exp: null));
      final me = await UsersApi(_dio(adapter)).me('tok-1');
      expect(me.bio, isNull);
      expect(me.experienceYears, isNull);
    });

    test('updateProfile: YALNIZ verilen alanlar gider (beyaz liste disiplini)',
        () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, body(name: 'Kaptan Martı'));

      final me = await UsersApi(_dio(adapter))
          .updateProfile(accessToken: 'tok-2', displayName: 'Kaptan Martı');
      expect(me.displayName, 'Kaptan Martı');

      final req = adapter.received.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/v1/users/me');
      expect(req.headers['Authorization'], 'Bearer tok-2');
      final Map<String, dynamic> sent = req.data as Map<String, dynamic>;
      final Map<String, dynamic> profile =
          sent['profile'] as Map<String, dynamic>;
      // Verilmeyen alanlar gövdede HİÇ yoktur — "null yap" sanılmasın.
      expect(profile, <String, dynamic>{'displayName': 'Kaptan Martı'});
    });

    test('publicProfile: kimliksiz okunur, kart PII taşımaz (Hafta 1B)', () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, <String, dynamic>{
        'id': 'u-2',
        'displayName': 'Kaptan Levent',
        'bio': 'Göcek sularındayım.',
        'experienceYears': 14,
        'memberSince': '2026-07-07T00:00:00.000Z',
        'points': 840,
        'levelCode': 'guide',
        'approvedCount': 46,
        'helpfulReceived': 120,
        'badges': <String>['lighthouse'],
      });

      final card = await UsersApi(_dio(adapter)).publicProfile('u-2');
      expect(card.displayName, 'Kaptan Levent');
      expect(card.levelCode, 'guide');
      expect(card.badges, <String>['lighthouse']);
      expect(card.initials, 'KL');
      expect(card.memberSince.year, 2026);

      final req = adapter.received.single;
      expect(req.path, '/v1/users/u-2/public');
      // Kimlik GÖNDERİLMEZ — uç herkese açıktır.
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('updateProfile: clearBio/clearExperience alanı bilerek null yazar',
        () async {
      final adapter = FakeAdapter();
      adapter.enqueueJson(200, body(bio: null, exp: null));

      await UsersApi(_dio(adapter)).updateProfile(
          accessToken: 'tok-3', clearBio: true, clearExperience: true);

      final Map<String, dynamic> profile =
          (adapter.received.single.data as Map<String, dynamic>)['profile']
              as Map<String, dynamic>;
      expect(profile.containsKey('bio'), isTrue);
      expect(profile['bio'], isNull);
      expect(profile.containsKey('experienceYears'), isTrue);
      expect(profile['experienceYears'], isNull);
      expect(profile.containsKey('displayName'), isFalse);
    });
  });
}
