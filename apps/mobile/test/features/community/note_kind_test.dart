import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/core/l10n/l10n_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sunucu kodu ↔ tip eşlemesi', () {
    expect(NoteKind.fromWire('status'), NoteKind.status);
    expect(NoteKind.fromWire('hazard'), NoteKind.hazard);
    expect(NoteKind.fromWire('passage'), NoteKind.passage);
    expect(NoteKind.fromWire('experience'), NoteKind.experience);
    // Bilinmeyen kod uygulamayı ÇÖKERTMEZ: en zararsız tipe düşer.
    expect(NoteKind.fromWire('bilinmeyen'), NoteKind.experience);
    for (final NoteKind k in NoteKind.values) {
      expect(NoteKind.fromWire(k.wire), k);
    }
  });

  test('4 dilde de her not tipinin ve her seviyenin etiketi var', () {
    for (final AppLocale loc in AppLocale.values) {
      final L10n t = l10nOf(loc);
      for (final NoteKind k in NoteKind.values) {
        expect(t.noteKindLabel(k.wire), isNotEmpty, reason: '${loc.name}/${k.wire}');
      }
      for (final String lvl in <String>['new', 'coastal', 'guide', 'master', 'pilot']) {
        expect(t.levelLabel(lvl), isNotEmpty, reason: '${loc.name}/$lvl');
      }
      // Bilinmeyen seviye kodu boş bırakmaz.
      expect(t.levelLabel('yok'), t.levelNew);
    }
  });

  test('Note.fromJson eksik alanlara dayanıklıdır', () {
    final Note n = Note.fromJson(<String, dynamic>{
      'id': 'x',
      'kind': 'status',
      'body': 'gövde',
      'observedOn': '2026-08-01',
      'createdAt': '2026-08-01T00:00:00.000Z',
      'author': <String, dynamic>{'userId': 'u', 'displayName': 'Kaptan'},
    });
    expect(n.helpfulCount, 0);
    expect(n.gpsVerified, isFalse);
    expect(n.wind, isNull);
    expect(n.author.levelCode, 'new');
    expect(n.status, isNull);
  });

  test('rüzgâr özeti gidiş-dönüş korunur', () {
    const NoteWind w = NoteWind(kn: 18, dirTr: 'KB');
    final NoteWind back = NoteWind.fromJson(w.toJson());
    expect(back.kn, 18);
    expect(back.dirTr, 'KB');
  });
}
