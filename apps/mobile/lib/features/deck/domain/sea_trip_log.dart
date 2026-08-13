/// SEYİR KAYDI — alan modeli (v2.1 "Planla → Gerçekleşti", kurucu onayı
/// 2026-08; tasarım raporu: koybul-seyir-sistemi-tasarim).
///
/// ESKİ MODEL ("Seyri başlat/bitir") kaldırıldı: uygulama teknede açık
/// tutulmadığı için iki-dokunuşlu süre ölçümü sistematik olarak yanlış veri
/// üretiyordu (unutulan "bitir" → hayalet seyirler). YENİ MODEL tek kaydın
/// iki durumudur:
///
///   PLANLANDI  — kaptan rota çizip "Seyri planla" dedi (niyet).
///   GERÇEKLEŞTİ — kaptan seferi yaptı ve "Gerçekleşti"yi işaretledi (anı).
///
/// Sezon istatistiklerine YALNIZ gerçekleşen seferler sayılır (0-uydurma).
/// Mesafe her zaman rota PLANININ mesafesidir (≈ ile gösterilir); süre,
/// kaptan isterse elle girdiği değerdir — ölçüm iddiası yok, dürüstlük var.
/// GERİYE UYUM: eski başlat/bitir kayıtları GERÇEKLEŞTİ olarak, ölçülen
/// süreleri korunarak okunur — kimse veri kaybetmez.
library;

/// Sefer durumu: planlanan niyet mi, gerçekleşen seyir mi?
enum TripStatus { planned, done }

/// Sefer kaydı — Defter'in Seyirler bölümündeki satır (her iki durumda).
class SeaTripLog {
  const SeaTripLog({
    required this.id,
    required this.name,
    required this.status,
    required this.dateMs,
    required this.distanceNm,
    this.stops = 0,
    this.durMin,
  });

  final String id;

  /// Rota adı (kayıtlı rotanın adı ya da "A → B" önerisi).
  final String name;

  /// PLANLANDI ya da GERÇEKLEŞTİ.
  final TripStatus status;

  /// PLANLANDI: planın oluşturulduğu an. GERÇEKLEŞTİ: seferin yapıldığı
  /// tarih (kaptanın onayladığı gün). Liste sıralaması ve karttaki tarih
  /// bu alandan gelir.
  final int dateMs;

  /// Rota planının mesafesi (≈, bilgi amaçlı — ölçüm değil).
  final double distanceNm;

  /// Rotadaki durak sayısı (plan anında).
  final int stops;

  /// Denizde geçen süre (dakika) — İSTEĞE BAĞLI. Yeni akışta kaptan
  /// "Gerçekleşti" onayında girerse dolar; eski başlat/bitir kayıtlarında
  /// ölçülen süre buraya taşınır. null = süre bilinmiyor (dürüst boşluk).
  final int? durMin;

  bool get isPlanned => status == TripStatus.planned;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'st': status == TripStatus.planned ? 'planned' : 'done',
        'date': dateMs,
        'nm': distanceNm,
        'stops': stops,
        if (durMin != null) 'dur': durMin,
      };

  /// Bozuk kayıt → null (çökme yok; satır sessizce atlanır).
  ///
  /// İKİ BİÇİM OKUNUR:
  ///  * yeni: {id, name, st, date, nm, stops, dur?}
  ///  * eski (v2.0 başlat/bitir): {id, name, start, end, nm, stops} —
  ///    GERÇEKLEŞTİ sayılır; tarih = bitiş anı, süre = end-start (ölçülmüştü).
  static SeaTripLog? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? id = raw['id'] as String?;
    final String? name = raw['name'] as String?;
    if (id == null || name == null) return null;
    final num? nm = raw['nm'] as num?;
    final int stops = (raw['stops'] as int?) ?? 0;

    final String? st = raw['st'] as String?;
    if (st != null) {
      final int? date = raw['date'] as int?;
      if (date == null) return null;
      if (st != 'planned' && st != 'done') return null;
      return SeaTripLog(
        id: id,
        name: name,
        status: st == 'planned' ? TripStatus.planned : TripStatus.done,
        dateMs: date,
        distanceNm: (nm ?? 0).toDouble(),
        stops: stops,
        durMin: raw['dur'] as int?,
      );
    }

    // Eski biçim (start/end) — kayıpsız göç.
    final int? start = raw['start'] as int?;
    final int? end = raw['end'] as int?;
    if (start == null || end == null) return null;
    final int measured = ((end - start) / 60000).round();
    return SeaTripLog(
      id: id,
      name: name,
      status: TripStatus.done,
      dateMs: end,
      distanceNm: (nm ?? 0).toDouble(),
      stops: stops,
      durMin: measured < 1 ? 1 : measured,
    );
  }

  /// Kaydın kopyası — durum geçişi için (PLANLANDI → GERÇEKLEŞTİ).
  SeaTripLog copyWith({TripStatus? status, int? dateMs, int? durMin}) {
    return SeaTripLog(
      id: id,
      name: name,
      status: status ?? this.status,
      dateMs: dateMs ?? this.dateMs,
      distanceNm: distanceNm,
      stops: stops,
      durMin: durMin ?? this.durMin,
    );
  }
}

/// ESKİ "süren seyir" kaydı — yalnız GÖÇ için okunur (v2.0 kalıntısı).
/// "Seyri başlat" demiş ama hiç bitirmemiş kaptanın kaydı çöpe atılmaz:
/// ilk açılışta PLANLANDI seferine çevrilir (dürüst durum: niyet vardı,
/// bitiş ölçümü yok). Yeni akışta bu sınıf hiçbir yerde YAZILMAZ.
class ActiveTrip {
  const ActiveTrip({
    required this.name,
    required this.startMs,
    required this.distanceNm,
    this.stops = 0,
  });

  final String name;
  final int startMs;
  final double distanceNm;
  final int stops;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'start': startMs,
        'nm': distanceNm,
        'stops': stops,
      };

  static ActiveTrip? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? name = raw['name'] as String?;
    final int? start = raw['start'] as int?;
    final num? nm = raw['nm'] as num?;
    if (name == null || start == null) return null;
    return ActiveTrip(
      name: name,
      startMs: start,
      distanceNm: (nm ?? 0).toDouble(),
      stops: (raw['stops'] as int?) ?? 0,
    );
  }
}

/// Seyir deposu arayüzü — testte sahtesiyle değiştirilir.
/// loadActive/saveActive yalnız eski-kayıt GÖÇÜ için durur.
abstract interface class SeaTripLogStore {
  Future<List<SeaTripLog>> load();
  Future<void> save(List<SeaTripLog> trips);

  /// ESKİ süren seyir (yoksa null) — göçte okunur, sonra null'a çekilir.
  Future<ActiveTrip?> loadActive();
  Future<void> saveActive(ActiveTrip? trip);
}
