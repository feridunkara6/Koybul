import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:dockly_mobile/features/community/presentation/note_composer_screen.dart';
import 'package:dockly_mobile/features/location/application/location_controller.dart';
import 'package:dockly_mobile/features/weather/application/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';
import '../../support/location_fakes.dart';
import '../../support/weather_fakes.dart';

/// NOT BIRAKMA ekranı — "izin vermiyor" şikâyetinin iki sebebi:
///  1) Seyir notu seçiliyordu ama gönderilemiyordu (varış noktası yok).
///  2) Konum yokken uyarı/güncel durum seçilebiliyor, ancak GÖNDERDİKTEN
///     sonra reddediliyordu.
void main() {
  const GeoPoint koy = GeoPoint(lat: 36.62, lon: 29.12);

  Widget composer(FakeCommunityGateway gw, List<Override> extra) => ProviderScope(
        overrides: <Override>[
          communityGatewayProvider.overrideWithValue(gw),
          weatherGatewayProvider.overrideWithValue(FakeWeatherGateway()),
          ...extra,
        ],
        child: const MaterialApp(
          home: NoteComposerScreen(
            locationId: 'loc-1',
            locationName: 'Boynuzbükü',
            position: koy,
          ),
        ),
      );

  testWidgets('SEYİR NOTU seçeneği GÖSTERİLMEZ — gönderilemiyordu',
      (WidgetTester tester) async {
    await tester.pumpWidget(composer(FakeCommunityGateway(), <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('note-kind-passage')), findsNothing);
    expect(find.byKey(const ValueKey<String>('note-kind-experience')), findsOneWidget);
    expect(kComposerKinds.contains(NoteKind.passage), isFalse);
  });

  testWidgets('KONUM YOKKEN uyarı tipi seçilemez ve sebebi yazar',
      (WidgetTester tester) async {
    await tester.pumpWidget(composer(FakeCommunityGateway(), <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('gerçek konumunu ister'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note-locate')), findsOneWidget);

    // Uyarıya dokunmak tipi DEĞİŞTİRMEZ (kilitli). Kanıt: karakter sayacı
    // "Deneyim" sınırında (4000) kalır; uyarı seçilseydi 500 olurdu.
    expect(find.text('0/4000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('note-kind-hazard')));
    await tester.pumpAndSettle();
    expect(find.text('0/4000'), findsOneWidget);
    expect(find.text('0/500'), findsNothing);
  });

  testWidgets('KONUM ALININCA uyarı tipi açılır ve not gönderilir',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway();
    await tester.pumpWidget(composer(gw, <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(koy)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('note-locate')));
    await tester.pumpAndSettle();

    // Kilit açıldı: artık uyarı seçilebiliyor.
    await tester.tap(find.byKey(const ValueKey<String>('note-kind-hazard')));
    await tester.pumpAndSettle();
    expect(find.text('Konumun doğrulandı'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey<String>('note-body')), 'Batı girişinde yüzer ağ var.');
    await tester.pumpAndSettle();
    // Düğme listenin altında kalıyor: görünür yapılmadan yapılan dokunuş
    // ıskalar ve test sessizce yanlış sebeple düşerdi.
    await tester.ensureVisible(find.byKey(const ValueKey<String>('note-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('note-submit')));
    await tester.pumpAndSettle();

    expect(gw.created, hasLength(1));
    expect(gw.created.first.kind, NoteKind.hazard);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('konum yokken DENEYİM notu sorunsuz gönderilir',
      (WidgetTester tester) async {
    final FakeCommunityGateway gw = FakeCommunityGateway();
    await tester.pumpWidget(composer(gw, <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('note-body')), 'Kuzey ucunda kum, tutuş iyi.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('note-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('note-submit')));
    await tester.pumpAndSettle();

    expect(gw.created, hasLength(1));
    expect(gw.created.first.kind, NoteKind.experience);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('konum reddedilirse dürüst açıklama çıkar, ekran kapanmaz',
      (WidgetTester tester) async {
    await tester.pumpWidget(composer(FakeCommunityGateway(), <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('note-locate')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Konum alınamadı'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note-body')), findsOneWidget);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
