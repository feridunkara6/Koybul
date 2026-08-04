import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/reviews/application/reviews_controller.dart';
import 'package:dockly_mobile/features/reviews/presentation/reviews_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/reviews_fakes.dart';

Widget _app(FakeReviewsGateway gateway) {
  return ProviderScope(
    overrides: <Override>[reviewsGatewayProvider.overrideWithValue(gateway)],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ReviewsSection(idOrSlug: 'loc-1')),
      ),
    ),
  );
}

void main() {
  testWidgets('yorumlar listelenir (başlık + yazar + metin)', (WidgetTester tester) async {
    final FakeReviewsGateway gateway = FakeReviewsGateway(
      results: <Review>[
        sampleReview('rev-1', authorName: 'Kaptan Ali', title: 'Harika yer', body: 'Personel iyi.'),
      ],
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Yorumlar'), findsOneWidget);
    expect(find.text('Kaptan Ali'), findsOneWidget);
    expect(find.text('Harika yer'), findsOneWidget);
    expect(find.text('Personel iyi.'), findsOneWidget);
  });

  testWidgets('yorum yoksa DOST boş durum gösterilir (UX 2026-08)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeReviewsGateway()));
    await tester.pumpAndSettle();
    expect(find.text('Yorumlar'), findsOneWidget);
    expect(find.text('Henüz yorum yok — ilk yorumu sen yazabilirsin.'), findsOneWidget);
  });

  testWidgets('hata olsa da bölüm gizlenir (misafiri rahatsız etmez)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeReviewsGateway(error: const NetworkFailure())));
    await tester.pumpAndSettle();
    expect(find.text('Yorumlar'), findsNothing);
  });
}
