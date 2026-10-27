/// KAPTANIN GÜNLÜĞÜ — alan modeli (kullanıcı onayı 2026-08).
///
/// Girişler cihazda saklanır (misafir ilkesi); hesap senkronu ileriki faz.
/// Otomatik bağlam: giriş oluşturulurken aktif rota varsa adı/mesafesi/durak
/// sayısı yakalanır — kaptan yalnız hikâyeyi yazar.
library;

/// Günlük girişine iliştirilen rota bağlamı (o anki aktif rotadan).
class LogContext {
  const LogContext({required this.routeName, this.distanceNm, this.stops});

  final String routeName;
  final double? distanceNm;
  final int? stops;
}

class LogEntry {
  const LogEntry({
    required this.id,
    required this.dateMs,
    required this.text,
    this.title,
    this.ctxRoute,
    this.ctxNm,
    this.ctxStops,
    this.ownerUid,
  });

  final String id;

  /// HESAP KAPISI (saha hatası 2026-10-27, Defter paketi): girişin sahibi.
  /// null = kapıdan önce yazılmış eski giriş (ilk hesaplı açılışta sahiplenilir).
  final String? ownerUid;

  /// Girişin anı (ms, epoch) — liste en yeni başta sıralanır.
  final int dateMs;

  /// Kaptanın notu (zorunlu — boş giriş kaydedilmez).
  final String text;

  /// İsteğe bağlı başlık.
  final String? title;

  /// Otomatik rota bağlamı (giriş anında aktif rota varsa).
  final String? ctxRoute;
  final double? ctxNm;
  final int? ctxStops;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': dateMs,
        'text': text,
        if (title != null) 'title': title,
        if (ctxRoute != null) 'ctxRoute': ctxRoute,
        if (ctxNm != null) 'ctxNm': ctxNm,
        if (ctxStops != null) 'ctxStops': ctxStops,
        if (ownerUid != null) 'owner': ownerUid,
      };

  /// Bozuk kayıt → null (çökme yok; satır sessizce atlanır).
  static LogEntry? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? id = raw['id'] as String?;
    final int? date = raw['date'] as int?;
    final String? text = raw['text'] as String?;
    if (id == null || date == null || text == null || text.isEmpty) {
      return null;
    }
    return LogEntry(
      id: id,
      dateMs: date,
      text: text,
      title: raw['title'] as String?,
      ctxRoute: raw['ctxRoute'] as String?,
      ctxNm: (raw['ctxNm'] as num?)?.toDouble(),
      ctxStops: raw['ctxStops'] as int?,
      ownerUid: raw['owner'] as String?,
    );
  }

  /// Girişi hesaba bağlar (eski kayıt sahiplenme — kayıtlı rota deseni).
  LogEntry withOwner(String uid) {
    return LogEntry(
      id: id,
      dateMs: dateMs,
      text: text,
      title: title,
      ctxRoute: ctxRoute,
      ctxNm: ctxNm,
      ctxStops: ctxStops,
      ownerUid: uid,
    );
  }
}

/// Günlük deposu — testte sahte ile override edilir. En iyi çaba: asla
/// fırlatmaz; depolama yoksa uygulama bellek içi çalışmaya devam eder.
abstract interface class LogbookStore {
  Future<List<LogEntry>> load();
  Future<void> save(List<LogEntry> entries);
}
