import 'package:dockly_mobile/features/premium/application/premium_controller.dart';
import 'package:dockly_mobile/features/route/application/route_quota_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/map_fakes.dart';

/// GÜNLÜK ROTA KOTASI birim testleri (P4b, kurucu onayı 2026-09-22 — K3).
/// Sözleşme: ücretsiz günde 3; gece yarısı (YEREL) sıfırlanır; cihazda sürer;
/// premium sınırsız ve sayaç hiç işlemez.

ProviderContainer _container({
  bool premium = false,
  FakeRouteQuotaStore? store,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      isPremiumActiveProvider.overrideWithValue(premium),
      routeQuotaStoreProvider.overrideWithValue(store ?? FakeRouteQuotaStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('ücretsiz: 3 hak verilir, 4. istek REDDEDİLİR; sayaç cihaza yazılır', () async {
    final store = FakeRouteQuotaStore();
    final c = _container(store: store);
    final RouteQuotaController ctrl =
        c.read(routeQuotaControllerProvider.notifier);

    for (int i = 1; i <= 3; i++) {
      expect(await ctrl.tryConsume(), isTrue, reason: 'hak $i');
      expect(c.read(routeQuotaControllerProvider).used, i);
    }
    expect(await ctrl.tryConsume(), isFalse);
    expect(c.read(routeQuotaControllerProvider).used, 3);
    expect(c.read(routeQuotaControllerProvider).remaining, 0);

    // Kalıcılık: bugünün anahtarı + 3 kullanılmış hak cihazda.
    expect(store.day, RouteQuotaController.dayKeyFor(DateTime.now()));
    expect(store.used, 3);
  });

  test('GÖRÜNÜR SAYAÇ sinyali: consumeSeq yalnız BAŞARILI kullanımda artar; '
      'depodan tazeleme artırmaz', () async {
    final String today = RouteQuotaController.dayKeyFor(DateTime.now());
    final c = _container(store: FakeRouteQuotaStore(today, 2));
    final RouteQuotaController ctrl =
        c.read(routeQuotaControllerProvider.notifier);

    expect(await ctrl.tryConsume(), isTrue); // 3/3
    final RouteQuotaState s = c.read(routeQuotaControllerProvider);
    expect(s.used, 3); // depodaki 2 + bu kullanım
    expect(s.consumeSeq, 1); // tazeleme (2 hak) sinyal ÜRETMEDİ

    expect(await ctrl.tryConsume(), isFalse); // dolu
    expect(c.read(routeQuotaControllerProvider).consumeSeq, 1); // artmadı
  });

  test('GECE YARISI DEVRİ: gün değişince sayaç kendiliğinden sıfırlanır', () async {
    final c = _container();
    final RouteQuotaController ctrl =
        c.read(routeQuotaControllerProvider.notifier);

    // "Bugün" sabitlenir, 3 hak tüketilir.
    ctrl.nowProvider = () => DateTime(2026, 9, 22, 23, 50);
    for (int i = 0; i < 3; i++) {
      expect(await ctrl.tryConsume(), isTrue);
    }
    expect(await ctrl.tryConsume(), isFalse);

    // Saat gece yarısını geçti → yeni gün, yeni 3 hak.
    ctrl.nowProvider = () => DateTime(2026, 9, 23, 0, 5);
    expect(await ctrl.tryConsume(), isTrue);
    expect(c.read(routeQuotaControllerProvider).used, 1);
  });

  test('ESKİ GÜNÜN kaydı bugünü bağlamaz (uygulama günler sonra açıldı)', () async {
    final c = _container(store: FakeRouteQuotaStore('2020-01-01', 3));
    final RouteQuotaController ctrl =
        c.read(routeQuotaControllerProvider.notifier);
    expect(await ctrl.tryConsume(), isTrue);
    expect(c.read(routeQuotaControllerProvider).used, 1);
  });

  test('PREMIUM: sınırsız — sayaç işlemez, cihaza yazılmaz', () async {
    final store = FakeRouteQuotaStore();
    final c = _container(premium: true, store: store);
    final RouteQuotaController ctrl =
        c.read(routeQuotaControllerProvider.notifier);

    for (int i = 0; i < 10; i++) {
      expect(await ctrl.tryConsume(), isTrue);
    }
    final RouteQuotaState s = c.read(routeQuotaControllerProvider);
    expect(s.unlimited, isTrue);
    expect(s.used, 0);
    expect(store.day, isNull); // hiç yazılmadı
  });

  test('depo BOZUK/BOŞ olsa da kota oturum içinde çalışır (hata sızmaz)', () async {
    // null store zaten boş; burada dolu depo YOK sayılan gün anahtarıyla.
    final c = _container(store: FakeRouteQuotaStore(null, 5));
    final RouteQuotaController ctrl =
        c.read(routeQuotaControllerProvider.notifier);
    expect(await ctrl.tryConsume(), isTrue); // eksik kayıt = kayıt yok
    expect(c.read(routeQuotaControllerProvider).used, 1);
  });
}
