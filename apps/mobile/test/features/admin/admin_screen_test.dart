import 'package:dockly_api/dockly_api.dart'
    show
        AdminContentItem,
        AdminDealInput,
        AdminEventInput,
        AdminPremiumGrant,
        AdminStats,
        EventParticipantView;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/admin/application/admin_controller.dart';
import 'package:dockly_mobile/features/admin/domain/admin_gateway.dart';
import 'package:dockly_mobile/features/admin/presentation/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// YÖNETİM PANELİ (kurucu talebi 2026-09-25): sayılar sunucudan gelir,
/// premium tanımlama e-postayla çalışır, hesap yoksa dürüst mesaj görünür.
class FakeAdminGateway implements AdminGateway {
  FakeAdminGateway({this.notFound = false});

  bool notFound;
  String? grantedEmail;
  int? grantedMonths;

  @override
  Future<AdminStats> stats() async => const AdminStats(
        totalUsers: 128,
        guestUsers: 40,
        newUsers7d: 9,
        premiumActive: 5,
        pendingModeration: 3,
        totalReviews: 61,
        totalNotes: 87,
      );

  @override
  Future<AdminPremiumGrant> grantPremium({
    required String email,
    required int months,
  }) async {
    if (notFound) throw const NotFoundFailure('Bulunamadı.');
    grantedEmail = email;
    grantedMonths = months;
    return AdminPremiumGrant(
      email: email,
      premiumUntil: DateTime.utc(2027, 9, 25),
    );
  }

  // Etkinlik/fırsat yönetimi (V1) — bu dosyanın testleri kullanmaz.
  @override
  Future<String> createEvent(AdminEventInput input) async => 'e-new';

  @override
  Future<void> cancelEvent(String eventId) async {}

  @override
  Future<List<EventParticipantView>> participants(String eventId) async =>
      <EventParticipantView>[];

  @override
  Future<String> createDeal(AdminDealInput input) async => 'd-new';

  @override
  Future<void> setDealActive(String dealId, {required bool isActive}) async {}

  // İçerik yönetimi (2026-10-27).
  List<AdminContentItem> content = <AdminContentItem>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<List<AdminContentItem>> listContent(String type) async => content;

  @override
  Future<void> deleteContent({required String type, required String id}) async {
    deletedIds.add(id);
    content = content.where((AdminContentItem r) => r.id != id).toList();
  }
}

Widget _app(FakeAdminGateway gw) => ProviderScope(
      overrides: <Override>[
        adminGatewayProvider.overrideWithValue(gw),
      ],
      child: const MaterialApp(home: AdminScreen()),
    );

void main() {
  testWidgets('sayı kartları sunucu verisiyle dolar', (WidgetTester tester) async {
    // CI dersi (bugün ekranı ile aynı): ListView TEMBELDİR — 600px'lik
    // varsayılan test ekranında alttaki dürüstlük notu hiç inşa edilmez ve
    // textContaining 0 bulur. Uzun ekranla tüm liste inşa edilir.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(FakeAdminGateway()));
    await tester.pumpAndSettle();

    expect(find.text('128'), findsOneWidget); // kayıtlı kullanıcı
    expect(find.text('5'), findsOneWidget); // aktif premium
    expect(find.text('Aktif Premium'), findsOneWidget);
    // Dürüstlük notu: indirme sayısının GERÇEK yeri söylenir.
    expect(find.textContaining('App Store Connect'), findsOneWidget);
  });

  testWidgets('premium tanımlama: e-posta + süre → onay mesajı ve çağrı',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeAdminGateway gw = FakeAdminGateway();
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('admin-grant-email')),
        'kaptan@ornek.com');
    await tester.tap(find.byKey(const ValueKey<String>('admin-grant-btn')));
    await tester.pumpAndSettle();

    expect(gw.grantedEmail, 'kaptan@ornek.com');
    expect(gw.grantedMonths, 12); // varsayılan seçim: 12 ay
    expect(find.textContaining('kaptan@ornek.com'), findsWidgets);
  });

  testWidgets('hesap yoksa dürüst mesaj görünür', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(FakeAdminGateway(notFound: true)));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('admin-grant-email')),
        'yok@ornek.com');
    await tester.tap(find.byKey(const ValueKey<String>('admin-grant-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Bu e-postayla kayıtlı bir hesap bulunamadı.'),
        findsOneWidget);
  });

  // ====== İÇERİK YÖNETİMİ (kurucu talebi 2026-10-27) ======
  testWidgets('İÇERİK YÖNETİMİ: satır panelden açılır; liste gelir; silme '
      'onayla çalışır ve liste tazelenir', (WidgetTester tester) async {
    final FakeAdminGateway gw = FakeAdminGateway()
      ..content = <AdminContentItem>[
        AdminContentItem(
          id: 'f0000000-0000-4000-f000-000000000001',
          title: 'Göcek 12 Adalar Klasiği',
          authorName: 'Kaptan Levent',
          status: 'approved',
          createdAt: DateTime.utc(2026, 10, 20),
        ),
      ];
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey<String>('admin-content')));
    await tester.tap(find.byKey(const ValueKey<String>('admin-content')));
    await tester.pumpAndSettle();

    expect(find.text('Göcek 12 Adalar Klasiği'), findsOneWidget);
    expect(find.text('Kaptan Levent · 20.10.2026'), findsOneWidget);

    // Sil → onay diyaloğu → onayla → satır gider, dürüst bilgi görünür.
    await tester.tap(find.byKey(
        const ValueKey<String>('admct-del-f0000000-0000-4000-f000-000000000001')));
    await tester.pumpAndSettle();
    expect(find.text('Yayından indirilsin mi?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('admct-confirm')));
    await tester.pumpAndSettle();

    expect(gw.deletedIds, <String>['f0000000-0000-4000-f000-000000000001']);
    expect(find.text('Göcek 12 Adalar Klasiği'), findsNothing);
    expect(find.text('Bu türde içerik yok.'), findsOneWidget);
  });

  testWidgets('İÇERİK YÖNETİMİ: tür çipleri listeyi değiştirir (tekneler '
      'gizli rozetiyle)', (WidgetTester tester) async {
    final FakeAdminGateway gw = FakeAdminGateway()
      ..content = <AdminContentItem>[
        AdminContentItem(
          id: 'd0000000-0000-4000-9000-000000000001',
          title: 'Martı · Beneteau',
          authorName: 'Meltem Y.',
          status: 'hidden',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ];
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(gw));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('admin-content')));
    await tester.tap(find.byKey(const ValueKey<String>('admin-content')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('admct-type-boats')));
    await tester.pumpAndSettle();
    expect(find.text('Martı · Beneteau'), findsOneWidget);
    expect(find.textContaining('Gizli'), findsOneWidget);
  });
}
