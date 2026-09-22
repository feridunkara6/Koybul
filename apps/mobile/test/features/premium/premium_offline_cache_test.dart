import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/premium/application/premium_controller.dart';
import 'package:dockly_mobile/features/premium/data/premium_offline_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/auth_fakes.dart';

/// PREMIUM ÇEVRİMDIŞI HAFIZASI (P4b, premium v3 §7 "denizde internet yok").
/// Sözleşme: son başarılı /premium/me yanıtının bitiş tarihi cihazda saklanır;
/// ağ yokken tarih GEÇMEDİYSE premium sürer, geçtiyse biter — uydurma uzatma
/// yok, bitmiş üyelik çevrimdışına "aktif" diye taşınmaz.

PremiumMe _me({required bool active, DateTime? until, String? productId}) =>
    PremiumMe(
      active: active,
      until: until,
      productId: productId,
      explorationRemaining: 2,
      explorationLimit: 3,
      monthKey: '2026-09',
    );

/// Hep hata fırlatan sahte sunucu — "denizde ağ yok" senaryosu.
class _OfflineBackend implements PremiumBackend {
  int calls = 0;

  @override
  Future<PremiumMe> me() async {
    calls++;
    throw const NetworkFailure();
  }

  @override
  Future<PremiumLinkResult> link(String transactionId) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('save→read: aktif üyelik tarihiyle geri gelir; keşif sayaçları '
      'çevrimdışı BİLİNMEZ (dürüstçe 0)', () async {
    final DateTime until = DateTime.now().add(const Duration(days: 200));
    await PremiumOfflineCache.save(
        _me(active: true, until: until, productId: 'koybul.premium.yillik'));

    final PremiumMe? cached = await PremiumOfflineCache.read();
    expect(cached, isNotNull);
    expect(cached!.active, isTrue);
    expect(cached.until!.millisecondsSinceEpoch, until.millisecondsSinceEpoch);
    expect(cached.productId, 'koybul.premium.yillik');
    expect(cached.explorationRemaining, 0); // uydurma sayaç yok
  });

  test('SÜRESİ GEÇMİŞ iz null döner (çevrimdışı af yok — tarih tek hakem)', () async {
    await PremiumOfflineCache.save(_me(
      active: true,
      until: DateTime.now().add(const Duration(seconds: 1)),
    ));
    // Tarihi geçmiş izi taklit et: geçmiş tarihle yeniden yaz.
    await PremiumOfflineCache.save(_me(
      active: true,
      until: DateTime.now().subtract(const Duration(days: 1)),
    ));
    expect(await PremiumOfflineCache.read(), isNull);
  });

  test('aktif OLMAYAN durum izi SİLER (bitmiş üyelik "aktif" taşınmaz)', () async {
    await PremiumOfflineCache.save(_me(
      active: true,
      until: DateTime.now().add(const Duration(days: 30)),
    ));
    expect(await PremiumOfflineCache.read(), isNotNull);

    await PremiumOfflineCache.save(_me(active: false, until: null));
    expect(await PremiumOfflineCache.read(), isNull);
  });

  test('premiumMeProvider: sunucuya ULAŞILAMAYINCA cihazdaki geçerli iz döner — '
      'denizde premium sıfırlanmaz', () async {
    final DateTime until = DateTime.now().add(const Duration(days: 90));
    await PremiumOfflineCache.save(_me(active: true, until: until));

    final backend = _OfflineBackend();
    final container = ProviderContainer(overrides: <Override>[
      signedInAuthOverride(),
      premiumBackendProvider.overrideWithValue(backend),
    ]);
    addTearDown(container.dispose);

    final PremiumMe? me = await container.read(premiumMeProvider.future);
    expect(backend.calls, 1); // önce sunucu DENENDİ (iz yetki kaynağı değil)
    expect(me, isNotNull);
    expect(me!.active, isTrue);

    // isPremiumActiveProvider da aynı karara bağlanır (kota sınırsız çalışır).
    await container.read(premiumMeProvider.future);
    expect(container.read(isPremiumActiveProvider), isTrue);
  });

  test('premiumMeProvider: ağ yok VE iz de yoksa hata YÜZEYE çıkar '
      '(sessiz sahte "premium değilsin" uydurulmaz)', () async {
    final container = ProviderContainer(overrides: <Override>[
      signedInAuthOverride(),
      premiumBackendProvider.overrideWithValue(_OfflineBackend()),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(premiumMeProvider.future), throwsA(isA<NetworkFailure>()));
    // Kota kapıları güvenli tarafta: hata = premium DEĞİL (haksız kapama yok,
    // ücretsiz kurala düşüş).
    expect(container.read(isPremiumActiveProvider), isFalse);
  });
}
