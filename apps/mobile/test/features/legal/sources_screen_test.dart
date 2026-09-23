import 'package:dockly_mobile/features/legal/data/photo_credits.dart';
import 'package:dockly_mobile/features/legal/presentation/sources_screen.dart';
import 'package:dockly_mobile/features/premium/data/premium_offline_cache.dart';
import 'package:dockly_mobile/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/premium_fakes.dart';

/// KAYNAKLAR VE LİSANSLAR (FAZ 0 K4). Lisans/mağaza denetiminin baktığı yol:
/// Profil → Kaynaklar ve lisanslar → harita/hava/veri kartları + fotoğraf
/// atıf listesi. Bu yolun her adımı burada yürünüyor.
Widget _app() =>
    const ProviderScope(child: MaterialApp(home: SourcesScreen()));

void main() {
  test('VERİ DİSİPLİNİ: her fotoğraf atfında credit dolu ve kaynak https', () {
    // Liste JSON'dan üretilir; bu test üretimin bozulmasını (boş atıf,
    // bağlantısız kaynak) CI'da yakalar. Sabit sayı BİLEREK yok: yeni
    // fotoğraf partisi eklenince test kırılmamalı.
    expect(kPhotoCredits.length, greaterThan(100));
    for (final PhotoCredit c in kPhotoCredits) {
      expect(c.credit, isNotEmpty);
      expect(c.place, isNotEmpty);
      expect(c.sourceUrl, startsWith('https://'));
    }
  });

  testWidgets('ekran üç kaynak kartını ve fotoğraf sayısını gösterir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Kaynaklar ve Lisanslar'), findsOneWidget);
    // Üç kaynak kartı gövdeleriyle ekranda (atıf zorunlulukları).
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('MET Norway'), findsOneWidget);
    expect(find.textContaining('DERİA'), findsWidgets);
    // Fotoğraf sayısı l10n şablonuna GERÇEKTEN basılmış ({0} kalmamış).
    expect(
      find.textContaining('${kPhotoCredits.length} kapak fotoğrafının'),
      findsOneWidget,
    );
    expect(find.textContaining('{0}'), findsNothing);
    // Listenin ilk satırı görünür: yer adı + atıf metni birlikte.
    final PhotoCredit first = kPhotoCredits.first;
    expect(find.text(first.place), findsOneWidget);
  });

  testWidgets('PROFİL YOLU: "Kaynaklar ve lisanslar" satırı ekranı açar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Kaptan Kartı başlığı premium rozetini izler (2026-09-23); depo
        // kuralı (docs/15): gerçek SharedPreferences testte asla.
        overrides: <Override>[
          premiumOfflineStoreProvider
              .overrideWithValue(FakePremiumOfflineStore()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kaynaklar ve lisanslar'), findsOneWidget);
    await tester.tap(find.text('Kaynaklar ve lisanslar'));
    await tester.pumpAndSettle();

    expect(find.byType(SourcesScreen), findsOneWidget);
    expect(find.text('Kaynaklar ve Lisanslar'), findsOneWidget);
  });
}
