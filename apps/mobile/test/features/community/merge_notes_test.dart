import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/application/community_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_fakes.dart';

void main() {
  test('yerel kayıt sunucu listesine eklenir, kimlik tekrarı olmaz', () {
    final List<Note> server = <Note>[makeNote(id: 'a'), makeNote(id: 'b')];
    final List<Note> local = <Note>[makeNote(id: 'a'), makeNote(id: 'c')];
    final List<Note> out = mergeNotes(server, local);
    expect(out.map((Note n) => n.id).toSet(), <String>{'a', 'b', 'c'});
    expect(out, hasLength(3));
  });

  test('UYARI notları HER ZAMAN başa alınır — yerel liste boş olsa bile', () {
    final List<Note> server = <Note>[
      makeNote(id: 'yeni', observedOn: '2026-08-09'),
      makeNote(id: 'uyari', kind: NoteKind.hazard, observedOn: '2026-01-01'),
    ];
    // Eski davranış yerel liste boşken sıralamayı ATLIYORDU: eski tarihli bir
    // uyarı yeni notların altında kalıyordu (inceleme bulgusu 2026-08).
    expect(mergeNotes(server, <Note>[]).first.kind, NoteKind.hazard);
    expect(mergeNotes(server, <Note>[makeNote(id: 'x')]).first.kind, NoteKind.hazard);
  });

  test('aynı tipte notlar gözlem tarihine göre yeniden eskiye sıralanır', () {
    final List<Note> out = mergeNotes(
      <Note>[
        makeNote(id: 'eski', observedOn: '2026-06-01'),
        makeNote(id: 'yeni', observedOn: '2026-08-01'),
      ],
      <Note>[makeNote(id: 'orta', observedOn: '2026-07-01')],
    );
    expect(out.map((Note n) => n.id).toList(), <String>['yeni', 'orta', 'eski']);
  });

  test('boş girdilerde boş liste döner', () {
    expect(mergeNotes(<Note>[], <Note>[]), isEmpty);
  });
}
