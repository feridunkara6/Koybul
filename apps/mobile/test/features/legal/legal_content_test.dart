import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/features/legal/data/legal_content.dart';
import 'package:dockly_mobile/features/legal/domain/legal_doc.dart';
import 'package:flutter_test/flutter_test.dart';

/// YASAL METİN testleri (Faz 0 — mağaza ve KVKK şartı).
///
/// Bu testler biçimsel değil: yayın engelini gerçekten kapattığımızı
/// doğruluyorlar. Boş bir bölüm ya da eksik bir belge, "gizlilik metni var"
/// demenin yanlış olması demektir.
void main() {
  test('her dilde AYNI üç belge, aynı sırada', () {
    final List<String> trIds =
        legalDocs(AppLocale.tr).map((LegalDoc d) => d.id).toList();
    expect(trIds, <String>['privacy', 'kvkk', 'terms']);
    expect(trIds, hasLength(kLegalDocCount));
    for (final AppLocale l in AppLocale.values) {
      expect(legalDocs(l).map((LegalDoc d) => d.id).toList(), trIds, reason: '$l');
    }
  });

  test('hiçbir dilde boş başlık, boş bölüm ya da boş paragraf yok', () {
    for (final AppLocale l in AppLocale.values) {
      for (final LegalDoc d in legalDocs(l)) {
        expect(d.title.trim(), isNotEmpty, reason: '$l ${d.id}');
        expect(d.summary.trim(), isNotEmpty, reason: '$l ${d.id}');
        expect(d.updated.trim(), isNotEmpty, reason: '$l ${d.id}');
        expect(d.sections.length, greaterThanOrEqualTo(5), reason: '$l ${d.id}');
        for (final LegalSection s in d.sections) {
          expect(s.heading.trim(), isNotEmpty, reason: '$l ${d.id}');
          expect(s.paragraphs, isNotEmpty, reason: '$l ${d.id} ${s.heading}');
          for (final String p in s.paragraphs) {
            expect(p.trim(), isNotEmpty, reason: '$l ${d.id} ${s.heading}');
          }
        }
      }
    }
  });

  test('İspanyolca ve Rusça İNGİLİZCE metne düşer (bilinçli karar)', () {
    // Yasal metinde yaklaşık çeviri, çeviri olmamasından risklidir. Bu test
    // kararın bilinçli olduğunu belgeler: biri bir gün es/ru çeviri eklerse
    // test kırılır ve karar yeniden gözden geçirilir.
    for (final AppLocale l in <AppLocale>[AppLocale.es, AppLocale.ru]) {
      final List<LegalDoc> docs = legalDocs(l);
      final List<LegalDoc> en = legalDocs(AppLocale.en);
      for (int i = 0; i < docs.length; i++) {
        expect(docs[i].title, en[i].title, reason: '$l');
      }
    }
  });

  test('Türkçe metin İngilizceden farklıdır (gerçekten yazılmış)', () {
    for (final LegalDoc tr in legalDocs(AppLocale.tr)) {
      final LegalDoc? en = legalDocById(AppLocale.en, tr.id);
      expect(en, isNotNull, reason: tr.id);
      expect(tr.title, isNot(en!.title), reason: tr.id);
    }
  });

  test('KVKK metni kanunun istediği asgari unsurları içerir', () {
    final LegalDoc kvkk = legalDocById(AppLocale.tr, 'kvkk')!;
    final String all = kvkk.sections
        .expand((LegalSection s) => <String>[s.heading, ...s.paragraphs])
        .join(' ');
    // Veri sorumlusunun kimliği, başvuru yolu ve 11. madde hakları
    // aydınlatma metninin zorunlu unsurlarıdır.
    //
    // LİTERAL aranır, sabit DEĞİL: sabitin kendisiyle karşılaştırmak
    // totolojidir — metinden başvuru bölümü tamamen silinse bile geçerdi
    // (inceleme bulgusu). Aşağıdaki dizgiler metnin içinde gerçekten
    // bulunmalı.
    expect(all, contains('destek@koybul.com'));
    expect(all, contains('veri sorumlusu'));
    expect(all, contains('6698'));
    expect(all, contains('11. maddesindeki'));
    expect(all, contains('otuz gün'));
    // Sabitler metne gerçekten AKIYOR mu (interpolasyon bozulmasın).
    expect(all, contains(kLegalEntity));
    expect(all, contains(kLegalAddress));
  });

  test('kullanım koşulları SEYİR YAYINI OLMADIĞINI açıkça söyler', () {
    // Bu cümle hukuki sorumluluk açısından metnin en önemli parçası; sessizce
    // silinirse test kırılsın.
    final LegalDoc terms = legalDocById(AppLocale.tr, 'terms')!;
    final String all = terms.sections
        .expand((LegalSection s) => <String>[s.heading, ...s.paragraphs])
        .join(' ');
    expect(all, contains('seyir yayını'));
    expect(all.toLowerCase(), contains('sorumlu'));
  });

  test('gizlilik metni cihazda kalan verileri sayar (yanlış vaat yok)', () {
    // Uygulama tekne/defter/favori verisini SUNUCUYA GÖNDERMİYOR. Metin bunu
    // söylüyorsa doğru; bir gün sunucuya taşınırsa bu test hatırlatır.
    final LegalDoc privacy = legalDocById(AppLocale.tr, 'privacy')!;
    final String all = privacy.sections
        .expand((LegalSection s) => <String>[s.heading, ...s.paragraphs])
        .join(' ');
    expect(all, contains('telefonunda durur'));
    expect(all, contains('bize hiç gönderilmez'));
    expect(all, contains('Hesabımı sil'));
  });

  test('bilinmeyen kimlik null döner', () {
    expect(legalDocById(AppLocale.tr, 'yok-boyle-belge'), isNull);
  });
}
