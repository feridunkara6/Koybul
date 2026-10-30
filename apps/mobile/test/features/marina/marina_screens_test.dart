import 'package:dockly_api/dockly_api.dart'
    show MarinaBoat, MarinaCommunity, MyMarinaBoat;
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/boat/application/my_boat_controller.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/marina/application/marina_controller.dart';
import 'package:dockly_mobile/features/marina/domain/marina_gateway.dart';
import 'package:dockly_mobile/features/marina/presentation/marina_community_screen.dart';
import 'package:dockly_mobile/features/marina/presentation/marinam_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/welcome_fakes.dart' show FakeBoatStorage;

/// MARİNA TOPLULUĞU ekran testleri (V1 — kurucu onayı 2026-10-23).
/// Kural (docs/15): ağ ve SharedPreferences yok — geçit ve depo sahtedir.

const MyBoat kLocalBoat = MyBoat(
  lengthM: 10.4,
  name: 'Martı',
  typeId: 'sail',
  brand: 'Beneteau',
  model: 'Oceanis 38.1', // Hafta 2: model + yıl da sunucuya gider
  buildYear: 2019,
  homeMarina: HomeMarina(id: 'loc-marti', name: 'Martı Marina', lat: 36.77, lon: 28.12),
);

MyMarinaBoat serverBoat({
  bool visible = false,
  bool shareSpecs = false,
  String? story,
  String storyStatus = 'approved',
}) =>
    MyMarinaBoat(
      boatId: 'b1',
      name: 'Martı',
      boatTypeCode: 'sailboat',
      lengthM: 10.4,
      brand: 'Beneteau',
      marinaId: 'loc-marti',
      marinaName: 'Martı Marina',
      visible: visible,
      shareSpecs: shareSpecs,
      story: story,
      storyStatus: storyStatus,
    );

MarinaCommunity community({
  String access = 'full',
  int total = 12,
  int visibleCount = 1,
  List<MarinaBoat> boats = const <MarinaBoat>[],
}) =>
    MarinaCommunity(
      marinaId: 'loc-marti',
      marinaName: 'Martı Marina',
      total: total,
      visibleCount: visibleCount,
      access: access,
      boats: boats,
    );

class FakeMarinaGateway implements MarinaGateway {
  FakeMarinaGateway({this.mine, required this.communityResult});

  MyMarinaBoat? mine;
  MarinaCommunity communityResult;
  final List<Map<String, Object?>> upserts = <Map<String, Object?>>[];

  @override
  Future<MyMarinaBoat?> myBoat() async => mine;

  @override
  Future<MyMarinaBoat> upsertMyBoat({
    required String name,
    required String boatTypeCode,
    required double lengthM,
    String? brand,
    String? model,
    int? buildYear,
    required String marinaLocationId,
    required bool visible,
    required bool shareSpecs,
    bool storySet = false,
    String? story,
  }) async {
    upserts.add(<String, Object?>{
      'name': name,
      'boatTypeCode': boatTypeCode,
      'lengthM': lengthM,
      'brand': brand,
      'model': model,
      'buildYear': buildYear,
      'marinaLocationId': marinaLocationId,
      'visible': visible,
      'shareSpecs': shareSpecs,
      'storySet': storySet,
      'story': story,
    });
    mine = MyMarinaBoat(
      boatId: 'b1',
      name: name,
      boatTypeCode: boatTypeCode,
      lengthM: lengthM,
      brand: brand,
      marinaId: marinaLocationId,
      marinaName: 'Martı Marina',
      visible: visible,
      shareSpecs: shareSpecs,
      story: storySet ? story : mine?.story,
      storyStatus: storySet && story != null ? 'pending' : 'approved',
    );
    return mine!;
  }

  @override
  Future<MarinaCommunity> community(String locationId) async => communityResult;
}

