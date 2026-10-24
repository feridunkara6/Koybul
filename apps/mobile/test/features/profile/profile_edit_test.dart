import 'package:dockly_api/dockly_api.dart' show UserProfileMe;
import 'package:dockly_mobile/features/community/application/reputation_controller.dart';
import 'package:dockly_mobile/features/community/presentation/sailor_profile_card.dart';
import 'package:dockly_mobile/features/deck/application/trip_log_controller.dart';
import 'package:dockly_mobile/features/profile/application/profile_controller.dart';
import 'package:dockly_mobile/features/profile/domain/profile_gateway.dart';
import 'package:dockly_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';
import '../../support/trip_fakes.dart';

/// PROFİL DÜZENLEME testleri (Sosyalleşme Hafta 1A, kurucu onayı 2026-10-24).
/// Kural (docs/15): ağ yok — geçit sahtedir.

const UserProfileMe kMe = UserProfileMe(
  id: 'u-1',
  email: 'feri@example.com',
  displayName: 'Kaptan Feri',
  bio: 'Hafta sonu denizcisiyim.',
  experienceYears: 8,
);

class FakeProfileGateway implements ProfileGateway {
  FakeProfileGateway({this.current = kMe});

  UserProfileMe current;
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];

  @override
  Future<UserProfileMe> me() async => current;

  @override
  Future<UserProfileMe> update({
    String? displayName,
    String? bio,
    bool clearBio = false,
    int? experienceYears,
    bool clearExperience = false,
  }) async {
    updates.add(<String, Object?>{
      'displayName': displayName,
      'bio': bio,
      'clearBio': clearBio,
      'experienceYears': experienceYears,
      'clearExperience': clearExperience,
    });
    current = UserProfileMe(
      id: current.id,
      email: current.email,
      displayName: displayName ?? current.displayName,
      bio: clearBio ? null : (bio ?? current.bio),
      experienceYears:
          clearExperience ? null : (experienceYears ?? current.experienceYears),
    );
    return current;
  }
}

/// Ekran bir ana sayfanın ÜSTÜNE itilir — kayıt sonrası pop gerçekçi olsun
/// (kök rotayı pop etmek test ortamında yasaktır).
Widget _app(FakeProfileGateway gw) {
  return ProviderScope(
    overrides: <Override>[profileGatewayProvider.overrideWithValue(gw)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              key: const ValueKey<String>('open-edit'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ProfileEditScreen()),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, FakeProfileGateway gw) async {
  await tester.pumpWidget(_app(gw));
  await tester.tap(find.byKey(const ValueKey<String>('open-edit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('form sunucudaki profille önceden dolar', (tester) async {
    final gw = FakeProfileGateway();
    await _open(tester, gw);
    expect(find.text('Kaptan Feri'), findsOneWidget);
    expect(find.text('Hafta sonu denizcisiyim.'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('yalnız DEĞİŞEN alan gönderilir ve ekran kapanır', (tester) async {
    final gw = FakeProfileGateway();
    await _open(tester, gw);
    await tester.enterText(
        find.byKey(const ValueKey<String>('pe-name')), 'Kaptan Martı');
    await tester.tap(find.byKey(const ValueKey<String>('pe-save')));
    await tester.pumpAndSettle();

    expect(gw.updates, hasLength(1));
    expect(gw.updates.single['displayName'], 'Kaptan Martı');
    expect(gw.updates.single['bio'], isNull);
    expect(gw.updates.single['clearBio'], false);
    expect(gw.updates.single['experienceYears'], isNull);
    expect(gw.updates.single['clearExperience'], false);
    // Kayıt sonrası düzenleme ekranı kapanır (ana sayfa düğmesi görünür).
    expect(find.byKey(const ValueKey<String>('open-edit')), findsOneWidget);
  });

  testWidgets('bio silinirse clearBio ile BİLİNÇLİ boşaltma gider', (tester) async {
    final gw = FakeProfileGateway();
    await _open(tester, gw);
    await tester.enterText(find.byKey(const ValueKey<String>('pe-bio')), '');
    await tester.tap(find.byKey(const ValueKey<String>('pe-save')));
    await tester.pumpAndSettle();

    expect(gw.updates.single['clearBio'], true);
    expect(gw.updates.single['bio'], isNull);
  });

  testWidgets('kısa ad kaydedilmez — doğrulama mesajı çıkar', (tester) async {
    final gw = FakeProfileGateway();
    await _open(tester, gw);
    await tester.enterText(find.byKey(const ValueKey<String>('pe-name')), 'K');
    await tester.tap(find.byKey(const ValueKey<String>('pe-save')));
    await tester.pumpAndSettle();

    expect(gw.updates, isEmpty);
    expect(find.text('Görünen ad 2-50 karakter olmalı'), findsOneWidget);
  });

  testWidgets('Denizci kartındaki kalem düzenleme ekranını açar', (tester) async {
    final gw = FakeProfileGateway();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        tripStoreProvider.overrideWithValue(FakeTripStore()),
        signedInAuthOverride(),
        reputationGatewayProvider.overrideWithValue(FakeReputationGateway()),
        profileGatewayProvider.overrideWithValue(gw),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SailorProfileCard())),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('sailor-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('pe-name')), findsOneWidget);
  });

  testWidgets('geçersiz deneyim kaydedilmez', (tester) async {
    final gw = FakeProfileGateway();
    await _open(tester, gw);
    await tester.enterText(find.byKey(const ValueKey<String>('pe-exp')), '99');
    await tester.tap(find.byKey(const ValueKey<String>('pe-save')));
    await tester.pumpAndSettle();

    expect(gw.updates, isEmpty);
    expect(find.text('Deneyim 0-80 arasında bir sayı olmalı'), findsOneWidget);
  });
}
