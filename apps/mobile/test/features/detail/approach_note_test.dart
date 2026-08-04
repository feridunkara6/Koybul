import 'package:dockly_mobile/features/detail/domain/approach_note.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yaklaşma notu ayrıştırıcısı — seed sözleşmesi (taban + "\n\n" + önek + not)
/// birebir test edilir (0-uydurma: metin aynen taşınır, içerik üretilmez).
void main() {
  test('TR önekli not ayrılır; taban metin öneksiz kalır', () {
    const String d = 'Çam ormanlı korunaklı koy.\n\n'
        'Yaklaşma notu: Girişte batı burnunda resif var; son yaklaşmayı resmî haritayla planlayın.';
    final ApproachNoteSplit s = splitApproachNote(d);
    expect(s.note,
        'Girişte batı burnunda resif var; son yaklaşmayı resmî haritayla planlayın.');
    expect(s.rest, 'Çam ormanlı korunaklı koy.');
  });

  test('dört dilin önekleri de tanınır', () {
    for (final String p in kApproachNotePrefixes) {
      final ApproachNoteSplit s = splitApproachNote('Taban.\n\n${p}Not metni.');
      expect(s.note, 'Not metni.', reason: p);
      expect(s.rest, 'Taban.', reason: p);
    }
  });

  test('önek yoksa: not null, metin olduğu gibi', () {
    final ApproachNoteSplit s = splitApproachNote('Sıradan açıklama. Nokta.');
    expect(s.note, isNull);
    expect(s.rest, 'Sıradan açıklama. Nokta.');
  });

  test('açıklamanın tamamı nottan ibaretse taban null olur', () {
    final ApproachNoteSplit s = splitApproachNote('Yaklaşma notu: Sığlık var.');
    expect(s.note, 'Sığlık var.');
    expect(s.rest, isNull);
  });

  test('null/boş açıklama → ikisi de null', () {
    expect(splitApproachNote(null).note, isNull);
    expect(splitApproachNote(null).rest, isNull);
    expect(splitApproachNote('  ').note, isNull);
    expect(splitApproachNote('  ').rest, isNull);
  });

  test('not içindeki cümle sayısı korunur (bölünmez, kırpılmaz)', () {
    const String d = 'Taban metin.\n\nYaklaşma notu: Birinci cümle. İkinci cümle 3,5 m.';
    final ApproachNoteSplit s = splitApproachNote(d);
    expect(s.note, 'Birinci cümle. İkinci cümle 3,5 m.');
  });
}
