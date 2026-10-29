import 'package:dockly_api/dockly_api.dart'
    show InboxItem, NotificationPrefs, NotificationsApi, SessionUser;
import 'package:dockly_mobile/core/providers.dart';
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/notifications/application/push_controller.dart';
import 'package:dockly_mobile/features/notifications/domain/push_gateway.dart';
import 'package:dockly_mobile/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// BİLDİRİM AYARLARI ekranı (push paketi, kurucu onayı 2026-10-27):
/// misafire dürüst not, izinsiz cihaza yol tarifi, hesapta anahtarlar;
/// moderasyon anahtarı yalnız admin hesaba çizilir.
class FakePushGateway implements PushGateway {
  FakePushGateway({this.permission = true, this.fcmToken = 'testtesttesttesttest'});

  bool permission;
  String? fcmToken;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<String?> token() async => fcmToken;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Stream<Map<String, String>> get onNotificationTap =>
      const Stream<Map<String, String>>.empty();
}

class FakeNotificationsApi implements NotificationsApi {
  NotificationPrefs prefs = const NotificationPrefs(
      community: true, events: true, moderation: true);

  String? registeredToken;
  String? registeredLocale;
  String? registeredPlatform;
  final List<String> removedTokens = <String>[];

  @override
  Future<NotificationPrefs> registerDevice({
    required String accessToken,
    required String token,
    required String platform,
    required String locale,
  }) async {
    registeredToken = token;
    registeredPlatform = platform;
    registeredLocale = locale;
    return prefs;
  }

  @override
  Future<void> removeDevice({
    required String accessToken,
    required String token,
  }) async {
    removedTokens.add(token);
  }

  @override
  Future<NotificationPrefs> updatePrefs({
    required String accessToken,
    required String token,
    bool? community,
    bool? events,
    bool? moderation,
  }) async {
    prefs = NotificationPrefs(
      community: community ?? prefs.community,
      events: events ?? prefs.events,
      moderation: moderation ?? prefs.moderation,
    );
    return prefs;
  }

  // BİLDİRİM KUTUSU (SP-2, 2026-10-31) — bu testte kullanılmaz; boş sahte.
  @override
  Future<List<InboxItem>> inbox({required String accessToken}) async =>
      const <InboxItem>[];

  @override
  Future<void> markAllRead({required String accessToken}) async {}
}

Widget _app({
  required FakeNotificationsApi api,
  required FakePushGateway gateway,
  List<Override> extra = const <Override>[],
}) =>
    ProviderScope(
      overrides: <Override>[
        notificationsApiProvider.overrideWithValue(api),
        pushGatewayProvider.overrideWithValue(gateway),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ...extra,
      ],
      child: const MaterialApp(home: NotificationSettingsScreen()),
    );

void main() {
  testWidgets('misafirde anahtar yok, dürüst not var', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      api: FakeNotificationsApi(),
      gateway: FakePushGateway(),
      // Override YOK → varsayılan durum misafir/oturumsuz başlar.
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ntf-guest-note')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ntf-community')), findsNothing);
    // Bakım anahtarı CİHAZ işi — misafirde de görünür.
    expect(find.byKey(const ValueKey<String>('ntf-maint')), findsOneWidget);
  });

  testWidgets('izin reddinde yol tarifi notu görünür', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      api: FakeNotificationsApi(),
      gateway: FakePushGateway(permission: false),
      extra: <Override>[signedInAuthOverride()],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ntf-perm-note')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ntf-community')), findsNothing);
  });

  testWidgets('hesapta cihaz kaydolur ve anahtarlar çizilir; admin değilse moderasyon yok',
      (WidgetTester tester) async {
    final FakeNotificationsApi api = FakeNotificationsApi();
    await tester.pumpWidget(_app(
      api: api,
      gateway: FakePushGateway(),
      extra: <Override>[signedInAuthOverride()], // role: 'user'
    ));
    await tester.pumpAndSettle();

    expect(api.registeredToken, 'testtesttesttesttest');
    expect(api.registeredLocale, isNotNull);
    expect(find.byKey(const ValueKey<String>('ntf-community')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ntf-events')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ntf-moderation')), findsNothing);
  });

  testWidgets('anahtar çevirince tercih sunucuya yazılır ve ekrana yansır',
      (WidgetTester tester) async {
    final FakeNotificationsApi api = FakeNotificationsApi();
    await tester.pumpWidget(_app(
      api: api,
      gateway: FakePushGateway(),
      extra: <Override>[signedInAuthOverride()],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ntf-community')));
    await tester.pumpAndSettle();

    expect(api.prefs.community, isFalse);
    final SwitchListTile sw = tester.widget(
        find.byKey(const ValueKey<String>('ntf-community')));
    expect(sw.value, isFalse);
  });

  testWidgets('admin hesapta moderasyon anahtarı da çizilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      api: FakeNotificationsApi(),
      gateway: FakePushGateway(),
      extra: <Override>[
        signedInAuthOverride(
            user: const SessionUser(
                id: 'a1', role: 'admin', isGuest: false, locale: 'tr')),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ntf-moderation')), findsOneWidget);
  });
}
