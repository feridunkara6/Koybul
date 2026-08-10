import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/features/detail/application/location_detail_controller.dart';
import 'package:dockly_mobile/features/detail/presentation/location_detail_screen.dart';
import 'package:dockly_mobile/features/emergency/presentation/emergency_screen.dart';
import 'package:dockly_mobile/features/nearby/application/nearby_controller.dart';
import 'package:dockly_mobile/features/profile/presentation/profile_screen.dart';
import 'package:dockly_mobile/features/reviews/application/reviews_controller.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:dockly_mobile/features/search/application/search_controller.dart';
import 'package:dockly_mobile/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';
import '../../support/detail_fakes.dart';
import '../../support/nearby_fakes.dart';
import '../../support/reviews_fakes.dart';
import '../../support/search_fakes.dart';
import '../../support/weather_fakes.dart';

Widget _app({AppLocale? locale}) {
  return ProviderScope(
    overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
      if (locale != null)
        appLocaleProvider.overrideWith(() => AppLocaleController(locale)),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

/// CI dersi: "Dil" satırı Profil listesinin EN ALTINDA — tembel liste onu
/// ancak kaydırınca kurar. Önce görünür alana kaydır, sonra doğrula/dokun.
Future<void> _scrollToLanguageRow(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200);
  await tester.ensureVisible(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('varsayılan dil Türkçe; dil satırı ve menü değeri görünür',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Teknem'), findsOneWidget);
    await _scrollToLanguageRow(tester, 'Dil');
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget); // menünün seçili değeri
  });

  testWidgets('menüden İngilizce seçilince ekran ANINDA İngilizceleşir',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _scrollToLanguageRow(tester, 'Türkçe');
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle(); // açılır menü
    expect(find.text('English'), findsWidgets);
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    // Dil satırı ve seçili değer artık İngilizce.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    // Yukarı kaydır: sayfanın üstü de İngilizceleşti (tembel liste yeniden kurar).
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('My Boat'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Teknem'), findsNothing);
  });

  testWidgets('Rusça override → profil Rusça açılır (otomatik algılama yolu)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(locale: AppLocale.ru));
    await tester.pumpAndSettle();
    expect(find.text('Моя лодка'), findsOneWidget);
    await _scrollToLanguageRow(tester, 'Язык');
    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
  });

  testWidgets('İspanyolca override → profil İspanyolca açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(locale: AppLocale.es));
    await tester.pumpAndSettle();
    expect(find.text('Mi barco'), findsOneWidget);
    await _scrollToLanguageRow(tester, 'Idioma');
    expect(find.text('Idioma'), findsOneWidget);
  });

  testWidgets('arama filtreleri seçili dilde: İspanyolca çipler ve ipucu',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          appLocaleProvider.overrideWith(() => AppLocaleController(AppLocale.es)),
          searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
          searchDebounceProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi barco cabe'), findsOneWidget); // Teknem sığar
    expect(find.text('Gratis'), findsOneWidget); // Ücretsiz
    expect(find.text('Combustible'), findsOneWidget); // Yakıt çipi
    expect(find.textContaining('al menos 2 letras'), findsOneWidget); // ipucu
  });

  testWidgets('arama filtreleri Rusça: tip çipi ve arama ipucu',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          appLocaleProvider.overrideWith(() => AppLocaleController(AppLocale.ru)),
          searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
          searchDebounceProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лодка поместится'), findsOneWidget);
    expect(find.text('Топливо'), findsOneWidget);
  });

  testWidgets('koy detayı İspanyolca: demirleme notları ve zemin çevrilir',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          appLocaleProvider.overrideWith(() => AppLocaleController(AppLocale.es)),
          locationDetailGatewayProvider
              .overrideWithValue(FakeLocationDetailGateway(result: sampleAnchorageDetail)),
          nearbyGatewayProvider.overrideWithValue(FakeNearbyGateway()),
          reviewsGatewayProvider.overrideWithValue(FakeReviewsGateway()),
          weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
        ],
        child: const MaterialApp(home: LocationDetailScreen(idOrSlug: 'loc-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Notas de fondeo'), 200);
    expect(find.text('Notas de fondeo'), findsOneWidget); // Demirleme Notları
    expect(find.text('Fondo: Fango'), findsOneWidget); // Zemin: Çamur
    expect(find.text('Punto de fondeo'), findsOneWidget); // Bağlama Noktası
  });

  testWidgets('acil durum İngilizce: başlıklar çevrilir, MAYDAY şablonu İngilizce',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
      communityGatewayProvider.overrideWithValue(FakeCommunityGateway()),
          appLocaleProvider.overrideWith(() => AppLocaleController(AppLocale.en)),
        ],
        child: const MaterialApp(home: EmergencyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Are you in distress?'), findsOneWidget);
    // MAYDAY kartı listenin aşağısında — önce görünür alana kaydır (CI dersi).
    await tester.scrollUntilVisible(
        find.text('MAYDAY call (life-threatening)'), 200);
    expect(find.textContaining('I REQUIRE IMMEDIATE ASSISTANCE'), findsOneWidget);
    expect(find.textContaining('YARDIM İSTİYORUM'), findsNothing); // TR şablon yok
  });
}
