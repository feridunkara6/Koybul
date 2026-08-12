import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/deria/application/deria_controller.dart';
import 'package:dockly_mobile/core/origin_provider.dart';
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/detail/presentation/location_detail_screen.dart';
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/reviews/application/reviews_controller.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';
import '../../support/deria_fakes.dart';
import '../../support/detail_fakes.dart';
import '../../support/location_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/reviews_fakes.dart';
import '../../support/weather_fakes.dart';

/// DETAY YENİDEN TASARIMI testleri (2026-08, kullanıcı onaylı A+B+C+D):
/// kimlik kartı, "Bir Bakışta" şeridi, yaklaşma notu kartı, iletişim
/// kutucukları ve yapışkan eylem çubuğu.
///
/// Yaklaşma notlu örnek: seed sözleşmesine birebir uygun açıklama
/// (taban + "\n\n" + "Yaklaşma notu: " + not).
const LocationDetail sampleApproachDetail = LocationDetail(
  id: 'loc-yaklasma',
  slug: 'resifli-koy',
  type: 'mooring_point',
  status: 'published',
  name: 'Resifli Koy',
  description: 'Çam ormanlarıyla çevrili sakin bir demirleme koyu.\n\n'
      'Yaklaşma notu: Girişte batı burnu açığında resif uzanır; '
      'son yaklaşmayı resmî haritayla planlayın.',
  position: GeoPoint(lat: 36.8, lon: 28.3),
  geo: GeoInfo(
    countryCode: 'TR',
    adminArea: AdminAreaRef(id: 'a9', name: 'Marmaris', province: 'Muğla'),
    waterBody: null,
  ),
  dimensions: Dimensions(
    maxBoatLengthM: null,
    maxDraftM: null,
    depthMinM: 4,
    depthMaxM: 8,
    capacity: null,
  ),
  priceTier: 'free',
  is24h: false,
  verifiedAt: null,
  rating: Rating(avg: null, count: 0, dimensions: <RatingDimension>[]),
  amenities: <AmenityLabeled>[],
  services: <ServiceLabeled>[],
  contacts: <Contact>[],
  hours: <Hour>[],
  seasons: <Season>[],
  typeDetails: AnchorageTypeDetails(
    holdingType: 'sand',
    protectionN: null,
    protectionS: null,
    protectionE: null,
    protectionW: null,
    swellExposure: null,
    isFree: true,
  ),
  media: MediaInfo(cover: null, count: 0),
  counts: Counts(reviews: 0, photos: 0),
);

Widget _app(LocationDetail detail, {List<Override> extra = const <Override>[]}) {
  return ProviderScope(
    overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      locationDetailGatewayProvider
          .overrideWithValue(FakeLocationDetailGateway(result: detail)),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      reviewsGatewayProvider.overrideWithValue(FakeReviewsGateway()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      deriaGatewayProvider.overrideWithValue(FakeDeriaGateway()),
      // CI DERSİ (2026-08): gerçek konum eklentisi widget testinde ASLA
      // çalıştırılmamalı — kanal yanıtı sahte-zaman döngüsünde hiç gelmez ve
      // akış sonsuza dek bekler (başlangıç menüsü hiç açılmaz → kırmızı).
      // Sahte servis: konum alınamadı → null (izin reddi senaryosu).
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
      ...extra,
    ],
    child: const MaterialApp(home: LocationDetailScreen(idOrSlug: 'loc-1')),
  );
}

