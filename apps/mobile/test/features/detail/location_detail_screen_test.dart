import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/core/origin_provider.dart';
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/detail/domain/location_detail_gateway.dart';
import 'package:dockly_mobile/features/detail/presentation/location_detail_screen.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/reviews/application/reviews_controller.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';
import '../../support/auth_fakes.dart';
import '../../support/detail_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/reviews_fakes.dart';
import '../../support/weather_fakes.dart';

/// İkonlar artık SVG tabanlı [DocklyIcon]; Material `find.byIcon` yerine ikon
/// verisiyle bulunur.
Finder _docklyIcon(DocklyIconData d) =>
    find.byWidgetPredicate((Widget w) => w is DocklyIcon && w.data == d);

/// Detay ekranı testleri: yakın-alternatifler ve yorumlar ağ geçitleri boş sahte
/// ile override edilir (aksi halde gerçek API zinciri appConfig'e ulaşıp fırlatır).
/// `signedIn: true` → üyelik kapısı açık (hesaplı kullanıcı) senaryosu.
Widget _app(LocationDetailGateway gateway, {bool signedIn = false}) {
  return ProviderScope(
    overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      locationDetailGatewayProvider.overrideWithValue(gateway),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      reviewsGatewayProvider.overrideWithValue(FakeReviewsGateway()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      if (signedIn) signedInAuthOverride(),
    ],
    child: const MaterialApp(home: LocationDetailScreen(idOrSlug: 'loc-1')),
  );
}

