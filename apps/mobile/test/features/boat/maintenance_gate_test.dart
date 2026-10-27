import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/domain/auth_state.dart';
import 'package:dockly_mobile/features/boat/application/maintenance_controller.dart';
import 'package:dockly_mobile/features/boat/domain/maintenance.dart';
import 'package:dockly_mobile/features/notifications/application/maintenance_reminder.dart';
import 'package:dockly_mobile/features/notifications/application/push_controller.dart';
import 'package:dockly_mobile/features/notifications/domain/local_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/auth_fakes.dart';
import '../../support/maintenance_fakes.dart';

/// BAKIM HESAP KAPISI (kurucu kararı 2026-10-27): bakım takibi de tekne ve
/// Defter gibi hesapla gezer. Ek olarak hatırlatma beyni v2: bildirim
/// telefona KURULUR (uygulama kapalıyken çalar), çıkışta kurulanlar sökülür.
class RecordingNotifier implements LocalNotifier {
  final List<int> shown = <int>[];
  final List<({int id, int atMs})> scheduled = <({int id, int atMs})>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> show({required int id, required String title, required String body}) async {
    shown.add(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
  }) async {
    scheduled.add((id: id, atMs: atMs));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MaintenanceRecord rec(String id, DateTime lastDone,
          {int? every, String? owner}) =>
      MaintenanceRecord(
        taskId: id,
        lastDoneMs:
            DateTime(lastDone.year, lastDone.month, lastDone.day)
                .millisecondsSinceEpoch,
        intervalDays: every,
        ownerUid: owner,
      );

  ProviderContainer container({
    FakeMaintenanceStore? store,
    RecordingNotifier? notifier,
    List<Override> extra = const <Override>[],
  }) {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        maintenanceStoreProvider
            .overrideWithValue(store ?? FakeMaintenanceStore()),
        if (notifier != null)
          // Runner'a sahte kaydedici verilir — kur/göster/iptal doğrulanır.
          localNotifierProvider.overrideWithValue(notifier),
        if (extra.isEmpty) signedInAuthOverride(),
        ...extra,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('HESAP KAPISI: çıkışta liste boşalır, dönüşte geri gelir; disk durur',
      () async {
    final FakeMaintenanceStore store = FakeMaintenanceStore()
      ..data = <MaintenanceRecord>[
        rec('engine_oil', DateTime(2026, 5, 1), owner: testUser.id),
      ];
    final ProviderContainer c = container(store: store, extra: <Override>[
      authControllerProvider.overrideWith(
          () => SwitchableAuthController(const Authenticated(testUser))),
    ]);
    c.read(maintenanceProvider); // tembel sağlayıcıyı kur (CI dersi 5.6)
    await Future<void>.delayed(Duration.zero);
    expect(c.read(maintenanceProvider), hasLength(1));

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Unauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(maintenanceProvider), isEmpty); // çıkış → bakım görünmez
    expect(store.data, hasLength(1)); // disk DURUYOR

    (c.read(authControllerProvider.notifier) as SwitchableAuthController)
        .switchTo(const Authenticated(testUser));
    c.read(maintenanceProvider); // geçiş sonrası da tembel — önce oku
    await Future<void>.delayed(Duration.zero);
    expect(c.read(maintenanceProvider).single.taskId, 'engine_oil');
  });

  test('HESAP KAPISI: sahipsiz eski kayıt sahiplenilir; başkasının kaydı '
      'gösterilmez ama yazarken korunur', () async {
    final FakeMaintenanceStore store = FakeMaintenanceStore()
      ..data = <MaintenanceRecord>[
        rec('engine_oil', DateTime(2026, 5, 1)), // kapıdan önce — sahipsiz
        rec('anodes', DateTime(2026, 5, 1), owner: 'baska-hesap'),
      ];
    final ProviderContainer c = container(store: store);
    c.read(maintenanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(maintenanceProvider).single.taskId, 'engine_oil');
    expect(c.read(maintenanceProvider).single.ownerUid, testUser.id);

    await c.read(maintenanceProvider.notifier).markDone('impeller');
    expect(c.read(maintenanceProvider), hasLength(2));
    expect(store.data, hasLength(3)); // yabancı kayıt SİLİNMEDİ
    expect(
        store.data.any((MaintenanceRecord r) => r.ownerUid == 'baska-hesap'),
        isTrue);
    // Yeni kayıt bu hesabın imzasını taşır.
    expect(
        store.data
            .firstWhere((MaintenanceRecord r) => r.taskId == 'impeller')
            .ownerUid,
        testUser.id);
  });

  test('JSON gidiş-dönüş: SAHİP korunur; eski biçim alan yazmaz', () {
    final MaintenanceRecord? back = MaintenanceRecord.fromJson(
        rec('engine_oil', DateTime(2026, 5, 1), every: 90, owner: 'u1')
            .toJson());
    expect(back?.ownerUid, 'u1');
    expect(back?.intervalDays, 90);
    expect(rec('x', DateTime(2026, 5, 1)).toJson().containsKey('owner'),
        isFalse);
  });

  test('HATIRLATMA v2: uzak kalem telefona KURULUR (eşik günü 10:00), '
      'eşiği geçmiş kalem hemen gösterilir', () async {
    final DateTime now = DateTime(2026, 10, 27);
    final FakeMaintenanceStore store = FakeMaintenanceStore()
      ..data = <MaintenanceRecord>[
        // 365 günlük motor yağı 300 gün önce → 65 gün kaldı: KURULUR.
        rec('engine_oil', now.subtract(const Duration(days: 300)),
            owner: testUser.id),
        // 180 günlük anot 170 gün önce → 10 gün kaldı: HEMEN gösterilir.
        rec('anodes', now.subtract(const Duration(days: 170)),
            owner: testUser.id),
      ];
    final RecordingNotifier notifier = RecordingNotifier();
    final ProviderContainer c = container(store: store, notifier: notifier);

    await c.read(maintenanceReminderProvider).run(now: now);

    expect(notifier.shown, hasLength(1)); // anot — eşik geçildi
    expect(notifier.scheduled, hasLength(1)); // motor yağı — ileriye kuruldu
    // Kurulum anı: eşiğin geçileceği gün (65-30=35 gün sonra) saat 10:00.
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(
        notifier.scheduled.single.atMs);
    expect(at.hour, 10);
    expect(at.difference(now).inDays, 35);

    // İkinci çalıştırma: anot BİR DAHA gösterilmez (tekrar koruması);
    // kurulum aynı kimlikle tazelenir (çift bildirim üretmez).
    notifier.shown.clear();
    await c.read(maintenanceReminderProvider).run(now: now);
    expect(notifier.shown, isEmpty);
  });

  test('HATIRLATMA v2: çıkışta kurulu TÜM bakım bildirimleri sökülür',
      () async {
    final RecordingNotifier notifier = RecordingNotifier();
    final ProviderContainer c = container(
      notifier: notifier,
      extra: <Override>[
        authControllerProvider
            .overrideWith(() => FixedAuthController(const Unauthenticated())),
      ],
    );

    await c.read(maintenanceReminderProvider).run();

    expect(notifier.cancelled, isNotEmpty); // 10 kalemin hepsi söküldü
    expect(notifier.shown, isEmpty);
    expect(notifier.scheduled, isEmpty);
  });
}