Widget _app({
  required FakeMarinaGateway gw,
  required Widget home,
  MyBoat? localBoat,
  bool signedIn = true,
  // KART tam ekran değildir → kaydırmalı Scaffold'a sarılır. EKRANLAR kendi
  // Scaffold'unu getirir; onları ikinci bir kaydırıcıya sarmak sonsuz
  // yükseklik hatası doğurur (CI dersi 2026-10-23) — çıplak verilirler.
  bool wrapCard = false,
}) {
  final Widget child =
      wrapCard ? Scaffold(body: SingleChildScrollView(child: home)) : home;
  return ProviderScope(
    overrides: <Override>[
      marinaGatewayProvider.overrideWithValue(gw),
      boatStorageProvider
          .overrideWithValue(FakeBoatStorage(boat: localBoat)),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      if (signedIn) signedInAuthOverride(),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Marinam: hesap yokken giriş daveti görünür',
      (WidgetTester tester) async {
    final FakeMarinaGateway gw =
        FakeMarinaGateway(communityResult: community());
    await tester.pumpWidget(
        _app(gw: gw, home: const MarinamCard(), signedIn: false, wrapCard: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('marinam-signin')), findsOneWidget);
    expect(gw.upserts, isEmpty);
  });

  testWidgets('Marinam: marina seçilmemişse seçim daveti görünür',
      (WidgetTester tester) async {
    final FakeMarinaGateway gw =
        FakeMarinaGateway(communityResult: community());
    await tester.pumpWidget(_app(
      gw: gw,
      home: const MarinamCard(),
      localBoat: const MyBoat(lengthM: 10.4, name: 'Martı', typeId: 'sail'),
      wrapCard: true,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('marinam-pick')), findsOneWidget);
  });

  testWidgets(
      'Marinam: katılmamış tekne AÇIK RIZAYLA katılır — varsayılan GİZLİ gider',
      (WidgetTester tester) async {
    final FakeMarinaGateway gw =
        FakeMarinaGateway(communityResult: community());
    await tester.pumpWidget(
        _app(gw: gw, home: const MarinamCard(), localBoat: kLocalBoat, wrapCard: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('marinam-join')));
    await tester.pumpAndSettle();

    expect(gw.upserts, hasLength(1));
    expect(gw.upserts.single['marinaLocationId'], 'loc-marti');
    expect(gw.upserts.single['boatTypeCode'], 'sailboat'); // yerel 'sail' eşlendi
    expect(gw.upserts.single['visible'], false); // gizlilik varsayılanı
    expect(gw.upserts.single['shareSpecs'], false);
    // Hafta 2: model + yıl yereldeki tekneden aynen taşınır (çizim köprüsü).
    expect(gw.upserts.single['model'], 'Oceanis 38.1');
    expect(gw.upserts.single['buildYear'], 2019);
    // Katılım sonrası sayı kutuları ve anahtarlar görünür.
    expect(find.byKey(const ValueKey<String>('marinam-visible')), findsOneWidget);
  });

  testWidgets('Marinam: "Marinada görün" anahtarı sunucuya visible=true yazar',
      (WidgetTester tester) async {
    final FakeMarinaGateway gw = FakeMarinaGateway(
        mine: serverBoat(), communityResult: community());
    await tester.pumpWidget(
        _app(gw: gw, home: const MarinamCard(), localBoat: kLocalBoat, wrapCard: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('marinam-visible')));
    await tester.pumpAndSettle();
    expect(gw.upserts.single['visible'], true);
    expect(gw.upserts.single['shareSpecs'], false); // diğer anahtar korunur
  });

  testWidgets('HİKÂYE (0024): satırdan sayfa açılır, kayıt storySet ile gider; '
      'anahtar değişikliği hikâye GÖNDERMEZ', (WidgetTester tester) async {
    final FakeMarinaGateway gw = FakeMarinaGateway(
        mine: serverBoat(), communityResult: community());
    await tester.pumpWidget(_app(
        gw: gw, home: const MarinamCard(), localBoat: kLocalBoat, wrapCard: true));
    await tester.pumpAndSettle();

    // Anahtar dokunuşu hikâye alanı taşımaz (mevcut hikâye silinmesin!).
    await tester.tap(find.byKey(const ValueKey<String>('marinam-visible')));
    await tester.pumpAndSettle();
    expect(gw.upserts.single['storySet'], false);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('marinam-story')));
    await tester.tap(find.byKey(const ValueKey<String>('marinam-story')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey<String>('marinam-story-field')),
        "2019'da Göcek'te teslim aldık; adı direğe konan martıdan.");
    await tester.tap(find.byKey(const ValueKey<String>('marinam-story-save')));
    await tester.pumpAndSettle();

    expect(gw.upserts, hasLength(2));
    expect(gw.upserts.last['storySet'], true);
    expect('${gw.upserts.last['story']}', contains('Göcek'));
    // Dürüst süreç mesajı: önce moderasyon.
    expect(find.textContaining('onaya gönderildi'), findsOneWidget);
  });

  testWidgets('Topluluk: tam erişimde liste + gizli sayısı + rıza süzgeci',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeMarinaGateway gw = FakeMarinaGateway(
      communityResult: community(
        total: 12,
        visibleCount: 2,
        boats: const <MarinaBoat>[
          MarinaBoat(
              boatId: 'b-ruzgar', // Hafta 2: Tekne Kartı köprüsü
              name: 'Rüzgargülü',
              boatTypeCode: 'sailboat',
              lengthM: 12,
              brand: 'Hanse',
              captainName: 'Deniz K.'),
          MarinaBoat(
              name: 'Poyraz', // boatId YOK — eski sunucu uyumu: satır düz kalır
              boatTypeCode: 'motor_yacht',
              lengthM: null, // shareSpecs kapalı — boy istemciye inmedi
              brand: null,
              captainName: 'Uğur T.'),
        ],
      ),
    );
    await tester.pumpWidget(_app(
        gw: gw, home: const MarinaCommunityScreen(marinaId: 'loc-marti')));
    await tester.pumpAndSettle();

    expect(find.text('Rüzgargülü'), findsOneWidget);
    expect(find.textContaining('12 m · Hanse'), findsOneWidget);
    expect(find.text('Poyraz'), findsOneWidget);
    expect(find.textContaining('Kaptan: Uğur T.'), findsOneWidget);
    expect(find.textContaining('+10 tekne gizli'), findsOneWidget); // 12-2
    expect(find.textContaining('beyanına dayanır'), findsOneWidget); // dürüstlük
    // TEKNE KARTI KÖPRÜSÜ (Hafta 2): kimlikli satır dokunulabilir,
    // kimliksiz (eski sunucu) satır düz kalır.
    expect(find.byKey(const ValueKey<String>('mc-boat-b-ruzgar')), findsOneWidget);
  });

  testWidgets('Topluluk: liste kilitliyken tekneler çizilmez, sayılar durur',
      (WidgetTester tester) async {
    final FakeMarinaGateway gw = FakeMarinaGateway(
      communityResult: community(access: 'counts', total: 12, visibleCount: 7),
    );
    await tester.pumpWidget(_app(
        gw: gw, home: const MarinaCommunityScreen(marinaId: 'loc-marti')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('mc-locked')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('Topluluk: boş rıhtım öncülük mesajı + davet kopyalama',
      (WidgetTester tester) async {
    final FakeMarinaGateway gw = FakeMarinaGateway(
      communityResult:
          community(total: 1, visibleCount: 0, boats: const <MarinaBoat>[]),
    );
    await tester.pumpWidget(_app(
        gw: gw, home: const MarinaCommunityScreen(marinaId: 'loc-marti')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ilk sensin'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mc-invite')), findsOneWidget);
  });
}
