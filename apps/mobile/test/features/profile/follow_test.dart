import 'package:dockly_api/dockly_api.dart'
    show BlockedUser, FollowedCaptain, PublicCaptain, UserProfileMe;
import 'package:dockly_mobile/features/auth/presentation/account_gate.dart'
    show AccountRequiredSheetBody;
import 'package:dockly_mobile/features/profile/application/profile_controller.dart';
import 'package:dockly_mobile/features/profile/domain/profile_gateway.dart';
import 'package:dockly_mobile/features/profile/presentation/blocked_users_screen.dart';
import 'package:dockly_mobile/features/profile/presentation/captain_profile_screen.dart';
import 'package:dockly_mobile/features/profile/presentation/follow_list_screen.dart';
import 'package:dockly_mobile/features/profile/presentation/following_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// TAKİP testleri (SP-3a, kurucu onayı 2026-10-31).
/// Kural (docs/15): ağ yok — geçit sahtesi + sağlayıcı override.

PublicCaptain captain({String id = 'u-2', int followerCount = 11}) =>
    PublicCaptain(
      id: id,
      displayName: 'Kaptan Levent',
      bio: null,
      experienceYears: 14,
      memberSince: DateTime.utc(2026, 7, 7),
      points: 840,
      levelCode: 'guide',
      approvedCount: 46,
      helpfulReceived: 120,
      badges: const <String>[],
      followerCount: followerCount,
    );

/// Takip çağrılarını kaydeden geçit sahtesi — following() kayıttan okur,
/// böylece düğme durumu gerçek akıştaki gibi tazelenir.
class FakeProfileGateway implements ProfileGateway {
  final List<String> followed = <String>[];
  final List<String> unfollowed = <String>[];
  List<FollowedCaptain> rows = <FollowedCaptain>[];

  @override
  Future<List<FollowedCaptain>> following() async => rows;

  @override
  Future<void> follow(String userId) async {
    followed.add(userId);
    rows = <FollowedCaptain>[
      ...rows,
      FollowedCaptain(id: userId, displayName: 'Kaptan $userId', levelCode: 'new'),
    ];
  }

  @override
  Future<void> unfollow(String userId) async {
    unfollowed.add(userId);
    rows = rows.where((FollowedCaptain f) => f.id != userId).toList();
  }

  // PR-1 (2026-11-03): liste uçları — takipçiler ayrı kayıttan, takip
  // edilenler mevcut `rows` kaydından okunur (liste ekranı testleri için).
  List<FollowedCaptain> followerRows = <FollowedCaptain>[];

  @override
  Future<List<FollowedCaptain>> followersOf(String userId) async =>
      followerRows;

  @override
  Future<List<FollowedCaptain>> followingOf(String userId) async => rows;

  // ENG-1 (2026-11-03): engelleme — gerçek geçit gibi kayıt tutar.
  final List<String> blockedCalls = <String>[];
  final List<String> unblockedCalls = <String>[];
  List<BlockedUser> blockedRows = <BlockedUser>[];

  @override
  Future<List<BlockedUser>> blocks() async => blockedRows;

  @override
  Future<void> block(String userId) async {
    blockedCalls.add(userId);
    blockedRows = <BlockedUser>[
      ...blockedRows,
      BlockedUser(
        id: userId,
        displayName: 'Kaptan $userId',
        levelCode: 'new',
        blockedAt: DateTime.utc(2026, 11, 3),
      ),
    ];
    // Gerçek sunucu gibi: iki yöndeki takip bağları düşer.
    rows = rows.where((FollowedCaptain f) => f.id != userId).toList();
  }

  @override
  Future<void> unblock(String userId) async {
    unblockedCalls.add(userId);
    blockedRows =
        blockedRows.where((BlockedUser b) => b.id != userId).toList();
  }

  @override
  Future<UserProfileMe> me() => throw UnimplementedError();

  @override
  Future<UserProfileMe> update({
    String? displayName,
    String? bio,
    bool clearBio = false,
    int? experienceYears,
    bool clearExperience = false,
  }) =>
      throw UnimplementedError();
}

