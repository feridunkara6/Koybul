/// ÇOK DURAKLI DENİZ ROTASI (ROTA DÜZENLEME 2026-08, kullanıcı onaylı):
/// rota artık sıralı ARA NOKTALARDAN oluşur — kaptan çizgiyi tutamaçla
/// kaydırabilir (isimsiz ara nokta) ya da bir koyu DURAK olarak ekleyebilir
/// (isimli ara nokta). Her bacak aynı A* motoruyla, aynı kaptan kurallarıyla
/// (kara yasağı + Türk karasuları tercihi) hesaplanır. Saf model + saf
/// birleştirme — motor ve arayüzden bağımsız, birim testli.
library;

import 'package:dockly_api/dockly_api.dart' show GeoPoint;

import 'sea_route.dart';
import 'sea_router.dart';

/// Rotanın BAŞLANGICI (rota planlama 2026-08, kullanıcı onaylı): kullanıcının
/// GPS konumu ([isDevice] true) YA DA haritadan/koydan seçilen A noktası —
/// sefer planı konumdan bağımsız da kurulabilir.
class RouteOrigin {
  const RouteOrigin({required this.pos, this.name, this.isDevice = false});

  final GeoPoint pos;

  /// Koy adı (başlangıç bir koy ise); serbest nokta/konum için null.
  final String? name;

  /// true → paylaşılan GPS konumu ("Konumum").
  final bool isDevice;
}

/// Rotadaki tek ara nokta. [name] doluysa bu bir DURAK (koy — çipte listelenir);
/// null ise tutamaçla eklenen serbest ara noktadır (yalnız haritada görünür).
class RouteWaypoint {
  const RouteWaypoint({required this.pos, this.id, this.name});

  final GeoPoint pos;

  /// Koy kimliği (durak ise dolu) — rüzgâr analizi ve tekrar-ekleme koruması.
  final String? id;

  /// Koy adı (durak ise dolu) — rota çipindeki durak listesi.
  final String? name;

  bool get isStop => name != null;
}

/// Çok bacaklı yolculuk: bacak planları + arayüzün çizdiği birleşik plan.
class SeaTrip {
  const SeaTrip({required this.legs, required this.combined});

  final List<SeaRoutePlan> legs;
  final SeaRoutePlan combined;
}

/// Bacak planlarını tek çizilebilir plana birleştirir. Tek bacak AYNEN döner
/// (kimlik korunur — durum karşılaştırmaları `identical` ile çalışır).
/// Bitişik bacakların ortak eklem noktası bir kez alınır; mesafe toplamdır;
/// `reachedGoal` tüm bacaklar hedefine ulaştıysa true (aksi hâlde arayüz
/// son-yaklaşma uyarısını gösterir).
SeaRoutePlan combineTripLegs(List<SeaRoutePlan> legs) {
  assert(legs.isNotEmpty, 'en az bir bacak gerekli');
  if (legs.length == 1) return legs.single;
  final List<GeoPoint> points = <GeoPoint>[...legs.first.points];
  double distance = legs.first.distanceNm;
  for (int i = 1; i < legs.length; i++) {
    final SeaRoutePlan leg = legs[i];
    final List<GeoPoint> p = leg.points;
    final GeoPoint last = points.last;
    final int startAt =
        (p.isNotEmpty && p.first.lat == last.lat && p.first.lon == last.lon) ? 1 : 0;
    points.addAll(p.sublist(startAt));
    distance += leg.distanceNm;
  }
  return SeaRoutePlan(
    points: points,
    distanceNm: distance,
    reachedGoal: legs.every((SeaRoutePlan l) => l.reachedGoal),
    viaSea: legs.every((SeaRoutePlan l) => l.viaSea),
  );
}

/// Yeni durağın rotada EN MANTIKLI yerini bulur: durak, toplam kuş-uçuşu
/// sapmayı (önceki→durak→sonraki − önceki→sonraki) en aza indiren bacağa
/// sokulur. Dönen değer, `waypoints` listesine ekleme dizinidir
/// (0 = ilk bacağa; asla son duraktan — hedeften — SONRAYA eklenmez).
int bestStopInsertIndex(GeoPoint origin, List<GeoPoint> waypoints, GeoPoint stop) {
  assert(waypoints.isNotEmpty, 'rotada en az hedef olmalı');
  int best = 0;
  double bestCost = double.infinity;
  GeoPoint prev = origin;
  for (int i = 0; i < waypoints.length; i++) {
    final GeoPoint next = waypoints[i];
    final double cost =
        haversineNm(prev, stop) + haversineNm(stop, next) - haversineNm(prev, next);
    if (cost < bestCost) {
      bestCost = cost;
      best = i;
    }
    prev = next;
  }
  return best;
}
