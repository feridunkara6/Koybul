/// Denizci itibarı: seviye, puan, rozet, katkı dökümü ve moderasyon kuyruğu.
///
/// TASARIM İLKESİ (sunucuyla aynı): puan ÖDÜL DEĞİLDİR. Hiçbir ayrıcalık
/// açmaz; okuyan kaptana "bu bilgiyi ne kadar deneyimli birinden alıyorum"
/// sinyalini verir. Etiket metinleri istemcide, 4 dilde yaşar — sunucu yalnız
/// kodu gönderir.
library;

/// Bölgesel uzmanlık satırı: "Fethiye · 22 katkı".
class AreaExpertise {
  const AreaExpertise({required this.adminAreaId, required this.name, required this.count});

  final String adminAreaId;
  final String name;
  final int count;

  factory AreaExpertise.fromJson(Map<String, dynamic> json) => AreaExpertise(
        adminAreaId: json['adminAreaId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Rozet satırı — kazanılmış ya da ilerleme hâlinde.
class BadgeProgress {
  const BadgeProgress({
    required this.code,
    required this.earned,
    required this.current,
    required this.target,
    required this.automatic,
    this.awardedAt,
    this.scopeId,
    this.scopeName,
  });

  /// 'area_expert' | 'lighthouse' | 'safety_watch' | 'winter_sailor' |
  /// 'region_traveler' | 'first_explorer' | 'reliable_reporter' | 'verified_boat'
  final String code;
  final bool earned;
  final int current;
  final int target;

  /// false = rozetin altyapısı henüz yok; ekranda "yakında" yazar.
  final bool automatic;
  final String? awardedAt;

  /// Bölgesel rozette kapsam (ör. Fethiye); diğerlerinde null.
  final String? scopeId;
  final String? scopeName;

  /// 0.0–1.0 arası ilerleme. Hedef 0 ise (bozuk kayıt) 0 döner: bölme yok.
  double get ratio {
    if (earned) return 1;
    if (target <= 0) return 0;
    final double r = current / target;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }

  factory BadgeProgress.fromJson(Map<String, dynamic> json) => BadgeProgress(
        code: json['code'] as String,
        earned: json['earned'] as bool? ?? false,
        current: (json['current'] as num?)?.toInt() ?? 0,
        target: (json['target'] as num?)?.toInt() ?? 1,
        automatic: json['automatic'] as bool? ?? true,
        awardedAt: json['awardedAt'] as String?,
        scopeId: json['scopeId'] as String?,
        scopeName: json['scopeName'] as String?,
      );
}

/// "Denizci Profilim" kartının ve seviye/rozet ekranlarının tek kaynağı.
class ReputationSummary {
  const ReputationSummary({
    required this.displayName,
    required this.points,
    required this.levelCode,
    required this.pointsToNext,
    required this.trustScore,
    required this.approvedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.helpfulReceived,
    required this.writeRestrictedUntil,
    required this.areas,
    required this.badges,
  });

  /// Kaptanın kamuya açık adı — kartın başlığı BUDUR (ürün adı değil).
  final String displayName;
  final int points;

  /// 'new' | 'coastal' | 'guide' | 'master' | 'pilot'.
  final String levelCode;

  /// Bir sonraki seviyeye kalan puan; en üstteyse null.
  final int? pointsToNext;

  /// 0.00–1.50. Yalnız KAZANILAN puanı etkiler; görünürlüğü ETKİLEMEZ.
  final double trustScore;
  final int approvedCount;
  final int pendingCount;
  final int rejectedCount;
  final int helpfulReceived;

  /// Doluysa kullanıcı geçici yazma kısıtı altındadır (ISO tarih).
  final String? writeRestrictedUntil;
  final List<AreaExpertise> areas;
  final List<BadgeProgress> badges;

  /// Hiç katkı yok mu — kart "henüz katkın yok" hâlini gösterir.
  bool get isEmpty => points == 0 && approvedCount == 0 && pendingCount == 0;

  /// Avatar için baş harfler ("Feridun Kara" → "FK"). Ad yoksa BOŞ döner ve
  /// kart genel ikonuna düşer — uydurma harf gösterilmez.
  String get initials {
    final List<String> words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '';
    final String first = _upperTr(_firstGlyph(words.first));
    if (words.length == 1) return first;
    return first + _upperTr(_firstGlyph(words.last));
  }

  /// Sözcüğün İLK GÖRÜNEN karakteri. `substring(0, 1)` UTF-16 birimi keser ve
  /// emoji gibi VEKİL ÇİFTİ (surrogate pair) ile başlayan adı ikiye bölüp
  /// bozuk karakter üretirdi. `package:characters` bu pakette yok, o yüzden
  /// vekil çifti elle kontrol edilir.
  static String _firstGlyph(String word) {
    final int unit = word.codeUnitAt(0);
    final bool highSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
    return word.substring(0, highSurrogate && word.length > 1 ? 2 : 1);
  }

  /// Türkçe'ye duyarlı büyütme: Dart'ın `toUpperCase`'i 'i' harfini 'I' yapar,
  /// oysa Türkçe'de karşılığı 'İ'dir ("İbrahim" → 'I' değil 'İ').
  static String _upperTr(String ch) {
    if (ch == 'i') return 'İ';
    if (ch == 'ı') return 'I';
    return ch.toUpperCase();
  }

  List<BadgeProgress> get earnedBadges =>
      badges.where((BadgeProgress b) => b.earned).toList(growable: false);

  List<BadgeProgress> get lockedBadges =>
      badges.where((BadgeProgress b) => !b.earned).toList(growable: false);

  static const ReputationSummary empty = ReputationSummary(
    displayName: '',
    points: 0,
    levelCode: 'new',
    pointsToNext: null,
    trustScore: 1,
    approvedCount: 0,
    pendingCount: 0,
    rejectedCount: 0,
    helpfulReceived: 0,
    writeRestrictedUntil: null,
    areas: <AreaExpertise>[],
    badges: <BadgeProgress>[],
  );

  factory ReputationSummary.fromJson(Map<String, dynamic> json) => ReputationSummary(
        displayName: json['displayName'] as String? ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        levelCode: json['levelCode'] as String? ?? 'new',
        pointsToNext: (json['pointsToNext'] as num?)?.toInt(),
        trustScore: (json['trustScore'] as num?)?.toDouble() ?? 1,
        approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
        pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
        rejectedCount: (json['rejectedCount'] as num?)?.toInt() ?? 0,
        helpfulReceived: (json['helpfulReceived'] as num?)?.toInt() ?? 0,
        writeRestrictedUntil: json['writeRestrictedUntil'] as String?,
        areas: <AreaExpertise>[
          for (final dynamic a in (json['areas'] as List<dynamic>?) ?? const <dynamic>[])
            AreaExpertise.fromJson(a as Map<String, dynamic>),
        ],
        badges: <BadgeProgress>[
          for (final dynamic b in (json['badgeProgress'] as List<dynamic>?) ?? const <dynamic>[])
            BadgeProgress.fromJson(b as Map<String, dynamic>),
        ],
      );
}

/// Katkı puanı dökümündeki tek satır.
class ContributionItem {
  const ContributionItem({
    required this.id,
    required this.type,
    required this.points,
    required this.createdAt,
    this.entityType,
    this.entityId,
  });

  final String id;

  /// `contribution_type` kodu — etiketi istemci çevirir.
  final String type;
  final int points;
  final String createdAt;
  final String? entityType;
  final String? entityId;

  factory ContributionItem.fromJson(Map<String, dynamic> json) => ContributionItem(
        id: json['id'] as String,
        type: json['type'] as String,
        points: (json['points'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] as String,
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
      );
}

/// Moderasyon kuyruğundaki bir öğe (yalnız `moderator` rolü görür).
class ModerationItem {
  const ModerationItem({
    required this.taskId,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.body,
    required this.authorName,
    required this.authorLevelCode,
    required this.approvedCount,
    required this.rejectedCount,
    this.kind,
    this.title,
    this.locationName,
    this.observedOn,
    this.gpsVerified,
  });

  final String taskId;

  /// 'note' | 'review' | 'media' | 'suggested_location' | 'location_report'.
  final String entityType;
  final String entityId;
  final String createdAt;
  final String body;
  final String authorName;
  final String authorLevelCode;
  final int approvedCount;
  final int rejectedCount;
  final String? kind;
  final String? title;
  final String? locationName;
  final String? observedOn;
  final bool? gpsVerified;

  /// Yazarın onay oranı (yüzde, 0–100). Hiç kararlanmamışsa null.
  int? get approvalRate {
    final int total = approvedCount + rejectedCount;
    if (total == 0) return null;
    return ((approvedCount / total) * 100).round();
  }

  factory ModerationItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> p =
        (json['preview'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> a =
        (json['author'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return ModerationItem(
      taskId: json['taskId'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      createdAt: json['createdAt'] as String,
      body: p['body'] as String? ?? '',
      kind: p['kind'] as String?,
      title: p['title'] as String?,
      locationName: p['locationName'] as String?,
      observedOn: p['observedOn'] as String?,
      gpsVerified: p['gpsVerified'] as bool?,
      authorName: a['displayName'] as String? ?? '',
      authorLevelCode: a['levelCode'] as String? ?? 'new',
      approvedCount: (a['approvedCount'] as num?)?.toInt() ?? 0,
      rejectedCount: (a['rejectedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Reddetme sebepleri — sunucudaki `REJECT_REASONS` ile birebir.
const List<String> kRejectReasons = <String>[
  'off_topic',
  'not_verifiable',
  'duplicate',
  'personal_data',
  'offensive',
  'wrong_location',
  'other',
];
