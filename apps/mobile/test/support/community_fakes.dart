import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/features/community/domain/community_gateway.dart';
import 'package:dockly_mobile/features/community/domain/reputation_gateway.dart';

/// Bellek içi topluluk ağ geçidi — ağa hiç çıkmaz.
class FakeCommunityGateway implements CommunityGateway {
  FakeCommunityGateway({List<Note>? notes, List<NearbyNote>? nearby})
      : notes = notes ?? <Note>[],
        nearby = nearby ?? <NearbyNote>[];

  final List<Note> notes;

  /// "Yakında paylaşılanlar" akışının içeriği.
  final List<NearbyNote> nearby;
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
  Future<List<NearbyNote>> nearbyNotes(GeoPoint position) async => nearby;

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
  String createdAt = '2026-08-01T10:00:00.000Z',
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
    createdAt: createdAt,
    author: NoteAuthor(
      userId: 'u-author',
      displayName: displayName,
      levelCode: levelCode,
      areaContributions: null,
    ),
    status: status,
  );
}

/// "Yakında paylaşılanlar" satırı üreticisi.
NearbyNote makeNearbyNote({
  String id = 'nb1',
  NoteKind kind = NoteKind.hazard,
  String body = 'Batı girişinde yüzer ağ var.',
  String locationName = 'Kızılada',
  double distanceNm = 4,
  String createdAt = '2026-08-01T10:00:00.000Z',
}) {
  return NearbyNote(
    note: makeNote(id: id, kind: kind, body: body, createdAt: createdAt),
    distanceNm: distanceNm,
    locationName: locationName,
  );
}

/// Bellek içi denizci profili ağ geçidi — ağa hiç çıkmaz.
class FakeReputationGateway implements ReputationGateway {
  FakeReputationGateway({
    ReputationSummary? summary,
    List<ContributionItem>? contributions,
    List<ModerationItem>? queue,
    Map<String, int>? counts,
  })  : _summary = summary ?? makeSummary(),
        _contributions = contributions ?? <ContributionItem>[],
        _queue = queue ?? <ModerationItem>[],
        _counts = counts ?? <String, int>{};

  final ReputationSummary _summary;
  final List<ContributionItem> _contributions;
  final List<ModerationItem> _queue;
  final Map<String, int> _counts;

  /// Verilen kararların kaydı — testler bunu doğrular.
  final List<({String taskId, bool approve, String? reason})> decisions =
      <({String taskId, bool approve, String? reason})>[];

  /// Ayarlanırsa `decide` bu hatayla düşer.
  Object? failWith;

  @override
  Future<ReputationSummary> summary() async => _summary;

  @override
  Future<List<ContributionItem>> contributions() async => _contributions;

  @override
  Future<Map<String, int>> moderationCounts() async => _counts;

  @override
  Future<List<ModerationItem>> moderationQueue({String? entityType}) async {
    if (entityType == null) return _queue;
    return _queue.where((ModerationItem i) => i.entityType == entityType).toList();
  }

  @override
  Future<void> decide({
    required String taskId,
    required bool approve,
    String? reason,
  }) async {
    if (failWith != null) throw failWith!;
    decisions.add((taskId: taskId, approve: approve, reason: reason));
  }
}

ReputationSummary makeSummary({
  int points = 2840,
  String levelCode = 'master',
  int? pointsToNext = 1160,
  double trustScore = 1.2,
  int approvedCount = 24,
  int pendingCount = 2,
  int rejectedCount = 1,
  List<AreaExpertise>? areas,
  List<BadgeProgress>? badges,
}) {
  return ReputationSummary(
    points: points,
    levelCode: levelCode,
    pointsToNext: pointsToNext,
    trustScore: trustScore,
    approvedCount: approvedCount,
    pendingCount: pendingCount,
    rejectedCount: rejectedCount,
    helpfulReceived: 12,
    writeRestrictedUntil: null,
    areas: areas ??
        const <AreaExpertise>[
          AreaExpertise(adminAreaId: 'a1', name: 'Fethiye', count: 22),
        ],
    badges: badges ?? <BadgeProgress>[],
  );
}

BadgeProgress makeBadge({
  String code = 'safety_watch',
  bool earned = false,
  int current = 4,
  int target = 5,
  bool automatic = true,
  String? scopeId,
  String? scopeName,
}) {
  return BadgeProgress(
    code: code,
    earned: earned,
    current: current,
    target: target,
    automatic: automatic,
    awardedAt: earned ? '2026-08-01T00:00:00.000Z' : null,
    scopeId: scopeId,
    scopeName: scopeName,
  );
}

ModerationItem makeModerationItem({
  String taskId = 't1',
  String entityType = 'note',
  String? kind = 'hazard',
  String body = 'Batı girişinde yüzer ağ var.',
  String authorName = 'A. Demir',
  int approvedCount = 24,
  int rejectedCount = 1,
}) {
  return ModerationItem(
    taskId: taskId,
    entityType: entityType,
    entityId: 'e-$taskId',
    createdAt: '2026-08-01T08:20:00.000Z',
    body: body,
    authorName: authorName,
    authorLevelCode: 'guide',
    approvedCount: approvedCount,
    rejectedCount: rejectedCount,
    kind: kind,
    locationName: 'Kızılada',
    observedOn: '2026-08-01',
    gpsVerified: true,
  );
}
