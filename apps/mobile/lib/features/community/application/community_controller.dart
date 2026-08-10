import 'package:dockly_api/dockly_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_community_gateway.dart';
import '../domain/community_gateway.dart';

/// KAPTAN NOTLARI — istemci tarafı orkestrasyonu.
///
/// Okuma anonimdir (misafir her şeyi okur). Yazma HESAP ister; arayüz kapısı
/// `requireAccount` ile, sunucu `@RequireAccount()` ile — iki katman tutarlı.

final Provider<CommunityGateway> communityGatewayProvider = Provider<CommunityGateway>((ref) {
  return ApiCommunityGateway(
    ref.watch(communityApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Bir noktanın onaylı notları. `autoDispose`: detay kapanınca istek serbest kalır.
final notesForLocationProvider =
    FutureProvider.autoDispose.family<List<Note>, String>((ref, String locationId) {
  return ref.watch(communityGatewayProvider).notesForLocation(locationId);
});

/// Yazma sonrası yerel tazeleme. Sunucu GET'i 300 sn CDN önbelleğinde olabilir;
/// kendi katkısını YAZAN kullanıcı sonucu HEMEN görmelidir (occupancy deseni).
class NoteOverrides extends Notifier<Map<String, List<Note>>> {
  @override
  Map<String, List<Note>> build() => <String, List<Note>>{};

  /// Onaylanmadan yayına çıkan not (güncel durum) listeye anında eklenir.
  void prepend(String locationId, Note note) {
    if (note.status != null && note.status != 'approved') return;
    final List<Note> current = state[locationId] ?? const <Note>[];
    state = <String, List<Note>>{
      ...state,
      locationId: <Note>[note, ...current],
    };
  }

  void removeNote(String locationId, String noteId) {
    final List<Note> current = state[locationId] ?? const <Note>[];
    state = <String, List<Note>>{
      ...state,
      locationId: current.where((Note n) => n.id != noteId).toList(growable: false),
    };
  }

}

/// Tepki sonrası sayaç yamaları: not KİMLİĞİNE göre, listeden bağımsız.
///
/// Ayrı bir harita olmasının sebebi: notların çoğu SUNUCUDAN gelir ve yerel
/// listede yoktur; sayacı yalnız yerel listede güncellemeye çalışmak, oy veren
/// kullanıcının kendi oyunu görememesine yol açıyordu (inceleme bulgusu 2026-08).
class NoteCounters extends Notifier<Map<String, NoteCounts>> {
  @override
  Map<String, NoteCounts> build() => <String, NoteCounts>{};

  void apply(String noteId, NoteCounts counts) {
    state = <String, NoteCounts>{...state, noteId: counts};
  }
}

final NotifierProvider<NoteCounters, Map<String, NoteCounts>> noteCountersProvider =
    NotifierProvider<NoteCounters, Map<String, NoteCounts>>(NoteCounters.new);

final NotifierProvider<NoteOverrides, Map<String, List<Note>>> noteOverridesProvider =
    NotifierProvider<NoteOverrides, Map<String, List<Note>>>(NoteOverrides.new);

/// Ekranın okuyacağı BİRLEŞİK liste: sunucudan gelenler + yerel eklemeler.
/// Yerel kayıtlar başa gelir ve kimliğe göre tekilleştirilir.
List<Note> mergeNotes(List<Note> fromServer, List<Note> local) {
  final Set<String> seen = <String>{};
  final List<Note> out = <Note>[];
  for (final Note n in <Note>[...local, ...fromServer]) {
    if (seen.add(n.id)) out.add(n);
  }
  // Uyarılar her zaman başta: emniyet bilgisi listenin dibinde kalmaz.
  out.sort((Note a, Note b) {
    final int ah = a.kind == NoteKind.hazard ? 0 : 1;
    final int bh = b.kind == NoteKind.hazard ? 0 : 1;
    if (ah != bh) return ah - bh;
    return b.observedOn.compareTo(a.observedOn);
  });
  return out;
}
