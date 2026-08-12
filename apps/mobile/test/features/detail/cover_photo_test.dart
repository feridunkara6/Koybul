import 'package:dockly_api/dockly_api.dart' show CoverMedia;
import 'package:dockly_mobile/features/detail/presentation/cover_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAPAK FOTOĞRAFI testleri (Faz 2). Fotoğraflar Wikimedia Commons'tan
/// geliyor; CC lisansı atıf İSTER. Buradaki sözleşme: atıf her zaman görünür,
/// kaynak sayfası varsa şerit dokunulabilirdir, ağ yokken ekran kırılmaz.
Widget _app(CoverMedia cover) => MaterialApp(
      home: Scaffold(body: CoverPhoto(cover: cover)),
    );

const CoverMedia _ccCover = CoverMedia(
  url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/x/xx/T.jpg/1280px-T.jpg',
  blurhash: null,
  credit: 'Ayşe Denizci',
  license: 'CC BY-SA 4.0',
  sourceUrl: 'https://commons.wikimedia.org/wiki/File:T.jpg',
);

void main() {
  testWidgets('atıf şeridi fotoğrafçıyı VE lisansı gösterir (CC şartı)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(_ccCover));
    await tester.pump();
    expect(find.text('Ayşe Denizci · CC BY-SA 4.0'), findsOneWidget);
  });

  testWidgets('kaynak sayfası varsa şerit dokunuşu Commons sayfasını açar '
      '(şeridin BOŞ kısmı dahil)', (WidgetTester tester) async {
    // url_launcher kanalını taklit et: gerçekten "launch" çağrısı gitti mi?
    final List<String> launched = <String>[];
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (MethodCall call) async {
        if (call.method == 'launch') {
          launched.add(call.arguments['url'] as String);
          return true;
        }
        return true; // canLaunch vb.
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'), null));

    await tester.pumpWidget(_app(_ccCover));
    await tester.pump();
    final Finder link = find.byKey(const ValueKey<String>('cover-credit-link'));
    expect(link, findsOneWidget);
    // Şeridin ORTASINA dokun — metnin sağındaki boş degrade alan. Varsayılan
    // hit-test davranışında burası ölüydü (inceleme bulgusu → opaque).
    await tester.tap(link);
    await tester.pump();
    expect(launched, hasLength(1));
    expect(launched.single, 'https://commons.wikimedia.org/wiki/File:T.jpg');
  });

  testWidgets('kaynak sayfası YOKSA şerit dokunulabilir değildir',
      (WidgetTester tester) async {
    const CoverMedia cover = CoverMedia(
      url: 'https://example.com/x.jpg',
      blurhash: null,
      credit: 'Ali Kaptan',
      license: null,
      sourceUrl: null,
    );
    await tester.pumpWidget(_app(cover));
    await tester.pump();
    expect(find.text('Ali Kaptan'), findsOneWidget); // lisanssız: yalnız ad
    expect(
        find.byKey(const ValueKey<String>('cover-credit-link')), findsNothing);
  });

  testWidgets('atıf yoksa kredi şeridi hiç çıkmaz', (WidgetTester tester) async {
    const CoverMedia cover = CoverMedia(
      url: 'https://example.com/x.jpg',
      blurhash: null,
      credit: null,
      license: null,
      sourceUrl: null,
    );
    await tester.pumpWidget(_app(cover));
    await tester.pump();
    expect(find.textContaining('·'), findsNothing);
    expect(
        find.byKey(const ValueKey<String>('cover-credit-link')), findsNothing);
  });

  testWidgets('görsel yüklenemezse zarif yer tutucu; atıf yine görünür',
      (WidgetTester tester) async {
    // Test ortamında Image.network HER ZAMAN başarısız olur (ağ yok) —
    // errorBuilder yolunu bedavaya sınar.
    await tester.pumpWidget(_app(_ccCover));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull); // hata yutuldu, ekran kırılmadı
    expect(find.text('Ayşe Denizci · CC BY-SA 4.0'), findsOneWidget);
  });
}
