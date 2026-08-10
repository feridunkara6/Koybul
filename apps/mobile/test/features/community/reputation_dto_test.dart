import 'package:dockly_api/dockly_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// İtibar DTO'ları — sunucu sözleşmesinin istemci izdüşümü. Sunucu bir alanı
/// göndermezse ekran ÇÖKMEMELİ, makul varsayılana düşmelidir (geriye uyum).
void main() {
  group('ReputationSummary.fromJson', () {
    test('tam yanıt okunur; rozetler badgeProgress alanından gelir', () {
      final ReputationSummary s = ReputationSummary.fromJson(<String, dynamic>{
        'displayName': 'Feridun Kara',
        'points': 2840,
        'levelCode': 'master',
        'pointsToNext': 1160,
        'trustScore': 1.2,
        'approvedCount': 24,
        'pendingCount': 2,
        'rejectedCount': 1,
        'helpfulReceived': 40,
        'writeRestrictedUntil': null,
        'areas': <dynamic>[
          <String, dynamic>{'adminAreaId': 'a1', 'name': 'Fethiye', 'count': 22},
        ],
        'badgeProgress': <dynamic>[
          <String, dynamic>{
            'code': 'lighthouse',
            'earned': true,
            'current': 30,
            'target': 25,
            'automatic': true,
            'awardedAt': '2026-08-01T00:00:00.000Z',
          },
          <String, dynamic>{
            'code': 'safety_watch',
            'earned': false,
            'current': 4,
            'target': 5,
            'automatic': true,
          },
        ],
      });

      expect(s.displayName, 'Feridun Kara');
      expect(s.initials, 'FK');
      expect(s.points, 2840);
      expect(s.areas.single.name, 'Fethiye');
      expect(s.earnedBadges.map((BadgeProgress b) => b.code), <String>['lighthouse']);
      expect(s.lockedBadges.map((BadgeProgress b) => b.code), <String>['safety_watch']);
      expect(s.isEmpty, isFalse);
    });

    test('eksik alanlar varsayılana düşer, çökme olmaz', () {
      final ReputationSummary s = ReputationSummary.fromJson(<String, dynamic>{});
      // Ad gelmezse kart ürün adına düşer; baş harf UYDURULMAZ.
      expect(s.displayName, '');
      expect(s.initials, '');
      expect(s.points, 0);
      expect(s.levelCode, 'new');
      expect(s.pointsToNext, isNull);
      expect(s.trustScore, 1);
      expect(s.areas, isEmpty);
      expect(s.badges, isEmpty);
      expect(s.isEmpty, isTrue);
    });

    test('en üst seviyede pointsToNext null gelir', () {
      final ReputationSummary s = ReputationSummary.fromJson(<String, dynamic>{
        'points': 5000,
        'levelCode': 'pilot',
      });
      expect(s.pointsToNext, isNull);
    });
  });

  group('BadgeProgress.ratio', () {
    BadgeProgress b(int current, int target, {bool earned = false}) => BadgeProgress(
          code: 'x',
          earned: earned,
          current: current,
          target: target,
          automatic: true,
        );

    test('kazanılmışsa her zaman 1', () => expect(b(0, 5, earned: true).ratio, 1));
    test('normal ilerleme oranı', () => expect(b(2, 5).ratio, 0.4));
    test('hedefi aşan ilerleme 1 ile sınırlanır', () => expect(b(9, 5).ratio, 1));
    test('hedef 0 ise BÖLME YAPILMAZ', () => expect(b(3, 0).ratio, 0));
    test('negatif sayaç 0 verir', () => expect(b(-3, 5).ratio, 0));
  });

  group('ModerationItem', () {
    test('iç içe preview/author düzleştirilir', () {
      final ModerationItem i = ModerationItem.fromJson(<String, dynamic>{
        'taskId': 't1',
        'entityType': 'note',
        'entityId': 'e1',
        'createdAt': '2026-08-01T08:20:00.000Z',
        'preview': <String, dynamic>{
          'kind': 'hazard',
          'body': 'Ağ var.',
          'locationName': 'Kızılada',
          'gpsVerified': true,
        },
        'author': <String, dynamic>{
          'displayName': 'A. Demir',
          'levelCode': 'guide',
          'approvedCount': 24,
          'rejectedCount': 1,
        },
      });
      expect(i.body, 'Ağ var.');
      expect(i.locationName, 'Kızılada');
      expect(i.authorName, 'A. Demir');
      expect(i.approvalRate, 96);
    });

    test('preview/author hiç gelmezse boş değerlere düşer', () {
      final ModerationItem i = ModerationItem.fromJson(<String, dynamic>{
        'taskId': 't1',
        'entityType': 'review',
        'entityId': 'e1',
        'createdAt': '2026-08-01T08:20:00.000Z',
      });
      expect(i.body, '');
      expect(i.authorLevelCode, 'new');
      // Hiç kararlanmamış yazarda oran UYDURULMAZ.
      expect(i.approvalRate, isNull);
    });
  });

  test('red sebepleri sunucudaki listeyle birebir aynı', () {
    expect(kRejectReasons, <String>[
      'off_topic',
      'not_verifiable',
      'duplicate',
      'personal_data',
      'offensive',
      'wrong_location',
      'other',
    ]);
  });
}
