import 'package:dockly_mobile/features/legal/presentation/legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yasal ekran testleri (Faz 0). Mağaza incelemesinin baktığı yol:
/// Profil → Gizlilik ve yasal metinler → belge → tam metin. Bu yolun her
/// adımı burada yürünüyor.
Widget _app() => const ProviderScope(child: MaterialApp(home: LegalScreen()));

void main() {
  testWidgets('üç belge listelenir ve son güncelleme tarihi görünür',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
    expect(find.text('Kullanım Koşulları'), findsOneWidget);
    // Yalnız önek aramak yetmez: '%s' gibi yanlış bir yer tutucu
    // kullanılsaydı önek yine eşleşir, tarih hiç basılmazdı (CI dersi).
    expect(find.text('Son güncelleme: 2026-08-11'), findsOneWidget);
  });

  testWidgets('belgeye dokununca tam metin açılır (çevrimdışı, ağ yok)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('legal-privacy')));
    await tester.pumpAndSettle();

    // Başlıkta ve gövdede metnin gerçekten olduğunu kanıtla.
    expect(find.text('Kısaca'), findsOneWidget);
    expect(find.textContaining('hesap açmadan kullanılabilir'), findsOneWidget);
  });

  testWidgets('kullanım koşulları SEYİR YAYINI OLMADIĞINI ekranda söyler',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('legal-terms')));
    await tester.pumpAndSettle();

    expect(find.textContaining('seyir yayını değildir'), findsOneWidget);
  });

  testWidgets('bilinmeyen belge kimliği boş ekran değil, dürüst satır gösterir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LegalDocScreen(docId: 'yok-boyle')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bu belge bulunamadı.'), findsOneWidget);
  });
}
