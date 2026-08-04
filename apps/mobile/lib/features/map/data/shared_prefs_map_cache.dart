import 'dart:convert';

import 'package:dockly_api/dockly_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/map_cache.dart';

/// `MapCache`'in `shared_preferences` uygulaması. Son başarılı harita yanıtını
/// JSON olarak cihazda saklar. Tüm işlemler en iyi çaba: hata olursa sessizce
/// geçer (ör. test ortamında eklenti yoksa) — uygulama akışı bozulmaz.
/// (Favoriler/tekne depolarıyla aynı desen.)
class SharedPrefsMapCache implements MapCache {
  const SharedPrefsMapCache();

  static const String _key = 'map_cache.v1';

  @override
  Future<CachedMap?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return decodeCachedMapJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(List<LocationPin> pins, List<Cluster> clusters) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = jsonEncode(<String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        // Anahtar adları DTO fromJson ile birebir (geri okuma aynı çözücüyle).
        'pins': <Map<String, dynamic>>[
          for (final LocationPin p in pins)
            <String, dynamic>{
              'id': p.id,
              'name': p.name,
              'type': p.type,
              'position': <String, double>{'lat': p.position.lat, 'lon': p.position.lon},
              'ratingAvg': p.ratingAvg,
              'priceTier': p.priceTier,
              'maxBoatLengthM': p.maxBoatLengthM,
              'maxDraftM': p.maxDraftM,
            },
        ],
        'clusters': <Map<String, dynamic>>[
          for (final Cluster c in clusters)
            <String, dynamic>{
              'position': <String, double>{'lat': c.position.lat, 'lon': c.position.lon},
              'count': c.count,
              'bbox': <double>[c.bbox.minLon, c.bbox.minLat, c.bbox.maxLon, c.bbox.maxLat],
              'countryCode': c.countryCode,
            },
        ],
      });
      await prefs.setString(_key, raw);
    } catch (_) {
      // en iyi çaba — sessizce geç
    }
  }
}

/// Önbellek/anlık-görüntü JSON'unu `CachedMap`'e çözer (ortak çözücü):
/// hem cihaz önbelleği (yukarıdaki `save` biçimi) hem uygulamayla gömülü gelen
/// `assets/map/map_snapshot.json` aynı şemayı kullanır. Bozuk girdi → null
/// (en iyi çaba — akış bozulmaz).
CachedMap? decodeCachedMapJson(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final List<LocationPin> pins =
        (decoded['pins'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(LocationPin.fromJson)
            .toList(growable: false);
    final List<Cluster> clusters =
        (decoded['clusters'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Cluster.fromJson)
            .toList(growable: false);
    final DateTime savedAt =
        DateTime.tryParse(decoded['savedAt'] as String? ?? '') ?? DateTime.now();
    return CachedMap(pins: pins, clusters: clusters, savedAt: savedAt);
  } catch (_) {
    return null;
  }
}
