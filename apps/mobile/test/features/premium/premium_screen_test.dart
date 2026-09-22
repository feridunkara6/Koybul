import 'dart:async';

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/premium/application/premium_controller.dart';
import 'package:dockly_mobile/features/premium/data/premium_offline_cache.dart';
import 'package:dockly_mobile/features/premium/domain/purchase_gateway.dart';
import 'package:dockly_mobile/features/premium/presentation/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/premium_fakes.dart';

/// KOYBUL PREMIUM paket ekranı (P3). Kurallar burada sabitlenir:
/// - fiyat KODDAN gelmez, mağazadan (sahtede bile öyle);
/// - misafir hesaba çağrılır, satın alma çizilmez;
/// - satın alma başarısı TEK BAŞINA yetmez — sunucu bağlama (link) çağrılır;
/// - "geri yükle" boş dönerse kullanıcıya dürüst bilgi verilir.

class FakeGateway implements PurchaseGateway {
  FakeGateway({this.available = true, this.packages = const <PremiumPackage>[]});

  bool available;
  List<PremiumPackage> packages;
  final List<String> buyCalls = <String>[];
  int restoreCalls = 0;
  final StreamController<PurchaseOutcome> controller =
      StreamController<PurchaseOutcome>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<PremiumPackage>> loadPackages() async => packages;

  @override
  Future<void> buy(PremiumPackage package) async {
    buyCalls.add(package.id);
  }

  @override
  Future<void> restore() async {
    restoreCalls += 1;
  }

  @override
  Stream<PurchaseOutcome> get outcomes => controller.stream;

  @override
  void dispose() {
    controller.close();
  }
}

class FakeBackend implements PremiumBackend {
  FakeBackend({required this.current});

  PremiumMe current;
  PremiumMe? afterLink;
  final List<String> linkCalls = <String>[];

  @override
  Future<PremiumMe> me() async => current;

  @override
  Future<PremiumLinkResult> link(String transactionId) async {
    linkCalls.add(transactionId);
    final PremiumMe? next = afterLink;
    if (next != null) current = next;
    return PremiumLinkResult(
      active: current.active,
      until: current.until,
      productId: current.productId,
    );
  }
}

const PremiumMe _freeMe = PremiumMe(
  active: false,
  until: null,
  productId: null,
  explorationRemaining: 3,
  explorationLimit: 3,
  monthKey: '2026-09',
);

final PremiumMe _activeMe = PremiumMe(
  active: true,
  until: DateTime.utc(2027, 9, 21),
  productId: 'koybul.premium.yillik',
  explorationRemaining: 3,
  explorationLimit: 3,
  monthKey: '2026-09',
);

const PremiumPackage _yearly = PremiumPackage(
  id: kPremiumYearlyId,
  price: '₺599,99',
  rawPrice: 599.99,
  currencySymbol: '₺',
);
const PremiumPackage _monthly = PremiumPackage(
  id: kPremiumMonthlyId,
  price: '₺79,99',
  rawPrice: 79.99,
  currencySymbol: '₺',
);

Widget _app(List<Override> overrides) {
  return ProviderScope(
    overrides: <Override>[
      // Çevrimdışı iz deposu HER ZAMAN sahte (depo kuralı, P4b): gerçek
      // shared_preferences testte sonsuza dek bekletir.
      premiumOfflineStoreProvider.overrideWithValue(FakePremiumOfflineStore()),
      ...overrides,
    ],
    child: const MaterialApp(home: PremiumScreen()),
  );
}

