import 'package:dockly_api/dockly_api.dart'
    show QaAnswer, QaCreateResult, QaDetail, QaFeed, QaQuestionSummary;
import 'package:dockly_mobile/features/qa/application/qa_controller.dart';
import 'package:dockly_mobile/features/qa/domain/qa_gateway.dart';
import 'package:dockly_mobile/features/qa/presentation/qa_composer_screen.dart';
import 'package:dockly_mobile/features/qa/presentation/qa_detail_screen.dart';
import 'package:dockly_mobile/features/qa/presentation/qa_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// SORU-CEVAP ekran testleri (Blog V1 — kurucu onayı 2026-10-23).
/// Kural (docs/15): ağ yok, gerçek depo yok — ağ geçidi sahtedir; erişim
/// kararları sahte sunucu yanıtlarıyla taklit edilir.

QaQuestionSummary summary({
  String id = 'q1',
  bool featured = false,
  bool authorPremium = true,
  int answersCount = 7,
}) {
  return QaQuestionSummary(
    id: id,
    category: 'demirleme',
    title: 'Poyrazda hangi yakaya demir atmalı?',
    preview: 'Hafta sonu Boynuz planı var, poyraz 15-20 kn görünüyor…',
    authorName: 'Kaptan M.',
    authorPremium: authorPremium,
    featured: featured,
    likeCount: 12,
    answersCount: answersCount,
    createdAt: DateTime.utc(2026, 10, 22, 9),
  );
}

QaAnswer answer({String id = 'a1', bool mine = false, String status = 'approved'}) {
  return QaAnswer(
    id: id,
    body: 'Kuzey yaka nefes alır; kıçtan karaya güney cebi daha rahat.',
    status: status,
    authorName: 'Kaptan H.',
    authorPremium: false,
    helpfulCount: 9,
    mine: mine,
    helpedByMe: false,
    createdAt: DateTime.utc(2026, 10, 22, 10),
  );
}

class FakeQaGateway implements QaGateway {
  FakeQaGateway({required this.feedResult, this.detailResult});

  QaFeed feedResult;
  QaDetail? detailResult;
  QaCreateResult createResult = const QaCreateResult(id: 'new', status: 'pending');

  String? createdCategory;
  String? createdTitle;
  String? createdBody;
  String? answeredQuestionId;
  String? answeredBody;
  final List<String> reports = <String>[];

  @override
  Future<QaFeed> feed({String? category}) async => feedResult;

  @override
  Future<QaDetail> detail(String questionId) async => detailResult!;

  @override
  Future<QaCreateResult> createQuestion({
    required String category,
    required String title,
    required String body,
  }) async {
    createdCategory = category;
    createdTitle = title;
    createdBody = body;
    return createResult;
  }

  @override
  Future<QaCreateResult> createAnswer({
    required String questionId,
    required String body,
  }) async {
    answeredQuestionId = questionId;
    answeredBody = body;
    return createResult;
  }

  @override
  Future<({bool liked, int likeCount})> toggleLike(String questionId) async =>
      (liked: true, likeCount: 13);

  @override
  Future<({bool helped, int helpfulCount})> toggleHelpful(String answerId) async =>
      (helped: true, helpfulCount: 10);

  @override
  Future<void> report({required String entity, required String id}) async {
    reports.add('$entity:$id');
  }
}

/// Kök rotayı koruyan başlatıcı: ekran itilerek açılır, pop güvenli olur.
class _Launcher extends StatelessWidget {
  const _Launcher(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => child),
          ),
          child: const Text('aç'),
        ),
      ),
    );
  }
}

