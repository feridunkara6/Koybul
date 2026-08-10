import 'package:dockly_api/dockly_api.dart';

/// Topluluk ağ geçidi — testte bellek içi sahte ile değiştirilir.
abstract interface class CommunityGateway {
  Future<List<Note>> notesForLocation(String locationId);
  Future<List<NearbyNote>> nearbyNotes(GeoPoint position);
  Future<List<Note>> myNotes({String? status});

  /// Not bırakır. Hesap yoksa [AuthFailure] fırlatır (arayüz kapısı normalde
  /// buraya düşürmez; oturum ağ yokken dolmuşsa güvenli taraf).
  Future<Note> createNote({
    required String locationId,
    required NoteKind kind,
    required String body,
    required String observedOn,
    String? title,
    GeoPoint? position,
    NoteWind? wind,
  });

  Future<void> deleteNote(String noteId);
  Future<NoteCounts> react(String noteId, String reaction);

  Future<void> createReview({
    required String idOrSlug,
    required int overallRating,
    String? body,
  });
}
