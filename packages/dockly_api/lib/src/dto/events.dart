/// ETKİNLİKLER & FIRSATLAR veri sözleşmeleri (V1 — kurucu onayı 2026-10-23).
///
/// Kilit sözleşmede görünür: kitlesi yetmeyen bakana fırsat KODU hiç inmez
/// (`code=null, locked=true`); süresi geçen kod da inmez (`expired=true`).
/// Kontenjan sayıları sunucunun işlemsel kilidinden gelir — istemci yalnız
/// gösterir, asla kendi saymaz.
library;

class DealView {
  const DealView({
    required this.id,
    required this.title,
    required this.partner,
    required this.benefit,
    required this.code,
    required this.locked,
    required this.audience,
    required this.validUntil,
    required this.terms,
    required this.place,
    required this.expired,
  });

  final String id;
  final String title;
  final String partner;
  final String benefit;

  /// Kilitli ya da süresi geçmişse null — sunucudan hiç çıkmaz.
  final String? code;
  final bool locked;

  /// 'all' | 'members' | 'premium'.
  final String audience;
  final DateTime? validUntil;
  final String? terms;
  final String? place;
  final bool expired;

  factory DealView.fromJson(Map<String, dynamic> json) => DealView(
        id: json['id'] as String,
        title: json['title'] as String,
        partner: json['partner'] as String,
        benefit: json['benefit'] as String,
        code: json['code'] as String?,
        locked: json['locked'] as bool,
        audience: json['audience'] as String,
        validUntil: json['validUntil'] == null
            ? null
            : DateTime.parse(json['validUntil'] as String),
        terms: json['terms'] as String?,
        place: json['place'] as String?,
        expired: json['expired'] as bool,
      );
}

class EventView {
  const EventView({
    required this.id,
    required this.title,
    required this.body,
    required this.startsAt,
    required this.endsAt,
    required this.locationText,
    required this.quota,
    required this.registeredCount,
    required this.remaining,
    required this.registrationDeadline,
    required this.priceNote,
    required this.conditions,
    required this.organizer,
    required this.audience,
    required this.status,
    required this.registered,
    required this.full,
    // SP-4 (kurucu onayı 2026-10-31): eski sunucuyla uyum için varsayılanlı.
    this.template,
    this.mine = false,
    this.community = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String locationText;
  final int quota;
  final int registeredCount;
  final int remaining;
  final DateTime? registrationDeadline;
  final String? priceNote;
  final String? conditions;
  final String organizer;

  /// 'all' | 'members' | 'premium'.
  final String audience;

  /// 'pending' | 'published' | 'cancelled' | 'rejected' (SP-4) — bekleyen/
  /// reddedilen yalnız kurucusuna iner; iptal dürüstçe listede kalır.
  final String status;

  /// Bakan kayıtlı mı?
  final bool registered;
  final bool full;

  /// SP-4: şablon kodu ('bay_meetup'|'joint_sail'|'marina_meetup') — Koybul
  /// resmi etkinliğinde null.
  final String? template;

  /// SP-4: etkinliği bakan mı kurdu?
  final bool mine;

  /// SP-4: kullanıcı (topluluk) etkinliği mi?
  final bool community;

  bool get cancelled => status == 'cancelled';
  bool get pending => status == 'pending';
  bool get rejected => status == 'rejected';

  factory EventView.fromJson(Map<String, dynamic> json) => EventView(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt:
            json['endsAt'] == null ? null : DateTime.parse(json['endsAt'] as String),
        locationText: json['locationText'] as String,
        quota: json['quota'] as int,
        registeredCount: json['registeredCount'] as int,
        remaining: json['remaining'] as int,
        registrationDeadline: json['registrationDeadline'] == null
            ? null
            : DateTime.parse(json['registrationDeadline'] as String),
        priceNote: json['priceNote'] as String?,
        conditions: json['conditions'] as String?,
        organizer: json['organizer'] as String,
        audience: json['audience'] as String,
        status: json['status'] as String,
        registered: json['registered'] as bool,
        full: json['full'] as bool,
        template: json['template'] as String?,
        mine: (json['mine'] as bool?) ?? false,
        community: (json['community'] as bool?) ?? false,
      );
}

/// RIZALI katılımcı satırı (SP-4) — yalnız izin verenler; PII yok.
class EventAttendee {
  const EventAttendee({required this.displayName, required this.levelCode});

  final String displayName;

  /// 'new' | 'coastal' | 'guide' | 'master' | 'pilot'.
  final String levelCode;

  factory EventAttendee.fromJson(Map<String, dynamic> json) => EventAttendee(
        displayName: (json['displayName'] as String?) ?? '',
        levelCode: (json['levelCode'] as String?) ?? 'new',
      );
}
