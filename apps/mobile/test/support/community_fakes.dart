import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/domain/community_gateway.dart';

/// Bellek içi topluluk ağ geçidi — ağa hiç çıkmaz.
class FakeCommunityGateway implements CommunityGateway {
  FakeCommunityGateway({List<Note>? notes}) : notes = notes ?? <Note>[];

  final List<Note> notes;
  final List<({String noteId, String reaction})> reactions =
      <({String noteId, String reaction})>[];
  final List<Note> created = <Note>[];
  final List<({String idOrSlug, int rating, String? body})> reviews =
      <({String idOrSlug, int rating, String? body})>[];

  /// Ayarlanırsa yazma çağrıları bu hatayla düşer.
  Object? failWith;

  /// Oluşturulan notun sunucudan dönen durumu.
  String createdStatus = 'pending';

  @override
  Future<List<Note>> notesForLocation(String locationId) async => notes;

  @override
  Future<List<NearbyNote>> nearbyNotes(GeoPoint position) async => <NearbyNote>[];

  @override
  Future<List<Note>> myNotes({String? status}) async => notes;

  @override
  Future<Note> createNote({
    required String locationId,
    required NoteKind kind,
    required String body,
    required String observedOn,
    String? title,
    GeoPoint? position,
    NoteWind? wind,
  }) async {
    if (failWith != null) throw failWith!;
    final Note n = makeNote(
      id: 'new-${created.length + 1}',
      kind: kind,
      body: body,
      observedOn: observedOn,
      status: createdStatus,
      wind: wind,
    );
    created.add(n);
    return n;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    notes.removeWhere((Note n) => n.id == noteId);
  }

  @override
  Future<NoteCounts> react(String noteId, String reaction) async {
    if (failWith != null) throw failWith!;
    reactions.add((noteId: noteId, reaction: reaction));
    return const NoteCounts(helpfulCount: 1, confirmCount: 0, disputeCount: 0);
  }

  @override
  Future<void> createReview({
    required String idOrSlug,
    required int overallRating,
    String? body,
  }) async {
    if (failWith != null) throw failWith!;
    reviews.add((idOrSlug: idOrSlug, rating: overallRating, body: body));
  }
}

/// Test notu üreticisi — yalnız ilgilenilen alanlar verilir.
Note makeNote({
  String id = 'n1',
  NoteKind kind = NoteKind.experience,
  String body = 'Kuzey ucunda kum, tutuş iyi.',
  String observedOn = '2026-08-01',
  String? title,
  String? status,
  NoteWind? wind,
  int helpfulCount = 0,
  int confirmCount = 0,
  String displayName = 'M. Kaya',
  String levelCode = 'master',
}) {
  return Note(
    id: id,
    kind: kind,
    locationId: 'loc-1',
    title: title,
    body: body,
    observedOn: observedOn,
    gpsVerified: false,
    wind: wind,
    helpfulCount: helpfulCount,
    confirmCount: confirmCount,
    disputeCount: 0,
    createdAt: '2026-08-01T10:00:00.000Z',
    author: NoteAuthor(
      userId: 'u-author',
      displayName: displayName,
      levelCode: levelCode,
      areaContributions: null,
    ),
    status: status,
  );
}
