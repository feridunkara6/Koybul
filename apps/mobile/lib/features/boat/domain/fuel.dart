/// YAKIT TAKİBİ — alan modeli (kurucu onayı 2026-10-30).
///
/// İLKE: uygulama tüketimi ÖLÇMEZ; yalnız kaptanın girdiği dolumları saklar
/// ve dürüstçe türetebildiğini gösterir. Ortalama tüketim YALNIZ motor
/// saati girilmiş ardışık dolumlardan hesaplanır — yoksa çizgi (—) görünür,
/// uydurma yok. Kayıtlar YALNIZ CİHAZDA durur ve HESABA bağlıdır: çıkışta
/// görünmez olur, aynı hesapla dönünce geri gelir (bakım kayıtları deseni).
library;

/// Tek dolum kaydı.
class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.dateMs,
    required this.liters,
    this.cost,
    this.engineHours,
    this.ownerUid,
  });

  final String id;

  /// Dolum günü (gün hassasiyeti — öğlen 12:00 sabitlenir, saat iddiası yok).
  final int dateMs;

  /// Alınan yakıt (litre) — tek zorunlu alan.
  final double liters;

  /// Ödenen tutar (kaptanın para birimi; isteğe bağlı, hesaba katılmaz).
  final double? cost;

  /// Dolum anındaki motor saati (isteğe bağlı) — ortalamanın tek kaynağı.
  final double? engineHours;

  /// HESAP KAPISI: kaydın sahibi; null = kapıdan önce girilmiş eski kayıt
  /// (ilk hesaplı açılışta sahiplenilir — bakım deseniyle aynı).
  final String? ownerUid;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': dateMs,
        'lt': liters,
        if (cost != null) 'cost': cost,
        if (engineHours != null) 'hrs': engineHours,
        if (ownerUid != null) 'owner': ownerUid,
      };

  /// Bozuk satır → null (çökme yok; satır sessizce atlanır).
  static FuelEntry? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? id = raw['id'] as String?;
    final int? date = raw['date'] as int?;
    final num? lt = raw['lt'] as num?;
    if (id == null || date == null || lt == null || lt <= 0) return null;
    return FuelEntry(
      id: id,
      dateMs: date,
      liters: lt.toDouble(),
      cost: (raw['cost'] as num?)?.toDouble(),
      engineHours: (raw['hrs'] as num?)?.toDouble(),
      ownerUid: raw['owner'] as String?,
    );
  }

  FuelEntry withOwner(String uid) => FuelEntry(
        id: id,
        dateMs: dateMs,
        liters: liters,
        cost: cost,
        engineHours: engineHours,
        ownerUid: uid,
      );
}

/// Yakıt deposu arayüzü — testte sahtesiyle değiştirilir.
abstract interface class FuelStore {
  Future<List<FuelEntry>> load();
  Future<void> save(List<FuelEntry> entries);
}

/// Bu yılın (sezonun) toplam litresi.
double fuelSeasonTotal(List<FuelEntry> entries, DateTime now) {
  double total = 0;
  for (final FuelEntry e in entries) {
    if (DateTime.fromMillisecondsSinceEpoch(e.dateMs).year == now.year) {
      total += e.liters;
    }
  }
  return total;
}

/// Ortalama tüketim (lt/motor saati) — DÜRÜST hesap: motor saati girilmiş
/// dolumlar saate göre sıralanır; ardışık her çift için "sonraki dolumun
/// litresi / saat farkı" alınır ve saatle ağırlıklandırılır (toplam litre /
/// toplam saat farkı). İki saatli kayıt yoksa null → arayüz '—' çizer.
double? fuelAvgPerHour(List<FuelEntry> entries) {
  final List<FuelEntry> hrs = entries
      .where((FuelEntry e) => e.engineHours != null)
      .toList(growable: false)
    ..sort((FuelEntry a, FuelEntry b) =>
        a.engineHours!.compareTo(b.engineHours!));
  double liters = 0;
  double hours = 0;
  for (int i = 1; i < hrs.length; i++) {
    final double delta = hrs[i].engineHours! - hrs[i - 1].engineHours!;
    if (delta <= 0) continue; // aynı/bozuk saat — çifte güvenilmez
    liters += hrs[i].liters;
    hours += delta;
  }
  if (hours <= 0) return null;
  return liters / hours;
}

/// Son dolumdan bu yana geçen tam gün (hiç dolum yoksa null).
int? fuelDaysSinceLast(List<FuelEntry> entries, DateTime now) {
  int? lastMs;
  for (final FuelEntry e in entries) {
    if (lastMs == null || e.dateMs > lastMs) lastMs = e.dateMs;
  }
  if (lastMs == null) return null;
  final int days =
      now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)).inDays;
  return days < 0 ? 0 : days;
}
