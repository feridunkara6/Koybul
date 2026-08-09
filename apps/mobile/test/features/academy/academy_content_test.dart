import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/features/academy/data/academy_content.dart';
import 'package:dockly_mobile/features/academy/domain/guide.dart';
import 'package:flutter_test/flutter_test.dart';

/// AKADEMİ İÇERİĞİ testleri (v2.0 "Akademi lite"): dört dilde AYNI rehberler,
/// boş metin yok, dürüstlük kuralları korunuyor.
void main() {
  test('her dilde aynı 10 rehber, aynı sırada', () {
    final List<String> trIds =
        academyGuides(AppLocale.tr).map((Guide g) => g.id).toList();
    // kAcademyGuideCount elle tutulan sabittir — gerçek listeyle eşitliği
    // burada doğrulanır (rehber eklenip sabit unutulursa test kırılır).
    expect(trIds, hasLength(kAcademyGuideCount));
    expect(trIds.toSet(), hasLength(kAcademyGuideCount)); // kimlikler eşsiz
    for (final AppLocale l in AppLocale.values) {
      final List<Guide> guides = academyGuides(l);
      expect(guides.map((Guide g) => g.id).toList(), trIds, reason: '$l');
    }
  });

  test('hiçbir dilde boş başlık/özet/madde yok (0 uydurma: eksik içerik '
      'ekrana çizilmez)', () {
    for (final AppLocale l in AppLocale.values) {
      for (final Guide g in academyGuides(l)) {
        expect(g.title.trim(), isNotEmpty, reason: '$l ${g.id}');
        expect(g.summary.trim(), isNotEmpty, reason: '$l ${g.id}');
        expect(g.points.length, greaterThanOrEqualTo(4), reason: '$l ${g.id}');
        for (final String p in g.points) {
          expect(p.trim(), isNotEmpty, reason: '$l ${g.id}');
        }
        if (g.note != null) {
          expect(g.note!.trim(), isNotEmpty, reason: '$l ${g.id}');
        }
      }
    }
  });

  test('diller birbirinden farklı (çeviri unutulmamış)', () {
    for (final Guide tr in academyGuides(AppLocale.tr)) {
      final Guide en = academyGuideById(AppLocale.en, tr.id)!;
      final Guide es = academyGuideById(AppLocale.es, tr.id)!;
      final Guide ru = academyGuideById(AppLocale.ru, tr.id)!;
      expect(<String>{tr.title, en.title, es.title, ru.title}, hasLength(4),
          reason: tr.id);
    }
  });

  test('kimlikle tek rehber getirilir; bilinmeyen kimlik null döner', () {
    final Guide? anchor = academyGuideById(AppLocale.tr, 'anchor');
    expect(anchor, isNotNull);
    expect(anchor!.title, 'Demir atma');
    expect(academyGuideById(AppLocale.tr, 'yok-boyle-rehber'), isNull);
  });
}
