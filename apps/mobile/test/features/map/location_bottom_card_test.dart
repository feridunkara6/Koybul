import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/boat/domain/my_boat.dart';
import 'package:dockly_mobile/features/map/presentation/location_bottom_card.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/map_fakes.dart';

/// İkonlar artık SVG tabanlı [DocklyIcon]; ikon verisiyle bulunur.
Finder _docklyIcon(DocklyIconData d) =>
    find.byWidgetPredicate((Widget w) => w is DocklyIcon && w.data == d);

/// Dil paketi: LocationBottomCard artık ConsumerWidget → ProviderScope şart.
Widget _wrap(Widget card) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: card)));

void main() {
  testWidgets('DAR EKRAN + iki buton: taşma HATASI olmaz, etiketler bulunur (CI dersi)',
      (WidgetTester tester) async {
    // dockly_button _Label taşma emniyeti: test yazı tipi geniştir; 'Deniz
    // rotası' dar butonda taşarsa RenderFlex hatası testleri kırıyordu.
    await tester.pumpWidget(_wrap(SizedBox(
      width: 340,
      child: LocationBottomCard(
        pin: testPin,
        onClose: () {},
        onOpenDetail: () {},
        onRoute: () {},
      ),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull); // taşma istisnası YOK
    expect(find.text('Detay'), findsOneWidget);
    expect(find.text('Deniz rotası'), findsOneWidget);
  });

  testWidgets('kart: tip etiketi + ad + puan + fiyat rozeti gösterir', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(LocationBottomCard(pin: testPin, onClose: () {})),
    );
    expect(find.byKey(LocationBottomCard.cardKey), findsOneWidget);
    expect(find.text('Özel Marina'), findsOneWidget); // private_marina etiketi
    expect(find.text('D-Marin Göcek'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Ücretli'), findsOneWidget); // paid rozeti
  });

  testWidgets('puanı olmayan pin → "Puan yok"', (WidgetTester tester) async {
    const noRating = LocationPin(
      id: 'x',
      name: 'İsimsiz Koy',
      type: 'mooring_point',
      position: GeoPoint(lat: 36.0, lon: 28.0),
      ratingAvg: null,
      priceTier: 'unknown',
    );
    await tester.pumpWidget(
      _wrap(LocationBottomCard(pin: noRating, onClose: () {})),
    );
    expect(find.text('Puan yok'), findsOneWidget);
    expect(find.text('Bağlama Noktası'), findsOneWidget);
    // unknown fiyat → rozet gösterilmez
    expect(find.text('Ücretli'), findsNothing);
    expect(find.text('Ücretsiz'), findsNothing);
  });

  testWidgets('kapat düğmesi onClose çağırır', (WidgetTester tester) async {
    bool closed = false;
    await tester.pumpWidget(
      _wrap(LocationBottomCard(pin: testPin, onClose: () => closed = true)),
    );
    await tester.tap(_docklyIcon(DocklyIcons.close));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('onOpenDetail verilince "Detay" butonu görünür ve çağırır', (WidgetTester tester) async {
    bool opened = false;
    await tester.pumpWidget(
      _wrap(LocationBottomCard(
        pin: testPin,
        onClose: () {},
        onOpenDetail: () => opened = true,
      )),
    );
    expect(find.text('Detay'), findsOneWidget);
    await tester.tap(find.text('Detay'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('onOpenDetail yoksa "Detay" butonu gösterilmez', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(LocationBottomCard(pin: testPin, onClose: () {})),
    );
    expect(find.text('Detay'), findsNothing);
  });

  testWidgets('fit verilince uyum rozeti gösterilir; unknown/verilmezse gösterilmez',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(LocationBottomCard(pin: testPin, onClose: () {}, fit: BoatFit.fits)),
    );
    expect(find.text('Teknen sığar'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(LocationBottomCard(pin: testPin, onClose: () {}, fit: BoatFit.unknown)),
    );
    expect(find.text('Teknen sığar'), findsNothing);
    expect(find.text('Uygunluk bilinmiyor'), findsNothing);
  });

  testWidgets('ROTA DÜZENLEME: onAddStop verilince "Durak ekle" görünür ve çağırır',
      (WidgetTester tester) async {
    bool added = false;
    await tester.pumpWidget(_wrap(SizedBox(
      width: 340, // dar ekran taşma emniyeti bu düğme için de denetlenir
      child: LocationBottomCard(
        pin: testPin,
        onClose: () {},
        onOpenDetail: () {},
        onAddStop: () => added = true, // rota çizili → rota düğmesi YOK
      ),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Durak ekle'), findsOneWidget);
    expect(find.text('Deniz rotası'), findsNothing);
    await tester.tap(find.text('Durak ekle'));
    await tester.pump();
    expect(added, isTrue);
  });

  testWidgets('doluluk rozeti: pin özet taşıyorsa tip etiketinin yanında görünür',
      (WidgetTester tester) async {
    final LocationPin occPin = LocationPin(
      id: 'akvaryum',
      name: 'Akvaryum Koyu (Adaboğazı)',
      type: 'mooring_point',
      position: const GeoPoint(lat: 37.0, lon: 27.38),
      ratingAvg: null,
      priceTier: 'free',
      occupancy: OccupancySummary(
        level: 'full',
        reportedAt: DateTime(2026, 7, 15, 10),
        reportCount: 2,
      ),
    );
    await tester.pumpWidget(_wrap(LocationBottomCard(pin: occPin, onClose: () {})));
    expect(find.text('Dolu'), findsOneWidget); // kompakt rozet (salt gösterim)
    expect(find.text('Doluluk bildir'), findsNothing); // bildirme YALNIZ detayda
  });
}
