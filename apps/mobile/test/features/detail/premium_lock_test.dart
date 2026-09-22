import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/deria/application/deria_controller.dart';
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/detail/domain/location_detail_gateway.dart';
import 'package:dockly_mobile/features/detail/presentation/location_detail_screen.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/reviews/application/reviews_controller.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/community_fakes.dart';
import '../../support/deria_fakes.dart';
import '../../support/detail_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/reviews_fakes.dart';
import '../../support/weather_fakes.dart';

/// KİLİTLİ KOY DETAYI — VİTRİN (P4, kurucu onayı 2026-09-22, premium v3 §3/§6).
/// Sözleşme: vitrinde güvenlik özeti AÇIK, kilit kartı TEK premium çağrısı,
/// keşif hakkı yalnız hesaplı üyeye, açınca detay tam hâliyle yeniden gelir.

/// Vitrin (teaser) detay örneği — sunucunun kilitli alanları HİÇ göndermediği
/// hâli taklit eder: açıklama/iletişim/olanak boş, güvenlik özeti dolu.
LocationDetail teaserDetail({int? remaining}) => LocationDetail(
      id: 'loc-1',
      slug: 'kille-koyu',
      type: 'buoy',
      status: 'published',
      name: 'Kille Koyu',
      description: null,
      position: const GeoPoint(lat: 36.68, lon: 28.89),
      geo: const GeoInfo(countryCode: 'TR', adminArea: null, waterBody: null),
      dimensions: const Dimensions(
        maxBoatLengthM: 25,
        maxDraftM: 4,
        depthMinM: 7,
        depthMaxM: 8,
        capacity: null,
      ),
      priceTier: 'paid',
      is24h: false,
      verifiedAt: null,
      rating: const Rating(avg: 4.4, count: 12, dimensions: <RatingDimension>[]),
      amenities: const <AmenityLabeled>[],
      services: const <ServiceLabeled>[],
      contacts: const <Contact>[],
      hours: const <Hour>[],
      seasons: const <Season>[],
      typeDetails: null,
      media: const MediaInfo(cover: null, count: 6),
      counts: const Counts(reviews: 12, photos: 6),
      seabed: 'mud',
      shelteredDirs: 'K,KB',
      access: 'teaser',
      explorationRemaining: remaining,
    );

/// Durumu DEĞİŞTİRİLEBİLİR sahte ağ geçidi: keşif hakkı kullanılınca sunucu
/// gibi davranır — sonraki istek TAM detayı döndürür.
class MutableDetailGateway implements LocationDetailGateway {
  MutableDetailGateway(this.current);

  LocationDetail current;
  int fetchCount = 0;

  @override
  Future<LocationDetail> fetch(String idOrSlug) async {
    fetchCount += 1;
    return current;
  }
}

class FakeKesifGateway implements KesifGateway {
  FakeKesifGateway({this.remainingAfter = 1, this.onUnlock});

  final int remainingAfter;
  final void Function()? onUnlock;
  final List<String> calls = <String>[];

  @override
  Future<int> unlock(String idOrSlug) async {
    calls.add(idOrSlug);
    onUnlock?.call();
    return remainingAfter;
  }
}

Widget _app(
  LocationDetailGateway gateway, {
  KesifGateway? kesif,
  bool signedIn = false,
}) {
  return ProviderScope(
    overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      locationDetailGatewayProvider.overrideWithValue(gateway),
      nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
      reviewsGatewayProvider.overrideWithValue(FakeReviewsGateway()),
      weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
      deriaGatewayProvider.overrideWithValue(FakeDeriaGateway()),
      if (kesif != null) kesifGatewayProvider.overrideWithValue(kesif),
      if (signedIn) signedInAuthOverride(),
    ],
    child: const MaterialApp(home: LocationDetailScreen(idOrSlug: 'loc-1')),
  );
}

void main() {
  testWidgets('vitrin: güvenlik özeti AÇIK, kilit kartı görünür, kilitli bölümler yok',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(MutableDetailGateway(teaserDetail())));
    await tester.pumpAndSettle();

    // Vitrin: kimlik + kilit kartı.
    expect(find.text('Kille Koyu'), findsWidgets);
    expect(find.text("Koyun tamamı Premium'da"), findsOneWidget);
    expect(find.text("Premium'u tanı"), findsOneWidget);
    // Oturumsuz kullanıcıya üyelik çağrısı (keşif hakkı üyeliğe bağlı).
    expect(find.textContaining('Üye ol'), findsOneWidget);
    // Keşif hakkı düğmesi YOK (hesap yok).
    expect(find.textContaining('Keşif hakkınla aç'), findsNothing);
  });

  testWidgets('vitrin + üye: keşif hakkı düğmesi kalan sayıyla görünür; '
      'dokununca sunucuya gider ve detay TAM hâliyle yeniden gelir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gateway = MutableDetailGateway(teaserDetail(remaining: 2));
    final kesif = FakeKesifGateway(
      remainingAfter: 1,
      // Sunucu gibi: açma başarılı → sonraki detay isteği TAM döner.
      onUnlock: null,
    );
    await tester.pumpWidget(_app(gateway, kesif: kesif, signedIn: true));
    await tester.pumpAndSettle();

    final Finder unlockBtn = find.textContaining('Keşif hakkınla aç (2 kaldı)');
    expect(unlockBtn, findsOneWidget);

    gateway.current = sampleMarinaDetail; // açıldıktan sonraki "tam" yanıt
    await tester.tap(unlockBtn);
    await tester.pumpAndSettle();

    expect(kesif.calls, <String>['loc-1']);
    // Kilit kartı gitti, tam içerik geldi; kalan hak bilgisi kullanıcıya söylendi.
    expect(find.text("Koyun tamamı Premium'da"), findsNothing);
    expect(find.textContaining('1 keşif hakkın kaldı'), findsOneWidget);
  });

  testWidgets('vitrin + üye, hak BİTMİŞ (0): düğme yerine dürüst bilgi satırı',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      MutableDetailGateway(teaserDetail(remaining: 0)),
      signedIn: true,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Keşif hakkınla aç'), findsNothing);
    expect(find.textContaining('keşif hakları bitti'), findsOneWidget);
    expect(find.text("Premium'u tanı"), findsOneWidget);
  });

  testWidgets('TAM detayda kilit kartı ÇİZİLMEZ (regresyon)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(MutableDetailGateway(sampleMarinaDetail)));
    await tester.pumpAndSettle();

    expect(find.text("Koyun tamamı Premium'da"), findsNothing);
    expect(find.text("Premium'u tanı"), findsNothing);
  });
}