Widget _profileApp(
  FakeProfileGateway gw, {
  List<Override> extra = const <Override>[],
  String captainId = 'u-2',
}) =>
    ProviderScope(
      overrides: <Override>[
        publicCaptainProvider.overrideWith((ref, String id) async => captain(id: id)),
        profileGatewayProvider.overrideWithValue(gw),
        ...extra,
      ],
      child: MaterialApp(home: CaptainProfileScreen(userId: captainId)),
    );

void main() {
  testWidgets('kaptan kartı: TAKİPÇİ sayısı görünür + "Takip et" düğmesi var',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(_profileApp(gw, extra: <Override>[signedInAuthOverride()]));
    await tester.pumpAndSettle();

    expect(find.text('TAKİPÇİ'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cp-follow-btn')), findsOneWidget);
    expect(find.text('Takip et'), findsOneWidget);
  });

  testWidgets('üye takip eder: geçit çağrılır, düğme "Takip ediliyor" olur; '
      'ikinci dokunuş takibi bırakır', (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(_profileApp(gw, extra: <Override>[signedInAuthOverride()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('cp-follow-btn')));
    await tester.pumpAndSettle();
    expect(gw.followed, <String>['u-2']);
    expect(find.text('Takip ediliyor'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('cp-follow-btn')));
    await tester.pumpAndSettle();
    expect(gw.unfollowed, <String>['u-2']);
    expect(find.text('Takip et'), findsOneWidget);
  });

  testWidgets('kendi kartımda takip düğmesi ÇİZİLMEZ (self-follow sunucuda 422)',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    // signedInAuthOverride → testUser.id = 'u1'; kart da u1'in kartı.
    await tester.pumpWidget(_profileApp(gw,
        extra: <Override>[signedInAuthOverride()], captainId: 'u1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('cp-follow-btn')), findsNothing);
    expect(find.text('TAKİPÇİ'), findsOneWidget); // sayı herkese açık kalır
  });

  testWidgets('hesapsız dokunuş: üyelik kapısı açılır, geçide gidilmez',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(_profileApp(gw)); // auth override yok → hesapsız
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('cp-follow-btn')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountRequiredSheetBody), findsOneWidget);
    expect(find.textContaining('ücretsiz bir hesap'), findsOneWidget);
    expect(gw.followed, isEmpty);
  });

  // --- PR-1 Profil düzeni (kurucu onayı 2026-11-03) ---

  testWidgets('PR-1 SAYAÇLAR: kaptan kartında takipçi/takip/katkı hücreleri',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(
        _profileApp(gw, extra: <Override>[signedInAuthOverride()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('cp-cnt-followers')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cp-cnt-following')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cp-cnt-contrib')), findsOneWidget);
    expect(find.text('KATKI'), findsOneWidget);
    expect(find.text('46'), findsOneWidget); // onaylı katkı sayacı
  });

  testWidgets('PR-1 HESAP KAPISI: hesapsız sayaca dokununca davet açılır, '
      'liste açılmaz', (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(_profileApp(gw)); // auth yok → hesapsız
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('cp-cnt-followers')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountRequiredSheetBody), findsOneWidget);
    expect(find.byType(FollowListScreen), findsNothing);
  });

  testWidgets('PR-1 LİSTE: üye sayaca dokununca takipçi listesi açılır; '
      'sekme değişince takip listesi gelir', (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway()
      ..followerRows = const <FollowedCaptain>[
        FollowedCaptain(id: 'u-5', displayName: 'Kaptan Deniz', levelCode: 'guide'),
      ];
    await tester.pumpWidget(
        _profileApp(gw, extra: <Override>[signedInAuthOverride()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('cp-cnt-followers')));
    await tester.pumpAndSettle();

    expect(find.byType(FollowListScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fl-row-u-5')), findsOneWidget);
    expect(find.text('Kaptan Deniz'), findsOneWidget);

    // Takip sekmesi: kimseyi takip etmiyor → boş durum (0-uydurma).
    await tester.tap(find.byKey(const ValueKey<String>('fl-tab-following')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('fl-empty')), findsOneWidget);
  });

  testWidgets('PR-1 HIZLI TAKİP: listedeki düğme geçide gider, durum tazelenir',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway()
      ..followerRows = const <FollowedCaptain>[
        FollowedCaptain(id: 'u-5', displayName: 'Kaptan Deniz', levelCode: 'guide'),
      ];
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        profileGatewayProvider.overrideWithValue(gw),
        signedInAuthOverride(),
      ],
      child: const MaterialApp(
        home: FollowListScreen(userId: 'u-2', displayName: 'Kaptan Levent'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('fl-follow-u-5')));
    await tester.pumpAndSettle();

    expect(gw.followed, <String>['u-5']);
    // Takip listem tazelendi → düğme "Takip ediliyor" hâline döner.
    expect(find.byKey(const ValueKey<String>('fl-unfollow-u-5')), findsOneWidget);
  });

  // --- ENGELLEME (ENG-1, kurucu onayı 2026-11-03) ---

  testWidgets('ENG-1 MENÜ: üye ⋯ → engelle → onay sayfası → geçide gider',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(
        _profileApp(gw, extra: <Override>[signedInAuthOverride()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('cp-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('cp-block')));
    await tester.pumpAndSettle();

    // Onay sayfası ne olacağını dürüstçe anlatır; onaysız hiçbir şey olmaz.
    expect(find.text('Bu kaptanı engellemek üzeresin'), findsOneWidget);
    expect(gw.blockedCalls, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('cp-block-confirm')));
    await tester.pumpAndSettle();
    expect(gw.blockedCalls, <String>['u-2']);
    expect(find.textContaining('Engellendi'), findsOneWidget); // snack
  });

  // CI dersi (2026-11-03): aynı ağaca ikinci kez FARKLI SAYIDA override
  // vermek Riverpod'da yasak — iki durum iki AYRI testte sınanır.
  testWidgets('ENG-1 GÖRÜNÜRLÜK: kendi profilinde ⋯ menüsü YOK',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    // Kendi profilim (u1 = testUser).
    await tester.pumpWidget(_profileApp(gw,
        extra: <Override>[signedInAuthOverride()], captainId: 'u1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('cp-more')), findsNothing);
  });

  testWidgets('ENG-1 GÖRÜNÜRLÜK: misafirde ⋯ menüsü YOK',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    // Misafir — menü yine yok (hesapsız kullanıcı etkileşemez).
    await tester.pumpWidget(_profileApp(gw));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('cp-more')), findsNothing);
  });

  testWidgets('ENG-1 LİSTE: Engellediklerim satırı + tek dokunuşla geri alma',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway()
      ..blockedRows = <BlockedUser>[
        BlockedUser(
          id: 'u-9',
          displayName: 'Tartışmacı Kaptan',
          levelCode: 'new',
          blockedAt: DateTime.utc(2026, 11, 3),
        ),
      ];
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        profileGatewayProvider.overrideWithValue(gw),
        signedInAuthOverride(),
      ],
      child: const MaterialApp(home: BlockedUsersScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tartışmacı Kaptan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('blocked-undo-u-9')));
    await tester.pumpAndSettle();

    expect(gw.unblockedCalls, <String>['u-9']);
    // Liste tazelendi → boş durum metni.
    expect(find.byKey(const ValueKey<String>('blocked-empty')), findsOneWidget);
  });

  testWidgets('Takip ettiklerim: boş durum metni (misafir/boş liste)',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        profileGatewayProvider.overrideWithValue(gw),
        signedInAuthOverride(),
      ],
      child: const MaterialApp(home: FollowingScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('following-empty')), findsOneWidget);
  });

  testWidgets('Takip ettiklerim: satırlar listelenir, dokununca kaptan kartı açılır',
      (WidgetTester tester) async {
    final FakeProfileGateway gw = FakeProfileGateway()
      ..rows = const <FollowedCaptain>[
        FollowedCaptain(id: 'u-2', displayName: 'Kaptan Levent', levelCode: 'guide'),
        FollowedCaptain(id: 'u-3', displayName: 'Kaptan Aylin', levelCode: 'new'),
      ];
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        profileGatewayProvider.overrideWithValue(gw),
        signedInAuthOverride(),
        publicCaptainProvider.overrideWith((ref, String id) async => captain(id: id)),
      ],
      child: const MaterialApp(home: FollowingScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kaptan Levent'), findsOneWidget);
    expect(find.text('Kaptan Aylin'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('following-row-u-2')));
    await tester.pumpAndSettle();
    expect(find.byType(CaptainProfileScreen), findsOneWidget);
  });
}