void main() {
  testWidgets('A) KİMLİK KARTI: tip çipi + doğrulanmış + koordinat gösterilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleMarinaDetail));
    await tester.pumpAndSettle();

    expect(find.text('Özel Marina'), findsOneWidget); // tip çipi
    expect(find.text('Doğrulanmış'), findsOneWidget); // verifiedAt dolu
    // Koordinat kimlik kartında (4 ondalık) — dokununca kopyalanır.
    expect(find.text('36.7500, 28.9300'), findsOneWidget);
  });

  testWidgets('A) koordinata dokun → panoya kopyalanır ve onay görünür',
      (WidgetTester tester) async {
    // Pano platform kanalı testte sahtelenir (emergency_screen deseni).
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(_app(sampleMarinaDetail));
    await tester.pumpAndSettle();
    await tester.tap(find.text('36.7500, 28.9300'));
    await tester.pumpAndSettle();
    final MethodCall copy =
        calls.lastWhere((MethodCall c) => c.method == 'Clipboard.setData');
    expect((copy.arguments as Map<Object?, Object?>)['text'], '36.7500, 28.9300');
    expect(find.text('Koordinatlar panoya kopyalandı.'), findsOneWidget);
    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('A) BİR BAKIŞTA: derinlik + zemin + teknem kutuları (koya özel)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleAnchorageDetail));
    await tester.pumpAndSettle();

    expect(find.text('Derinlik'), findsOneWidget);
    expect(find.text('7–8 m'), findsOneWidget); // şerit değeri
    expect(find.text('Zemin'), findsOneWidget);
    expect(find.text('Çamur'), findsOneWidget);
    // Tekne tanımsız → kutu iddiada bulunmaz, tanımlama daveti taşır.
    expect(find.text('Teknem'), findsOneWidget);
    expect(find.text('Tekneni tanımla'), findsOneWidget);
  });

  testWidgets('B) YAKLAŞMA NOTU: açıklamadan ayrılır, uyarı kartında gösterilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleApproachDetail));
    await tester.pumpAndSettle();

    expect(find.text('Yaklaşma notu'), findsOneWidget); // kart başlığı
    expect(find.textContaining('batı burnu açığında resif'), findsOneWidget);
    // Taban metin "Hakkında" kartında ve ÖNEKSİZ (çift gösterim yok).
    // ÖNEM SIRASI (2026-08): Hakkında artık sayfanın alt yarısında —
    // tembel liste onu ancak kaydırınca kurar.
    await tester.scrollUntilVisible(
        find.textContaining('Çam ormanlarıyla çevrili'), 200);
    expect(find.textContaining('Çam ormanlarıyla çevrili'), findsOneWidget);
    expect(find.textContaining('Yaklaşma notu:'), findsNothing);
  });

  testWidgets('D) YAPIŞKAN ÇUBUK: koyda Deniz rotası + Doluluk bildir her an görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleAnchorageDetail));
    await tester.pumpAndSettle();

    // Kaydırma YAPMADAN bulunmalılar (yapışkan çubuk).
    expect(find.text('Deniz rotası'), findsOneWidget);
    expect(find.text('Doluluk bildir'), findsOneWidget);
    expect(find.text('Rezervasyon Talebi'), findsNothing); // ürün kararı
  });

  testWidgets('D) marinada ikinci eylem Rezervasyon Talebi olur',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleMarinaDetail));
    await tester.pumpAndSettle();

    expect(find.text('Deniz rotası'), findsOneWidget);
    expect(find.text('Rezervasyon Talebi'), findsOneWidget);
    expect(find.text('Doluluk bildir'), findsNothing);
  });

  testWidgets('D) GPS yokken rota düğmesi BAŞLANGIÇ MENÜSÜ açar (rota planlama); '
      '"Konumumdan" seçilirse konum uyarısı gösterilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleAnchorageDetail));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deniz rotası'));
    await tester.pumpAndSettle();
    // Menü: iki seçenek (konumdan bağımsız planlama — kullanıcı onaylı).
    expect(find.text('Konumumdan'), findsOneWidget);
    expect(find.text('Başlangıç noktası seç'), findsOneWidget);
    await tester.tap(find.text('Konumumdan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('önce konumunu paylaşmalısın'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });

  testWidgets('D) UX P0 (2026-08): marinada ARA kısayolu + favori kalbi '
      'yapışkan çubukta, kaydırmadan erişilir', (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleMarinaDetail));
    await tester.pumpAndSettle();

    // Kaydırma YAPMADAN bulunmalılar (yapışkan çubuk).
    expect(find.byKey(const ValueKey<String>('detail-call-button')),
        findsOneWidget);
    expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
  });

  testWidgets('D) UX P0: telefon kaydı olmayan koyda ARA ikonu HİÇ çizilmez; '
      'kalp yine çubukta', (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleAnchorageDetail));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('detail-call-button')),
        findsNothing);
    expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
  });

  testWidgets('D) UX P0: HESAPSIZ Ara kısayolu üyelik kapısına çıkar '
      '(iletişim kutucuğuyla aynı kapı)', (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleMarinaDetail));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('detail-call-button')));
    await tester.pumpAndSettle();
    expect(find.text('Hesap gerekli'), findsOneWidget);
    expect(find.textContaining('tek dokunuşla aramak'), findsOneWidget);
    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
  });

  testWidgets('C) İLETİŞİM KUTUCUĞU: "Ara" etiketi + numara birlikte görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(sampleMarinaDetail));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('+902526451234'), 300);
    expect(find.text('Ara'), findsOneWidget);
    expect(find.text('+902526451234'), findsOneWidget);
  });

  testWidgets('deniz yolu bölümü kartlaştı; rota eylemi çubukta tek kopya',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      sampleAnchorageDetail,
      extra: <Override>[
        originProvider.overrideWith((ref) => const GeoPoint(lat: 36.0, lon: 29.5)),
      ],
    ));
    await tester.pumpAndSettle();

    // Bilgi bölümü listede; eylem düğmesi yalnız çubukta (tek 'Deniz rotası').
    await tester.scrollUntilVisible(find.textContaining('Deniz yolu'), 200);
    expect(find.textContaining('Deniz yolu'), findsOneWidget);
    expect(find.text('Deniz rotası'), findsOneWidget);
  });
}
