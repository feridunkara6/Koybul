import 'package:dockly_api/dockly_api.dart'
    show FollowedCaptain, PublicCaptain, UserProfileMe;
import 'package:dockly_mobile/features/auth/presentation/account_gate.dart'
    show AccountRequiredSheetBody;
import 'package:dockly_mobile/features/profile/application/profile_controller.dart';
import 'package:dockly_mobile/features/profile/domain/profile_gateway.dart';
import 'package:dockly_mobile/features/profile/presentation/captain_profile_screen.dart';
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