void main() {
  testWidgets('detay yüklenince içerik gösterilir (tip + marina VHF)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle(); // Future.value çözülür → içerik.

    expect(find.byKey(LocationDetailScreen.contentKey), findsOneWidget);
    expect(find.text('Özel Marina'), findsOneWidget); // private_marina etiketi
    // VHF '73' bilgi bölümünde (listede aşağıda) — tembel liste onu görünür
    // olana dek kaydır (aksi hâlde henüz çizilmemiş olur).
    await tester.scrollUntilVisible(find.text('73'), 300);
    expect(find.text('73'), findsOneWidget); // marina VHF kanalı
  });

  testWidgets('telefon iletişimi tıklanabilir → "aç" ikonu görünür (P0)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle();

    // İletişim bölümü listenin altında; tembel liste onu görünür olana dek
    // kaydır (aksi hâlde henüz çizilmemiş olur).
    await tester.scrollUntilVisible(_docklyIcon(DocklyIcons.openInNew), 300);
    expect(_docklyIcon(DocklyIcons.openInNew), findsOneWidget);
  });

  testWidgets('origin biliniyorsa deniz yolu bölümü gösterilir (P2)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          locationDetailGatewayProvider.overrideWithValue(FakeLocationDetailGateway()),
          nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
          reviewsGatewayProvider.overrideWithValue(FakeReviewsGateway()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
          originProvider.overrideWith((ref) => const GeoPoint(lat: 40.0, lon: 28.93)),
        ],
        child: const MaterialApp(home: LocationDetailScreen(idOrSlug: 'loc-1')),
      ),
    );
    await tester.pumpAndSettle();
    // Deniz yolu bölümü listede aşağıda olabilir → görünene dek kaydır.
    await tester.scrollUntilVisible(find.textContaining('Deniz yolu'), 200);
    expect(find.textContaining('Deniz yolu'), findsOneWidget);
  });

  testWidgets('hata → mesaj + tekrar dene', (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway(error: const NetworkFailure())));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byKey(LocationDetailScreen.contentKey), findsNothing);
  });

  testWidgets('demirleme koyunda Rezervasyon Talebi YOK; notlar KOYA ÖZEL',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(FakeLocationDetailGateway(result: sampleAnchorageDetail)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rezervasyon Talebi'), findsNothing);
    await tester.scrollUntilVisible(find.text('Demirleme Notları'), 200);
    expect(find.text('Demirleme Notları'), findsOneWidget);
    expect(find.textContaining('ilk gelen demirler'), findsOneWidget);
    expect(find.textContaining('Ücretsiz demirleme alanı'), findsOneWidget);
    // Koya özel yapısal satırlar: zemin (holdingType=mud) + derinlik (7-8 m).
    expect(find.text('Zemin: Çamur'), findsOneWidget);
    expect(find.text('Derinlik: 7–8 m'), findsOneWidget);
    // Açıklamadaki demirleme + DİKKAT cümleleri karta taşındı (tek kopya)…
    expect(find.textContaining('tutuş iyidir'), findsOneWidget);
    expect(find.textContaining('tekil kaya'), findsOneWidget);
    // …koyu anlatan metin altta açıklama olarak duruyor. CI dersi: kart
    // uzadığı için açıklama görünür alanın DIŞINDA kalıyor ve tembel liste
    // onu kurmuyor — görünene dek kaydır, sonra doğrula.
    await tester.scrollUntilVisible(
        find.textContaining('her yönden korunaklı'), 200);
    expect(find.textContaining('her yönden korunaklı'), findsOneWidget);
    // Eski sabit içerik kalktı — koya özel olmayan öneri artık gösterilmez.
    expect(find.textContaining('Genel öneri'), findsNothing);
  });

  testWidgets('koya özel veri yoksa notlarda dürüst yedek metin gösterilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(FakeLocationDetailGateway(result: sampleBareAnchorageDetail)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Demirleme Notları'), 200);
    expect(find.textContaining('kayıtlı zemin ve uyarı bilgisi henüz yok'),
        findsOneWidget);
    // İşaret içermeyen açıklama olduğu gibi altta kalır (tembel liste:
    // görünene dek kaydır — kart kısayken de güvenli, zaten görünürse
    // kaydırma hiç yapılmaz).
    await tester.scrollUntilVisible(
        find.textContaining('Zeytinlikler arasında'), 200);
    expect(find.textContaining('Zeytinlikler arasında'), findsOneWidget);
    // priceTier 'unknown' → "Ücretsiz" iddiası YOK (0-uydurma).
    expect(find.textContaining('Ücretsiz demirleme alanı'), findsNothing);
  });

  testWidgets('marinada Rezervasyon Talebi düğmesi DURUYOR',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rezervasyon Talebi'), 200);
    expect(find.text('Rezervasyon Talebi'), findsOneWidget);
  });

  // --- Üyelik kapısı (kullanıcı kararı 2026-07) ---

  testWidgets('HESAPSIZ: Rezervasyon Talebi → "Hesap gerekli" sayfası açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rezervasyon Talebi'), 200);
    await tester.ensureVisible(find.text('Rezervasyon Talebi'));
    await tester.pump();
    await tester.tap(find.text('Rezervasyon Talebi'));
    await tester.pumpAndSettle();

    expect(find.text('Hesap gerekli'), findsOneWidget);
    expect(find.textContaining('Rezervasyon talebi göndermek'), findsOneWidget);
    // Rezervasyon sayfası AÇILMADI (başlık yalnız düğmede, tek kopya).
    expect(find.text('Rezervasyon Talebi'), findsOneWidget);
    // "Şimdi değil" ile kapanır, gezinme engellenmez.
    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
    expect(find.text('Hesap gerekli'), findsNothing);
  });

  testWidgets('HESAPLI: Rezervasyon Talebi doğrudan açılır (kapı yok)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway(), signedIn: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rezervasyon Talebi'), 200);
    await tester.ensureVisible(find.text('Rezervasyon Talebi'));
    await tester.pump();
    await tester.tap(find.text('Rezervasyon Talebi'));
    await tester.pumpAndSettle();

    expect(find.text('Hesap gerekli'), findsNothing);
    // Düğme + açılan sayfanın başlığı → iki kopya.
    expect(find.text('Rezervasyon Talebi'), findsNWidgets(2));
  });

  testWidgets('HESAPSIZ: telefon satırına dokununca kapı; numara görünür kalır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('+902526451234'), 300);
    expect(find.text('+902526451234'), findsOneWidget); // bilgi herkese açık
    await tester.ensureVisible(find.text('+902526451234'));
    await tester.pump();
    await tester.tap(find.text('+902526451234'));
    await tester.pumpAndSettle();
    expect(find.text('Hesap gerekli'), findsOneWidget);
    expect(find.textContaining('tek dokunuşla aramak'), findsOneWidget);
  });

  testWidgets('HESAPSIZ: favori kalbine dokununca kapı; favori eklenmez',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilere ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Hesap gerekli'), findsOneWidget);
    expect(find.text('Favorilere eklendi'), findsNothing);
  });

  testWidgets('HESAPLI: favori kalbi çalışır (SnackBar onayı)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway(), signedIn: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilere ekle'));
    await tester.pump();
    expect(find.text('Hesap gerekli'), findsNothing);
    expect(find.text('Favorilere eklendi'), findsOneWidget);
    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('kapıdan "Giriş yap veya kayıt ol" → giriş sayfası açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeLocationDetailGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorilere ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giriş yap veya kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('Hoş geldin, kaptan'), findsOneWidget); // SignInSheetBody
  });

  testWidgets(
      'demirleme OLMAYAN tipte zemin gösterilir, sahte "Ücretsiz" rozeti çıkmaz',
      (WidgetTester tester) async {
    // Ekran uzun; tembel liste görünmeyen çocukları kurmaz — yüzeyi büyüt.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(FakeLocationDetailGateway(result: samplePierWithSeabedDetail)),
    );
    await tester.pumpAndSettle();

    // "Bir Bakışta" şeridi zemini üst düzey `seabed` alanından okur.
    expect(find.text('Zemin'), findsOneWidget);
    expect(find.text('Kum'), findsOneWidget);
    // Derinlik de aynı şeritte (veri turunda dolan ikinci alan). Aynı metin
    // tekne uygunluğu kutusunda da geçebildiği için "en az bir" aranır.
    expect(find.text('4–9 m'), findsWidgets);
    // KRİTİK: barınağın ücret durumu bilinmiyor. Zemin kaydı eklendi diye
    // demirleme kartının "Ücretsiz" rozeti sızmamalı (API ayrımı: yalnız
    // mooring_point/buoy/guest_mooring kind='anchorage' üretir).
    expect(find.text('Ücretsiz'), findsNothing);

    // KORUNAKLI yönler kendi kutusunda çıkar…
    expect(find.text('Kapalı yön'), findsOneWidget);
    expect(find.text('K, GB'), findsOneWidget);
    // …ve "Açık yön" kutusu ÇIKMAZ: korunak ifadesi açık yöne çevrilmedi.
    // Bu satır ters çevirme hatasının nöbetçisidir.
    expect(find.text('Açık yön'), findsNothing);
  });

  testWidgets('her yönden korunaklı koy tek etikete iner (sekiz kısaltma değil)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(FakeLocationDetailGateway(result: sampleAllRoundShelterDetail)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kapalı yön'), findsOneWidget);
    expect(find.text('Her yönden'), findsOneWidget);
    // Sekiz kısaltmanın yan yana dizildiği ham liste GÖSTERİLMEZ.
    expect(find.text('K, KD, D, GD, G, GB, B, KB'), findsNothing);
  });

  testWidgets('açık yön ve kapalı yön AYNI ANDA, birbirinden bağımsız çıkar',
      (WidgetTester tester) async {
    // Gerçek kayıt: kaynak Ornos için hem "open to the S" hem "shelter in
    // northerlies" diyor. İkisi birbirinin tersi olmadığı için ikisi de ayrı
    // kutuda görünmeli — biri diğerinden TÜRETİLMEZ.
    // Genişlik bilerek 360 dp (gerçek telefon), çünkü şeritte beş kutu birden
    // çıkıyor. NOT: burada taşma İSTİSNASI aramanın anlamı yok — kutular
    // `Expanded` olduğu için yatay taşma yapısal olarak imkânsız, etiket de
    // `ellipsis` ile sessizce kırpılır. Ölçülen şey, iki alanın birbirinden
    // bağımsız çıkması ve zeminin kutuya sığan KISA adla yazılması.
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(FakeLocationDetailGateway(result: sampleBothWindDetail)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Açık yön'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Kapalı yön'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
    // Zemin kutuda KISA yazılır; parantezli açılım kutuyu altı satır uzatırdı.
    expect(find.text('Karışık'), findsOneWidget);
    expect(find.text('Karışık (kum/çamur/yosun)'), findsNothing);
  });
}
