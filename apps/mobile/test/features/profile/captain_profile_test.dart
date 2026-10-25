import 'package:dockly_api/dockly_api.dart' show PublicCaptain;
import 'package:dockly_mobile/features/profile/application/profile_controller.dart';
import 'package:dockly_mobile/features/profile/presentation/captain_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// HERKESE AÇIK KAPTAN PROFİLİ testleri (Hafta 1B, kurucu onayı 2026-10-24).
/// Kural (docs/15): ağ yok — sağlayıcı aile sahtesiyle beslenir.

PublicCaptain captain({
  String? bio = 'Göcek sularındayım; sorulara elimden geldiğince yazarım.',
  List<String> badges = const <String>['lighthouse', 'safety_watch'],
}) =>
    PublicCaptain(
      id: 'u-2',
      displayName: 'Kaptan Levent',
      bio: bio,
      experienceYears: 14,
      memberSince: DateTime.utc(2026, 7, 7),
      points: 840,
      levelCode: 'guide',
      approvedCount: 46,
      helpfulReceived: 1200,
      badges: badges,
    );

Widget _app(PublicCaptain c) => ProviderScope(
      overrides: <Override>[
        publicCaptainProvider.overrideWith((ref, String id) async => c),
      ],
      child: const MaterialApp(home: CaptainProfileScreen(userId: 'u-2')),
    );

void main() {
  testWidgets('kart: ad, seviye, üyelik yılı, bio, sayılar ve rozetler',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(captain()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('cp-name')), findsOneWidget);
    expect(find.text('Kaptan Levent'), findsOneWidget);
    expect(find.text('Yol Gösteren'), findsOneWidget); // levelLabel('guide')
    expect(find.textContaining('2026'), findsOneWidget); // üyelik yılı
    expect(find.textContaining('14 yıl'), findsOneWidget);
    expect(find.textContaining('Göcek sularındayım'), findsOneWidget);
    // Binlik ayraç dili korunur: 1200 değil 1.200.
    expect(find.text('1.200'), findsOneWidget);
    expect(find.text('46'), findsOneWidget);
    // Rozet kodu yerel etikete çevrilir (badgeName).
    expect(find.text('Fener'), findsOneWidget);
    // PII yüzeyi: e-posta bu ekranda ASLA görünmez.
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('bio yoksa tanıtım bölümü hiç çizilmez; rozet yoksa başlık yok',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _app(captain(bio: null, badges: const <String>[])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Göcek sularındayım'), findsNothing);
    expect(find.text('Rozetler'.toUpperCase()), findsNothing);
    expect(find.text('Kaptan Levent'), findsOneWidget);
  });
}