void main() {
  testWidgets('misafir: hesap çağrısı görünür, satın alma çizilmez',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(<Override>[
      signedInAuthOverride(user: testGuest),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Premium, Koybul hesabına bağlanır'),
        findsOneWidget);
    expect(find.text('Giriş yap / hesap aç'), findsOneWidget);
    expect(find.text("Premium'a geç"), findsNothing);
  });

  testWidgets('paketler MAĞAZADAN gelir: yıllık önde, rozetli, aylık karşılığı dürüst',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway(packages: <PremiumPackage>[_yearly, _monthly]);
    await tester.pumpWidget(_app(<Override>[
      signedInAuthOverride(),
      purchaseGatewayProvider.overrideWithValue(gateway),
      premiumBackendProvider.overrideWithValue(FakeBackend(current: _freeMe)),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Yıllık'), findsOneWidget);
    expect(find.text('Aylık'), findsOneWidget);
    // Fiyatlar sahte MAĞAZANIN verdiği metinler — kodda fiyat olmadığının kanıtı.
    expect(find.text('₺599,99'), findsOneWidget);
    expect(find.text('₺79,99'), findsOneWidget);
    expect(find.text('Avantajlı seçim'), findsOneWidget);
    // 599,99 ÷ 12 = 50,00 — dürüst bölme, uydurma indirim yüzdesi yok.
    expect(find.textContaining('₺50.00'), findsOneWidget);
    expect(find.text("Premium'a geç"), findsNWidgets(2));
  });

  testWidgets('satın alma: mağaza onayı SONRASI sunucu bağlama çağrılır, premium açılır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway(packages: <PremiumPackage>[_yearly, _monthly]);
    final backend = FakeBackend(current: _freeMe)..afterLink = _activeMe;
    await tester.pumpWidget(_app(<Override>[
      signedInAuthOverride(),
      purchaseGatewayProvider.overrideWithValue(gateway),
      premiumBackendProvider.overrideWithValue(backend),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Premium'a geç").first);
    await tester.pump();
    expect(gateway.buyCalls, <String>[kPremiumYearlyId]);

    // Mağaza onayladı → işlem kimliği sunucuya bağlanmalı (premium'u veren adım).
    gateway.controller.add(const PurchaseOutcome(PurchaseOutcomeKind.purchased,
        transactionId: 'tx-100'));
    await tester.pumpAndSettle();

    expect(backend.linkCalls, <String>['tx-100']);
    expect(find.text('Premium etkin'), findsOneWidget);
    // Etkin durumda satın alma düğmesi ÇİZİLMEZ.
    expect(find.text("Premium'a geç"), findsNothing);
  });

  testWidgets('geri yükle: boş dönerse dürüst bilgi notu görünür',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = FakeGateway(packages: <PremiumPackage>[_yearly, _monthly]);
    await tester.pumpWidget(_app(<Override>[
      signedInAuthOverride(),
      purchaseGatewayProvider.overrideWithValue(gateway),
      premiumBackendProvider.overrideWithValue(FakeBackend(current: _freeMe)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Satın alımları geri yükle'));
    await tester.pump();
    expect(gateway.restoreCalls, 1);

    gateway.controller
        .add(const PurchaseOutcome(PurchaseOutcomeKind.restoreFinished));
    await tester.pumpAndSettle();
    expect(find.textContaining('aktif yeni bir abonelik bulunamadı'),
        findsOneWidget);
  });

  testWidgets('mağazaya ulaşılamıyorsa kibar mesaj (çökme/boş ekran yok)',
      (WidgetTester tester) async {
    final gateway = FakeGateway(available: false);
    await tester.pumpWidget(_app(<Override>[
      signedInAuthOverride(),
      purchaseGatewayProvider.overrideWithValue(gateway),
      premiumBackendProvider.overrideWithValue(FakeBackend(current: _freeMe)),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mağazaya şu an ulaşılamıyor'), findsOneWidget);
  });

  testWidgets('premium zaten etkin: durum kartı + tarih, paket listesi yok',
      (WidgetTester tester) async {
    final gateway = FakeGateway(packages: <PremiumPackage>[_yearly]);
    await tester.pumpWidget(_app(<Override>[
      signedInAuthOverride(),
      purchaseGatewayProvider.overrideWithValue(gateway),
      premiumBackendProvider.overrideWithValue(FakeBackend(current: _activeMe)),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Premium etkin'), findsOneWidget);
    expect(find.textContaining('21.09.2027'), findsOneWidget);
    expect(find.text("Premium'a geç"), findsNothing);
  });
}
