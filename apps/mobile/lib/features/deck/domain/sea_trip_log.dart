/// SEYİR KAYDI — alan modeli (v2.0 Defter, kurucu onayı 2026-08).
///
/// Kaptan rota kartındaki "Seyri başlat"a dokunur; "Seyri bitir" deyince
/// seyir tarih, süre ve rota bilgisiyle Defter'in Seyirler bölümüne işlenir.
///
/// DÜRÜSTLÜK: mesafe, seyir başlarkenki ROTA PLANININ mesafesidir (≈ ile
/// gösterilir) — tarayıcıda sürekli GPS izi tutulamaz; gerçek iz kaydı
/// v3.0 yerli uygulamayla gelecek. Süre ise gerçektir (başlat→bitir).
/// Kayıtlar cihazda saklanır (misafir ilkesi); hesap senkronu ileriki faz.
library;

/// Tamamlanmış seyir — Defter'in Seyirler bölümündeki satır.
class SeaTripLog {
  const SeaTripLog({
    required this.id,
    required this.name,
    required this.startMs,
    required this.endMs,
    required this.distanceNm,
    this.stops = 0,
  });

  final String id;

  /// Rota adı (kayıtlı rotanın adı ya da "A → B" önerisi).
  final String name;

  /// Başlangıç/bitiş anı (ms, epoch) — süre bu ikisinden hesaplanır.
  final int startMs;
  final int endMs;

  /// Başlangıçtaki rota planının mesafesi (≈, bilgi amaçlı).
  final double distanceNm;

  /// Rotadaki durak sayısı (başlangıç anında).
  final int stops;

  /// Gerçek seyir süresi (dakika, en az 1).
  int get durationMin {
    final int m = ((endMs - startMs) / 60000).round();
    return m < 1 ? 1 : m;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'start': startMs,
        'end': endMs,
        'nm': distanceNm,
        'stops': stops,
      };

  /// Bozuk kayıt → null (çökme yok; satır sessizce atlanır).
  static SeaTripLog? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? id = raw['id'] as String?;
    final String? name = raw['name'] as String?;
    final int? start = raw['start'] as int?;
    final int? end = raw['end'] as int?;
    final num? nm = raw['nm'] as num?;
    if (id == null || name == null || start == null || end == null) {
      return null;
    }
    return SeaTripLog(
      id: id,
      name: name,
      startMs: start,
      endMs: end,
      distanceNm: (nm ?? 0).toDouble(),
      stops: (raw['stops'] as int?) ?? 0,
    );
  }
}

/// SÜREN seyir — "Seyri başlat" anında alınan rota fotoğrafı. Cihazda
/// saklanır: sayfa yenilense/uygulama kapansa bile seyir KAYBOLMAZ,
/// Defter'den bitirilebilir.
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
abstract interface class SeaTripLogStore {
  Future<List<SeaTripLog>> load();
  Future<void> save(List<SeaTripLog> trips);

  /// Süren seyir (yoksa null). [saveActive]'e null vermek kaydı siler.
  Future<ActiveTrip?> loadActive();
  Future<void> saveActive(ActiveTrip? trip);
}
