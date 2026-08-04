import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import '../domain/map_cache.dart';
import 'shared_prefs_map_cache.dart';

/// Uygulamayla GÖMÜLÜ gelen harita anlık görüntüsü (perf, 2026-08).
///
/// `assets/map/map_snapshot.json`, yayınlı koy/marina kayıtlarından derleme
/// zamanında üretilen balon (cluster) özetidir — sayılar gerçek kayıt
/// sayılarıdır, uydurma veri yoktur. İLK ziyarette cihaz önbelleği henüz boş
/// olduğundan harita normalde ağ yanıtını bekler; bu görüntü sayesinde açılışta
/// ANINDA dolu görünür, taze veri gelince yerini bırakır (sıcak başlangıçla
/// aynı sözleşme). En iyi çaba: varlık okunamazsa null döner, akış bozulmaz.
class BundledMapSnapshot {
  const BundledMapSnapshot();

  static const String assetPath = 'assets/map/map_snapshot.json';

  Future<CachedMap?> load() async {
    // YALNIZ WEB (CI dersi, 2026-08): flutter test pubspec varlıklarını
    // GERÇEKTEN yükleyebildiği için gömülü görüntü VM testlerinde haritayı
    // beklenmedik şekilde doldurup determinizmi bozuyordu (20 kırmızı).
    // Web dışında (mobil dahil) kapalıdır: mobilde ilk açılış zaten mağaza
    // indirmesi sonrası tek seferdir; testler ise sahtesini override eder.
    if (!kIsWeb) return null;
    try {
      final String raw = await rootBundle.loadString(assetPath);
      return decodeCachedMapJson(raw);
    } catch (_) {
      return null;
    }
  }
}
