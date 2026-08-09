import 'package:dockly_api/dockly_api.dart' show GeoPoint, LocationSummary;
import 'package:dockly_core/dockly_core.dart' show NetworkFailure;
import 'package:dockly_mobile/core/origin_provider.dart';
import 'package:dockly_mobile/features/checklist/application/checklist_controller.dart';
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/today/presentation/today_screen.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/checklist_fakes.dart';
import '../../support/detail_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/search_fakes.dart' show sampleSummary;
import '../../support/weather_fakes.dart';

/// BUGÜN testleri (v2.0): konum yokken dürüst yönlendirme; kontrol listesi;
/// AKILLI ÖNERİ bölümü ("Bugün Nereye?") gerçek sahtelerle uçtan uca.
void main() {
  testWidgets('konum yokken hava kartı yerine yönlendirme metni; '
      'öneri bölümü de çizilmez', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
        checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('konumunu paylaş'), findsOneWidget);
    expect(find.text('Bugün Nereye?'), findsNothing); // konum yok → öneri yok
    expect(find.byKey(const ValueKey<String>('today-checklist')), findsOneWidget);

    // Düğme kontrol listesini açar.
    await tester.tap(find.byKey(const ValueKey<String>('today-checklist')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('checklist-0')), findsOneWidget);
  });

  testWidgets('BUGÜN NEREYE?: yakın adaylar puan sırasıyla listelenir; '
      'bilgi eksikse rozet dürüstçe söyler', (WidgetTester tester) async {
    // İki aday: biri yakın (2 nm) biri uzak (15 nm). Detay kaydında açık
    // yön bilgisi YOK (sahte marina detayı) → ikisi de "bilgi yok" rozeti
    // alır; sıralamayı mesafe belirler.
    final FakeNearbyGateway nearby = FakeNearbyGateway(
      results: <LocationSummary>[
        sampleSummary('yakin', 'Boynuz Bükü', distanceNm: 2),
        sampleSummary('uzak', 'Ekincik Koyu', distanceNm: 15),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        originProvider.overrideWith(
            (ref) => const GeoPoint(lat: 36.74, lon: 28.94)),
        weatherGatewayProvider.overrideWithValue(
            FakeWeatherGateway(result: sampleForecast(windKn: 20, windDirDeg: 0))),
        checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
        nearbyGatewayProvider.overrideWithValue(nearby),
        locationDetailGatewayProvider
            .overrideWithValue(FakeLocationDetailGateway()),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bugün Nereye?'), findsOneWidget);
    expect(find.text('Boynuz Bükü'), findsOneWidget);
    expect(find.text('Ekincik Koyu'), findsOneWidget);
    // Puanlar şeffaf (halka içinde): yakın 90 (−10 bilgi eksik),
    // uzak 70 (−10 bilgi eksik, −20 mesafe).
    expect(find.text('%90'), findsOneWidget);
    expect(find.text('%70'), findsOneWidget);
    // Yakın aday listede ÜSTTE ve sıra numarası taşır.
    final double yakinY = tester.getTopLeft(find.text('Boynuz Bükü')).dy;
    final double uzakY = tester.getTopLeft(find.text('Ekincik Koyu')).dy;
    expect(yakinY, lessThan(uzakY));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    // Dürüst rozetler: açık yön bilgisi yok (iki adayda da) + yakın rozeti.
    expect(find.text('Açık yön bilgisi kayıtlarda yok'), findsNWidgets(2));
    expect(find.textContaining('Yakın · ≈2'), findsOneWidget);
    // ONAYLI E2 GEREKÇELERİ: süre tahmini + detaydan gelen derinlik.
    expect(find.textContaining('dnz mili ≈'), findsNWidgets(2));
    expect(find.textContaining('3-8 m derinlik'), findsNWidgets(2));
    // Her önerinin "Rota çiz" düğmesi var.
    expect(find.text('Rota çiz'), findsNWidgets(2));
    // Tahmin kaynağı ve saati görünür (kaynak gizlenmez).
    expect(find.textContaining('MET Norway'), findsWidgets);
    // Karar kaptanındır notu her zaman görünür.
    expect(find.textContaining('karar her zaman kaptanındır'), findsOneWidget);
  });

  testWidgets('GÜNÜN ÖZETİ (onaylı E2): rüzgâr · en iyi saat · deniz kutuları',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        originProvider.overrideWith(
            (ref) => const GeoPoint(lat: 36.74, lon: 28.94)),
        weatherGatewayProvider.overrideWithValue(FakeWeatherGateway(
            result: sampleForecast(windKn: 8, windDirDeg: 225))),
        checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
        nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
        locationDetailGatewayProvider
            .overrideWithValue(FakeLocationDetailGateway()),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('today-summary')), findsOneWidget);
    expect(find.text('RÜZGÂR'), findsOneWidget);
    expect(find.text('EN İYİ SAAT'), findsOneWidget);
    expect(find.text('DENİZ (rüzgâra göre)'), findsOneWidget);
    // Örnek tahminde tepe rüzgâr 21 kn → "Çırpıntılı"; yön GB.
    expect(find.text('Çırpıntılı'), findsOneWidget);
    expect(find.textContaining('kn GB'), findsOneWidget);
    // Kontrol listesi ilerlemesi kartın üstünde. (Hava kartının yatay
    // şeridi de bir Scrollable'dır — kaydırma hedefi AÇIKÇA verilir,
    // yoksa "too many elements" hatası alınır.)
    await tester.scrollUntilVisible(
      find.textContaining('0/10 · çıkmadan tamamla'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('0/10 · çıkmadan tamamla'), findsOneWidget);
  });

  testWidgets('öneri servisi hata verirse dürüst hata metni (bölüm kırılmaz)',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        originProvider.overrideWith(
            (ref) => const GeoPoint(lat: 36.74, lon: 28.94)),
        weatherGatewayProvider.overrideWithValue(
            FakeWeatherGateway(result: sampleForecast())),
        checklistStoreProvider.overrideWithValue(FakeChecklistStore()),
        nearbyGatewayProvider.overrideWithValue(
            FakeNearbyGateway(error: const NetworkFailure())),
        locationDetailGatewayProvider
            .overrideWithValue(FakeLocationDetailGateway()),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Öneriler şu an hazırlanamadı'), findsOneWidget);
  });
}
