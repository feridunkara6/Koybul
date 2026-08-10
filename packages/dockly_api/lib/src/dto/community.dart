/// Kaptan Notu tipi. Sunucudaki `note_kind` enum'uyla birebir.
enum NoteKind {
  /// Güncel durum — 48 saat öne çıkar, GPS ister.
  status,

  /// Emniyet uyarısı — kalıcı, GPS ister, insan moderasyonu şart.
  hazard,

  /// Demirleme/marina/restoran deneyimi — kalıcı.
  experience,

  /// İki nokta arası seyir notu — kalıcı.
  passage;

  static NoteKind fromWire(String v) => switch (v) {
        'status' => NoteKind.status,
        'hazard' => NoteKind.hazard,
        'passage' => NoteKind.passage,
        _ => NoteKind.experience,
      };

  String get wire => name;
}

/// Notun yazıldığı andaki hava — sunucuda DONDURULUR, sonradan değişmez.
class NoteWind {
  const NoteWind({required this.kn, required this.dirTr});

  final int kn;

  /// TR pusula kodu (K, KD, D, GD, G, GB, B, KB).
  final String dirTr;

  factory NoteWind.fromJson(Map<String, dynamic> json) => NoteWind(
        kn: (json['kn'] as num).round(),
        dirTr: json['dirTr'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'kn': kn, 'dirTr': dirTr};
}

/// Not yazarının kamuya açık kimliği — PII taşımaz.
class NoteAuthor {
  const NoteAuthor({
    required this.userId,
    required this.displayName,
    required this.levelCode,
    required this.areaContributions,
  });

  final String userId;
  final String displayName;

  /// 'new' | 'coastal' | 'guide' | 'master' | 'pilot' — etiketi istemci çevirir.
  final String levelCode;

  /// Bu notun bölgesindeki onaylı katkı sayısı (yoksa null).
  final int? areaContributions;

  factory NoteAuthor.fromJson(Map<String, dynamic> json) => NoteAuthor(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        levelCode: json['levelCode'] as String? ?? 'new',
        areaContributions: (json['areaContributions'] as num?)?.toInt(),
      );
}

/// Yayındaki (ya da sahibi için bekleyen) bir Kaptan Notu.
class Note {
  const Note({
    required this.id,
    required this.kind,
    required this.locationId,
    required this.title,
    required this.body,
    required this.observedOn,
    required this.gpsVerified,
    required this.wind,
    required this.helpfulCount,
    required this.confirmCount,
    required this.disputeCount,
    required this.createdAt,
    required this.author,
    required this.status,
  });

  final String id;
  final NoteKind kind;
  final String? locationId;
  final String? title;
  final String body;

  /// "Ne zaman oradaydı" — YYYY-MM-DD. Yazılma tarihi DEĞİL.
  final String observedOn;
  final bool gpsVerified;
  final NoteWind? wind;
  final int helpfulCount;
  final int confirmCount;
  final int disputeCount;
  final String createdAt;
  final NoteAuthor author;

  /// Yalnız kendi içeriğini listelerken dolu: pending | approved | rejected.
  final String? status;

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        kind: NoteKind.fromWire(json['kind'] as String),
        locationId: json['locationId'] as String?,
        title: json['title'] as String?,
        body: json['body'] as String,
        observedOn: json['observedOn'] as String,
        gpsVerified: json['gpsVerified'] as bool? ?? false,
        wind: json['wind'] == null
            ? null
            : NoteWind.fromJson(json['wind'] as Map<String, dynamic>),
        helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
        confirmCount: (json['confirmCount'] as num?)?.toInt() ?? 0,
        disputeCount: (json['disputeCount'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] as String,
        author: NoteAuthor.fromJson(json['author'] as Map<String, dynamic>),
        status: json['status'] as String?,
      );
}

/// "Yakında paylaşılanlar" akışındaki not — mesafe ve nokta adı ekli.
class NearbyNote {
  const NearbyNote({required this.note, required this.distanceNm, required this.locationName});

  final Note note;
  final double distanceNm;
  final String? locationName;

  factory NearbyNote.fromJson(Map<String, dynamic> json) => NearbyNote(
        note: Note.fromJson(json),
        distanceNm: (json['distanceNm'] as num?)?.toDouble() ?? 0,
        locationName: json['locationName'] as String?,
      );
}

/// Not tepkisinden sonra dönen güncel sayaçlar.
class NoteCounts {
  const NoteCounts({
    required this.helpfulCount,
    required this.confirmCount,
    required this.disputeCount,
  });

  final int helpfulCount;
  final int confirmCount;
  final int disputeCount;

  factory NoteCounts.fromJson(Map<String, dynamic> json) => NoteCounts(
        helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
        confirmCount: (json['confirmCount'] as num?)?.toInt() ?? 0,
        disputeCount: (json['disputeCount'] as num?)?.toInt() ?? 0,
      );
}
