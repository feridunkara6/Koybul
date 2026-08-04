/// Açıklamadan YAKLAŞMA NOTUNU ayıran SAF işlev (widget'tan bağımsız, testli).
///
/// Veri sözleşmesi (apps/api generate_locations_seed.py, emit_yaklasma):
/// açıklama = taban metin + "\n\n" + "<dil önekli> " + not. Önek dört dilde
/// sabittir; istemci bu sözleşmeyi ayrıştırır — YENİ İÇERİK ÜRETMEZ (0-uydurma).
/// Önek yoksa: not = null, metin olduğu gibi kalır.
library;

/// Dört dildeki sabit önekler (seed PREFIX haritasının birebir kopyası).
const List<String> kApproachNotePrefixes = <String>[
  'Yaklaşma notu: ',
  'Approach note: ',
  'Nota de aproximación: ',
  'Заметка о подходе: ',
];

class ApproachNoteSplit {
  const ApproachNoteSplit({required this.note, required this.rest});

  /// Yaklaşma notu metni (öneksiz); açıklamada not yoksa null.
  final String? note;

  /// Not çıkarıldıktan sonra kalan açıklama; boşsa null.
  final String? rest;
}

ApproachNoteSplit splitApproachNote(String? description) {
  final String text = (description ?? '').trim();
  if (text.isEmpty) return const ApproachNoteSplit(note: null, rest: null);
  for (final String prefix in kApproachNotePrefixes) {
    // Sözleşmedeki biçim: taban + "\n\n" + önek + not.
    final int i = text.indexOf('\n\n$prefix');
    if (i >= 0) {
      final String note = text.substring(i + 2 + prefix.length).trim();
      final String rest = text.substring(0, i).trim();
      return ApproachNoteSplit(
        note: note.isEmpty ? null : note,
        rest: rest.isEmpty ? null : rest,
      );
    }
    // Uç durum: açıklamanın tamamı nottan ibaret (taban metin yok).
    if (text.startsWith(prefix)) {
      final String note = text.substring(prefix.length).trim();
      return ApproachNoteSplit(note: note.isEmpty ? null : note, rest: null);
    }
  }
  return ApproachNoteSplit(note: null, rest: text);
}
