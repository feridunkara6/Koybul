import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';

import '../domain/community_gateway.dart';

/// Gerçek sunucu ağ geçidi. Yazma çağrıları access token ister; token yoksa
/// standart oturum hatası fırlatılır (occupancy ağ geçidiyle aynı desen).
class ApiCommunityGateway implements CommunityGateway {
  ApiCommunityGateway(this._api, this._tokenProvider);

  final CommunityApi _api;
  final Future<String?> Function() _tokenProvider;

  Future<String> _token() async {
    final String? t = await _tokenProvider();
    if (t == null) {
      throw const AuthFailure('Oturum yenilenemedi — lütfen tekrar giriş yapın.');
    }
    return t;
  }

  @override
  Future<List<Note>> notesForLocation(String locationId) =>
      _api.notesForLocation(locationId);

  @override
  Future<List<NearbyNote>> nearbyNotes(GeoPoint position) =>
      _api.nearbyNotes(position: position);

  @override
  Future<List<Note>> myNotes({String? status}) async =>
      _api.myNotes(accessToken: await _token(), status: status);

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
    return _api.createNote(
      locationId: locationId,
      kind: kind,
      body: body,
      observedOn: observedOn,
      title: title,
      position: position,
      wind: wind,
      accessToken: await _token(),
    );
  }

  @override
  Future<void> deleteNote(String noteId) async =>
      _api.deleteNote(noteId: noteId, accessToken: await _token());

  @override
  Future<NoteCounts> react(String noteId, String reaction) async =>
      _api.reactToNote(noteId: noteId, reaction: reaction, accessToken: await _token());

  @override
  Future<void> createReview({
    required String idOrSlug,
    required int overallRating,
    String? body,
  }) async {
    await _api.createReview(
      idOrSlug: idOrSlug,
      overallRating: overallRating,
      body: body,
      accessToken: await _token(),
    );
  }
}