Widget _app(FakeQaGateway gw, Widget home) {
  return ProviderScope(
    overrides: <Override>[qaGatewayProvider.overrideWithValue(gw)],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('liste: öne çıkan şeridi + akış + premium rozeti çizilir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeQaGateway gw = FakeQaGateway(
      feedResult: QaFeed(
        featured: <QaQuestionSummary>[summary(id: 'q-feat', featured: true)],
        items: <QaQuestionSummary>[summary(id: 'q-old', authorPremium: false)],
      ),
    );
    await tester.pumpWidget(_app(gw, const QaListScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('qa-item-q-feat')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('qa-item-q-old')), findsOneWidget);
    expect(find.text('⭑ PREMIUM'), findsOneWidget); // yalnız premium yazarda
    expect(find.byKey(const ValueKey<String>('qa-ask-fab')), findsOneWidget);
    expect(find.textContaining('ÖNE ÇIKAN'), findsOneWidget);
  });

  testWidgets('liste: boş akışta davet metni görünür', (WidgetTester tester) async {
    final FakeQaGateway gw = FakeQaGateway(
      feedResult: const QaFeed(
          featured: <QaQuestionSummary>[], items: <QaQuestionSummary>[]),
    );
    await tester.pumpWidget(_app(gw, const QaListScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('ilk soruyu sen sor'), findsOneWidget);
  });

  testWidgets('detay (vitrin): kilit kartı var, gövde ve cevap kutusu YOK',
      (WidgetTester tester) async {
    final FakeQaGateway gw = FakeQaGateway(
      feedResult: const QaFeed(
          featured: <QaQuestionSummary>[], items: <QaQuestionSummary>[]),
      detailResult: QaDetail(
        access: 'teaser',
        question: summary(),
        answersCount: 7,
      ),
    );
    await tester.pumpWidget(_app(gw, const QaDetailScreen(questionId: 'q1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('qa-lock')), findsOneWidget);
    expect(find.textContaining('7 denizci'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('qa-answer-field')), findsNothing);
    expect(find.text("Premium'a geç"), findsOneWidget);
  });

  testWidgets('detay (tam): cevaplar listelenir, cevap gönderimi geçide ulaşır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeQaGateway gw = FakeQaGateway(
      feedResult: const QaFeed(
          featured: <QaQuestionSummary>[], items: <QaQuestionSummary>[]),
      detailResult: QaDetail(
        access: 'full',
        question: summary(),
        answersCount: 1,
        body: 'Sorunun tam gövdesi — yalnız tam erişimde iner.',
        answers: <QaAnswer>[answer()],
      ),
    );
    await tester.pumpWidget(_app(gw, const QaDetailScreen(questionId: 'q1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('tam gövdesi'), findsOneWidget);
    expect(find.textContaining('Kuzey yaka nefes alır'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('qa-lock')), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey<String>('qa-answer-field')),
        'Ben de geçen hafta oradaydım, tek demir yetmedi.');
    await tester.tap(find.byKey(const ValueKey<String>('qa-answer-send')));
    await tester.pumpAndSettle();

    expect(gw.answeredQuestionId, 'q1');
    expect(gw.answeredBody, contains('tek demir yetmedi'));
    // Karma moderasyon dürüstlüğü: ilk içerik denetimde mesajı görünür.
    expect(find.textContaining('denetime alındı'), findsOneWidget);
  });

  testWidgets('soru oluşturma: kısa başlık geçmez; geçerli soru geçide ulaşır',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeQaGateway gw = FakeQaGateway(
      feedResult: const QaFeed(
          featured: <QaQuestionSummary>[], items: <QaQuestionSummary>[]),
    );
    // Başarılı gönderim sayfayı KAPATIR — kök rota kapanmasın diye ekran bir
    // başlatıcı üzerinden itilir (Navigator.pop güvenliği).
    await tester.pumpWidget(_app(gw, const _Launcher(QaComposerScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    // 1) Kısa başlık: istemci doğrulaması durdurur, geçit çağrılmaz.
    await tester.enterText(
        find.byKey(const ValueKey<String>('qa-title')), 'Kısa');
    await tester.enterText(find.byKey(const ValueKey<String>('qa-body')),
        'Yeterince uzun bir detay metni yazıyorum, otuz karakteri geçsin.');
    await tester.tap(find.byKey(const ValueKey<String>('qa-submit')));
    await tester.pumpAndSettle();
    expect(gw.createdTitle, isNull);
    expect(find.textContaining('10-140'), findsOneWidget);

    // 2) Geçerli soru: kategori + başlık + detay geçide gider, sayfa kapanır.
    await tester.tap(find.byKey(const ValueKey<String>('qa-cat-ekipman')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey<String>('qa-title')),
        '10 metre yelkenliye kaç kg çapa almalı?');
    await tester.tap(find.byKey(const ValueKey<String>('qa-submit')));
    await tester.pumpAndSettle();

    expect(gw.createdCategory, 'ekipman');
    expect(gw.createdTitle, contains('çapa'));
    expect(gw.createdBody, contains('otuz karakteri'));
  });
}
