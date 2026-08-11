import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/core/origin_provider.dart';
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

  /// Form üç adımlı ve ~760 px. Varsayılan 800x600 test yüzeyinde görünür
  /// alan 544 px kalır; "Gönder" düğmesi ve GPS satırı bunun ALTINDA kalır.
  /// Sliver o çocukları önbellek bölgesinde KURAR, ama onları "offstage"
  /// işaretler (SliverMultiBoxAdaptorElement.debugVisitOnstageChildren:
  /// ölçüt boyama alanıdır, önbellek alanı değil). `find.*` varsayılan
  /// `skipOffstage: true` ile çalıştığı için widget'ı GÖRMEZ; CI'daki
  /// "Found 0 widgets" ve `ensureVisible` → "Bad state: No element"
  /// hatalarının ikisi de budur (2026-08). Yüzeyi büyütmek hepsini boyama
  /// alanına sokar. NOT: `cacheExtent` büyütmek bu sorunu ÇÖZMEZ.
  ///
  /// DEGISMEZ KURAL: form bu yuzeye SIGMALI (bugun ~760 / 2344 px — uc kat
  /// pay). Buraya kaydirma yardimcisi KOYMAYIN; ikisi de denendi, ikisi de
  /// CI'yi kirdi: `ensureVisible` sahne disi widget'ta "No element" atar;
  /// `scrollUntilVisible` ise varsayilan `find.byType(Scrollable)` adayini
  /// `Iterable.single` ile tekillestirdigi icin "Too many elements" atar —
  /// agacta ListView'in yani sira cok satirli TextField'in kendi kaydiricisi
  /// da vardir. Form bir gun tasarsa dogru duzeltme asagidaki 2400'u
  /// buyutmektir.
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

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
    tallSurface(tester);
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
    tallSurface(tester);
    await tester.pumpWidget(composer(FakeCommunityGateway(), <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('gerçek konumunu ister'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note-locate')), findsOneWidget);

    // Uyarıya dokunmak tipi DEĞİŞTİRMEZ (kilitli). Kanıt: karakter sayacı
    // "Deneyim" sınırında (4000) kalır; uyarı seçilseydi 500 olurdu.
    expect(find.text('0/4000'), findsOneWidget);
    // Kilit DOĞRUDAN de kanıtlanır: aşağıdaki "sayaç değişmedi" iddiası,
    // dokunuş alakasız bir sebeple ıskalasaydı da geçerdi.
    expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey<String>('note-kind-hazard')))
            .onTap,
        isNull);
    await tester.tap(find.byKey(const ValueKey<String>('note-kind-hazard')));
    await tester.pumpAndSettle();
    expect(find.text('0/4000'), findsOneWidget);
    expect(find.text('0/500'), findsNothing);
  });

  testWidgets('KONUM SAĞLAYICIDAN GELİRSE uyarı tipi açılır ve not gönderilir',
      (WidgetTester tester) async {
    tallSurface(tester);
    final FakeCommunityGateway gw = FakeCommunityGateway();
    await tester.pumpWidget(composer(gw, <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(koy)),
      // Konum ZATEN varmış gibi: kilidin konuma bağlı olduğunu kanıtlar.
      devicePositionProvider.overrideWith((ref) => koy),
    ]));
    await tester.pumpAndSettle();

    // Konum varken davet satırı hiç çıkmaz.
    expect(find.byKey(const ValueKey<String>('note-locate')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('note-kind-hazard')));
    await tester.pumpAndSettle();
    expect(find.text('Konumun doğrulandı'), findsOneWidget);
    expect(find.text('0/500'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey<String>('note-body')), 'Batı girişinde yüzer ağ var.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('note-submit')));
    await tester.pumpAndSettle();

    expect(gw.created, hasLength(1));
    expect(gw.created.first.kind, NoteKind.hazard);
    // Gönderim yolunun YAN ETKİSİ: ekran kapanır. Bu yol CI'da bugüne dek hiç
    // koşmadı — ölçmeden geçmiş sayılmaz. Moderasyon bildirimi BURADA
    // aranmaz: `_submit` önce pop eder, SnackBar'ı çizecek Scaffold da
    // onunla birlikte gider; bu ekran testin tek rotası olduğu için bildirim
    // hiç boyanmaz (kayıp değil — gerçek uygulamada altta bir rota kalır).
    expect(find.byKey(const ValueKey<String>('note-body')), findsNothing);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('"Konumumu kullan" izni ister ve davet satırı kaybolur',
      (WidgetTester tester) async {
    tallSurface(tester);
    final FakeLocationService svc = FakeLocationService(koy);
    await tester.pumpWidget(composer(FakeCommunityGateway(), <Override>[
      locationServiceProvider.overrideWithValue(svc),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('note-locate')));
    await tester.pumpAndSettle();

    // Konum servisine gerçekten gidildi ve davet satırı kayboldu.
    expect(svc.calls, 1);
    expect(find.byKey(const ValueKey<String>('note-locate')), findsNothing);
    expect(find.textContaining('gerçek konumunu ister'), findsNothing);

    // UÇTAN UCA: kilit gerçekten açıldı mı? Uyarı seçilebiliyorsa karakter
    // sınırı 500'e düşer. Bu satır olmadan test yalnız "banner kayboldu"
    // derdi; asıl vaat olan "artık uyarı yazabilirsin" ölçülmemiş olurdu.
    await tester.tap(find.byKey(const ValueKey<String>('note-kind-hazard')));
    await tester.pumpAndSettle();
    expect(find.text('0/500'), findsOneWidget);
    expect(find.text('Konumun doğrulandı'), findsOneWidget);
  });

  testWidgets('konum yokken DENEYİM notu sorunsuz gönderilir',
      (WidgetTester tester) async {
    tallSurface(tester);
    final FakeCommunityGateway gw = FakeCommunityGateway();
    await tester.pumpWidget(composer(gw, <Override>[
      locationServiceProvider.overrideWithValue(FakeLocationService(null)),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('note-body')), 'Kuzey ucunda kum, tutuş iyi.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('note-submit')));
    await tester.pumpAndSettle();

    expect(gw.created, hasLength(1));
    expect(gw.created.first.kind, NoteKind.experience);
    expect(find.byKey(const ValueKey<String>('note-body')), findsNothing);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('konum reddedilirse dürüst açıklama çıkar, ekran kapanmaz',
      (WidgetTester tester) async {
    tallSurface(tester);
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
