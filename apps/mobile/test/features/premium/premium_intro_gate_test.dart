import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_state.dart';
import 'package:dockly_mobile/features/premium/application/premium_controller.dart';
import 'package:dockly_mobile/features/premium/data/premium_intro_store.dart';
import 'package:dockly_mobile/features/premium/data/premium_offline_cache.dart';
import 'package:dockly_mobile/features/premium/presentation/premium_intro_gate.dart';
import 'package:dockly_mobile/features/premium/presentation/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/premium_fakes.dart';

/// Sabit, pasif premium durumu döndüren sahte sunucu (ağ kuralı: test ağa çıkmaz).
class _FreeBackend implements PremiumBackend {
  @override
  Future<PremiumMe> me() async => const PremiumMe(
        active: false,
        until: null,
        productId: null,
        explorationRemaining: 3,
        explorationLimit: 3,
        monthKey: '2026-09',
      );

  @override
  Future<PremiumLinkResult> link(String transactionId) =>
      throw UnimplementedError();
}

/// KAYIT SONRASI PREMIUM TANITIMI (kurucu isteği 2026-09-23).
/// Sözleşme: yalnız GİRİŞ EYLEMİNDE (oturumsuz→üye ya da misafir→üye), cihaz
/// başına BİR KEZ; oturum geri yüklemesinde (açılış) ASLA — açılış paywall'u
/// değildir (K7 sıkmama sözleşmesiyle uzlaşma).

late SwitchableAuthController _auth;

Widget _app(AuthState initial, {FakePremiumIntroStore? store}) {
  _auth = SwitchableAuthController(initial);
  return ProviderScope(
    overrides: <Override>[
      authControllerProvider.overrideWith(() => _auth),
      premiumIntroStoreProvider
          .overrideWithValue(store ?? FakePremiumIntroStore()),
      // Mağaza + sunucu HER ZAMAN sahte (depo/ağ kuralı): tanıtım ekranı
      // "mağazaya ulaşılamıyor" hâlinde açılır — bu test için yeterli.
      purchaseGatewayProvider.overrideWithValue(FakeUnavailablePurchaseGateway()),
      premiumBackendProvider.overrideWithValue(_FreeBackend()),
      premiumOfflineStoreProvider.overrideWithValue(FakePremiumOfflineStore()),
    ],
    child: const MaterialApp(
      home: PremiumIntroGate(child: Scaffold(body: Text('ANA EKRAN'))),
    ),
  );
}

void main() {
  testWidgets('misafir → üye geçişinde tanıtım BİR KEZ açılır ve iz yazılır',
      (WidgetTester tester) async {
    final store = FakePremiumIntroStore();
    await tester.pumpWidget(_app(const Authenticated(testGuest), store: store));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);

    _auth.switchTo(const Authenticated(testUser));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(store.markCalls, 1);

    // Geri tuşu anında kapatır (dayatma yok).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('ANA EKRAN'), findsOneWidget);
  });

  testWidgets('oturumsuz → üye girişinde de açılır', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const Unauthenticated()));
    await tester.pumpAndSettle();
    _auth.switchTo(const Authenticated(testUser));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
  });

  testWidgets('daha önce gösterildiyse BİR DAHA açılmaz (cihaz başına tek)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(const Unauthenticated(),
        store: FakePremiumIntroStore(shown: true)));
    await tester.pumpAndSettle();
    _auth.switchTo(const Authenticated(testUser));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
  });

  testWidgets('oturum GERİ YÜKLEMESİ tanıtım açmaz (açılış paywall\'u yok)',
      (WidgetTester tester) async {
    final store = FakePremiumIntroStore();
    await tester.pumpWidget(_app(const AuthRestoring(), store: store));
    await tester.pumpAndSettle();
    _auth.switchTo(const Authenticated(testUser));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
    expect(store.markCalls, 0);
  });

  testWidgets('misafir GİRİŞİ tanıtım açmaz (üyelik değil)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(const Unauthenticated()));
    await tester.pumpAndSettle();
    _auth.switchTo(const Authenticated(testGuest));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsNothing);
  });
}
