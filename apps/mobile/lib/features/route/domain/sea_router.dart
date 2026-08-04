import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dockly_api/dockly_api.dart' show GeoPoint;

import '../data/sea_mask.dart';
import '../data/tr_coast_grid.dart';
import 'sea_route.dart';

/// AKILLI DENİZ ROTASI (2026-08, kullanıcı isteği: "yol tarifi uygulama
/// içinden, deniz rotası üzerinden"). Karaları tanıyan yol bulma algoritması
/// (A*) su/kara ızgarasında en kısa DENİZ yolunu arar — internetsiz çalışır,
/// gerçek verilerle deterministiktir (0-uydurma ilkesine uygun: harici servis
/// tahmini değil, kamu malı kıyı haritası üzerinde geometri).
///
/// GÜVENLİK SÖZLEŞMESİ: bu bir SEYİR PLANI DEĞİL, tahminî rota önizlemesidir.
/// Izgara ~500 m'dir; sığlık/yasak bölge bilmez. Arayüz her rotada "resmî
/// deniz haritalarını kullanın" uyarısını gösterir. Kıyılar bilinçli olarak
/// 1 hücre kalınlaştırıldığından çok dar geçitler kapalı sayılır; hedef koy
/// ızgarada kapalıysa rota koyun açığındaki EN YAKIN suya kadar hesaplanır
/// (`reachedGoal=false`) ve arayüz son yaklaşma uyarısı gösterir.
///
/// KARA ÜZERİNDEN ÇİZGİ YASAĞI (kaptan kuralı, 2026-08): İstanbul→Antalya
/// gibi dolambaçlı rotalarda dar arama penceresi boğazı (Çanakkale) dışarıda
/// bırakabiliyordu; motor "ulaşamadım" deyip kalan yolu düz çizgiyle
/// tamamlıyor ve çizgi KARADAN geçiyordu. Artık İKİ AŞAMA vardır:
/// 1) dar pencere (hızlı, kısa rotaların tamamı); 2) başarısızsa TÜM BÖLGE
/// taraması (boğazlar dahil). Hedefe yine ulaşılamazsa ve en yakın varış
/// 2 deniz milinden uzaksa rota HİÇ üretilmez (null) — kara üzerinden düz
/// çizgi ASLA çizilmez. 2 nm altındaki fark yalnız kapalı koy ağzıdır
/// (emniyet kalınlaştırması) ve son-yaklaşma notuyla gösterilir.
class SeaRoutePlan {
  const SeaRoutePlan({
    required this.points,
    required this.distanceNm,
    required this.reachedGoal,
    required this.viaSea,
  });

  /// Rota kırıklıkları (ilk nokta = başlangıç, son nokta = hedef).
  final List<GeoPoint> points;

  /// Toplam uzunluk (deniz mili) — kırıklıkların büyük-daire toplamı.
  final double distanceNm;

  /// Hedef hücresine ulaşıldı mı? false → rota koyun açığında biter,
  /// son bacak kuş uçuşudur (arayüz son-yaklaşma notu gösterir).
  final bool reachedGoal;

  /// true → kara tanıyan A* sonucu; false → kuş uçuşu (motor kullanılamadı).
  final bool viaSea;

  /// Varsayılan seyir hızında kaba süre (saat).
  double get etaHoursAtCruise => etaHours(distanceNm);
}

/// Kuş uçuşu yedek planı — motor yoksa/bölge dışıysa arayüz yine bilgi verir.
SeaRoutePlan directLinePlan(GeoPoint from, GeoPoint to) => SeaRoutePlan(
      points: <GeoPoint>[from, to],
      distanceNm: haversineNm(from, to),
      reachedGoal: true,
      viaSea: false,
    );

/// Kapalı koy ağzı toleransı (nm): hedefe bundan yakın kalınmışsa rota
/// "koyun açığına kadar" kabul edilir; uzaksa rota ÜRETİLMEZ (kara yasağı).
const double kCoastalApproachNm = 2.0;

/// `from` → `to` deniz rotası. İKİ AŞAMA: dar pencere → tam bölge.
/// Hedefe ulaşılamaz ve en yakın varış [kCoastalApproachNm]'den uzaksa null —
/// KARA ÜZERİNDEN düz çizgi asla üretilmez (kaptan kuralı).
SeaRoutePlan? planSeaRoute(
  SeaMask m,
  GeoPoint from,
  GeoPoint to, {
  int maxPop = 900000,
  TrCoastGrid? waters,
}) {
  if (!m.covers(from) || !m.covers(to)) return null;
  // KARADAKİ BAŞLANGIÇ (kaptan kuralı #2, 2026-08): kullanıcı karada (evde/
  // şehirde) olabilir — başlangıç, EN YAKIN kıyı suyuna oturtulur (~20 km'ye
  // kadar aranır) ve rota ORADAN başlar; karadaki ilk bacak ASLA çizilmez.
  final int? sIdxRaw =
      _snapToWater(m, m.colOf(from.lon), m.rowOf(from.lat), maxR: 40);
  final int? gIdxRaw = _snapToWater(m, m.colOf(to.lon), m.rowOf(to.lat));
  if (sIdxRaw == null || gIdxRaw == null) return null;
  final int sx = sIdxRaw % m.width, sy = sIdxRaw ~/ m.width;
  final int gx = gIdxRaw % m.width, gy = gIdxRaw ~/ m.width;

  // TÜRK KARASULARI TERCİHİ (kaptan kuralı #3): hedef Türk kıyısındaysa
  // (Türk karasına ≤ 3 nm ve Yunan tarafında değil) rota Yunan tarafına
  // geçmemeyi TERCİH eder (yumuşak maliyet — dar boğaz geçişleri yine
  // mümkündür). Hedef Yunan adasıysa tercih kapanır, geçiş serbesttir.
  final bool preferTr = waters != null &&
      waters.distTrNm(to) <= 3.0 &&
      !waters.greekSide(to);

  // 1. AŞAMA — dar pencere: kısa/orta rotaların tamamını milisaniyelerde çözer.
  final int margin =
      math.max(120, (math.max((sx - gx).abs(), (sy - gy).abs()) * 0.35).round());
  _Attempt res = _search(
    m, sx, sy, gx, gy,
    bx0: math.max(0, math.min(sx, gx) - margin),
    by0: math.max(0, math.min(sy, gy) - margin),
    bx1: math.min(m.width - 1, math.max(sx, gx) + margin),
    by1: math.min(m.height - 1, math.max(sy, gy) + margin),
    maxPop: maxPop,
    waters: preferTr ? waters : null,
  );

  // 2. AŞAMA — dar pencere hedefe ulaşamadıysa TÜM BÖLGE (boğazlar dahil).
  // İstanbul→Antalya gibi rotalar Çanakkale'den ancak böyle geçer.
  // İstisna: hedefe zaten ≤ tolerans kadar yaklaşıldıysa bu KAPALI KOY
  // ağzıdır (emniyet kalınlaştırması) — tam tarama boşuna koşturulmaz.
  if (!res.reached && res.bestGapNm > kCoastalApproachNm) {
    final _Attempt full = _search(
      m, sx, sy, gx, gy,
      bx0: 0, by0: 0, bx1: m.width - 1, by1: m.height - 1,
      maxPop: 2600000,
      waters: preferTr ? waters : null,
    );
    if (full.reached || full.bestGapNm < res.bestGapNm) res = full;
  }

  // KARA YASAĞI: hedefe ulaşılamadıysa yalnız kapalı-koy toleransı kadar
  // (≤ 2 nm) açık bırakılabilir; daha uzaksa rota YOK (düz çizgi çizilmez).
  if (!res.reached && res.bestGapNm > kCoastalApproachNm) return null;
  if (res.px.isEmpty) return null;

  // Görüş-hattı sadeleştirme: ardışık kırıklıklar, aradaki tüm hücreler su
  // kaldığı sürece birleştirilir (süpürme çizgisi kara bilmezse köşe kalır).
  final List<int> px = res.px, py = res.py;
  // Başlangıç karadaysa çizgi SUDAN başlar (ilk hücre merkezi) — karadaki
  // eve/şehre çizgi çekilmez; kaptan denizdeyse gerçek konum kullanılır.
  final bool fromOnWater = m.isWater(m.colOf(from.lon), m.rowOf(from.lat));
  final List<GeoPoint> pts = <GeoPoint>[
    if (fromOnWater) from else m.centerOf(sx, sy),
  ];
  int anchor = 0;
  for (int i = 1; i < px.length; i++) {
    final bool last = i == px.length - 1;
    if (!last && _clearLine(m, px[anchor], py[anchor], px[i + 1], py[i + 1])) {
      continue; // bir sonraki de görünüyor — bu kırıklık gereksiz
    }
    pts.add(m.centerOf(px[i], py[i]));
    anchor = i;
  }
  // Hedef işareti kıyıda/az içerideyse çizgi işarete bağlanır (görsel bağ);
  // işaret denizden 1,2 nm'den uzaktaysa çizgi SUDA biter (kara yasağı).
  final GeoPoint goalCenter = m.centerOf(gx, gy);
  final bool toOnWater = m.isWater(m.colOf(to.lon), m.rowOf(to.lat));
  if (toOnWater || haversineNm(goalCenter, to) <= 1.2) {
    pts.add(to);
  } else {
    pts.add(goalCenter);
  }

  double dist = 0;
  for (int i = 1; i < pts.length; i++) {
    dist += haversineNm(pts[i - 1], pts[i]);
  }
  return SeaRoutePlan(
    points: pts,
    distanceNm: dist,
    reachedGoal: res.reached,
    viaSea: true,
  );
}

/// Tek A* koşusunun sonucu: hücre yolu + hedefe kalan en küçük mesafe.
class _Attempt {
  const _Attempt({
    required this.reached,
    required this.px,
    required this.py,
    required this.bestGapNm,
  });

  final bool reached;
  final List<int> px, py;
  final double bestGapNm;
}

/// Verilen kutu içinde A* araması. Hedefe ulaşamazsa hedefe EN YAKIN düğüme
/// giden yolu döndürür (bestGapNm = o düğüm ile hedef arası nm).
_Attempt _search(
  SeaMask m,
  int sx,
  int sy,
  int gx,
  int gy, {
  required int bx0,
  required int by0,
  required int bx1,
  required int by1,
  required int maxPop,
  TrCoastGrid? waters,
}) {
  final int bw = bx1 - bx0 + 1, bh = by1 - by0 + 1;
  final int n = bw * bh;

  // Float32 yeter (nm toplamları) — TAM BÖLGE koşusunda belleği yarılar.
  final Float32List gScore = Float32List(n)..fillRange(0, n, double.infinity);
  final Int32List cameFrom = Int32List(n)..fillRange(0, n, -1);
  final Uint8List closed = Uint8List(n);
  final _Heap heap = _Heap(math.min(n ~/ 8 + 64, 400000));

  int local(int x, int y) => (y - by0) * bw + (x - bx0);
  final double goalLat = m.latAt(gy), goalLon = m.lonAt(gx);
  final double hCos =
      math.cos(((m.latAt(sy) + goalLat) / 2) * math.pi / 180.0);

  // Hızlı sezgisel (eşdikdörtgen yaklaşımı, %1 emniyet payıyla küçültülmüş —
  // A* eniyiliği bozulmaz): tam bölge taramasında haversine'den kat kat ucuz.
  double hOf(int x, int y) {
    final double dLat = (m.latAt(y) - goalLat) * 60.0;
    final double dLon = (m.lonAt(x) - goalLon) * 60.0 * hCos;
    return math.sqrt(dLat * dLat + dLon * dLon) * 0.99;
  }

  final Float32List lonNmRow = Float32List(bh);
  final double latNm = 60.0 * m.res;
  for (int r = 0; r < bh; r++) {
    lonNmRow[r] = latNm * math.cos(m.latAt(by0 + r) * math.pi / 180.0);
  }

  final int start = local(sx, sy), goal = local(gx, gy);
  gScore[start] = 0;
  heap.push(hOf(sx, sy), start);

  int pops = 0;
  int best = start;
  double bestH = hOf(sx, sy);
  bool reached = false;

  while (heap.isNotEmpty) {
    final int cur = heap.pop();
    if (closed[cur] == 1) continue;
    closed[cur] = 1;
    if (cur == goal) { reached = true; break; }
    if (++pops > maxPop) break;
    final int cx = bx0 + cur % bw, cy = by0 + cur ~/ bw;
    final double hCur = hOf(cx, cy);
    if (hCur < bestH) { bestH = hCur; best = cur; }
    final int r = cur ~/ bw;
    final double ew = lonNmRow[r];
    final double diag = math.sqrt(latNm * latNm + ew * ew);
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final int nx = cx + dx, ny = cy + dy;
        if (nx < bx0 || nx > bx1 || ny < by0 || ny > by1) continue;
        if (m.isLand(nx, ny)) continue;
        // Köşe kesme yasak: çapraz geçişte iki dik komşu da su olmalı
        // (iki kara hücresinin arasından "sızma" olmaz — emniyet).
        if (dx != 0 && dy != 0 && (m.isLand(cx + dx, cy) || m.isLand(cx, cy + dy))) {
          continue;
        }
        final int ni = local(nx, ny);
        if (closed[ni] == 1) continue;
        double step = (dx == 0) ? latNm : (dy == 0 ? ew : diag);
        // KIYIDAN KADEMELİ KAÇINMA (kaptan kuralı): kara komşusu olan hücreye
        // güçlü, iki hücre yakınına hafif ceza — rota mecbur kalmadıkça kıyıyı
        // yalamaz, açık sudan dolaşır. Dar geçitler yine geçilebilir.
        if (m.isLand(nx + 1, ny) || m.isLand(nx - 1, ny) ||
            m.isLand(nx, ny + 1) || m.isLand(nx, ny - 1)) {
          step += latNm * 0.35;
        } else if (m.isLand(nx + 2, ny) || m.isLand(nx - 2, ny) ||
            m.isLand(nx, ny + 2) || m.isLand(nx, ny - 2)) {
          step += latNm * 0.12;
        }
        // TÜRK KARASULARI TERCİHİ: Yunan tarafındaki hücreye geçiş pahalıdır
        // (yasak değil — dar boğazlarda kısa geçişler yine yapılabilir).
        if (waters != null && waters.greekSideAt(m.latAt(ny), m.lonAt(nx))) {
          step += latNm * 0.6;
        }
        final double tentative = gScore[cur] + step;
        if (tentative < gScore[ni]) {
          gScore[ni] = tentative;
          cameFrom[ni] = cur;
          heap.push(tentative + hOf(nx, ny), ni);
        }
      }
    }
  }

  final int endNode = reached ? goal : best;
  if (!reached && endNode == start) {
    return const _Attempt(
        reached: false, px: <int>[], py: <int>[], bestGapNm: double.infinity);
  }
  final List<int> cellsX = <int>[], cellsY = <int>[];
  int cur = endNode;
  while (cur != -1) {
    cellsX.add(bx0 + cur % bw);
    cellsY.add(by0 + cur ~/ bw);
    cur = cameFrom[cur];
  }
  final double gap = reached
      ? 0
      : haversineNm(
          m.centerOf(bx0 + endNode % bw, by0 + endNode ~/ bw),
          m.centerOf(gx, gy),
        );
  return _Attempt(
    reached: reached,
    px: cellsX.reversed.toList(growable: false),
    py: cellsY.reversed.toList(growable: false),
    bestGapNm: gap,
  );
}

/// En yakın su hücresi (kare halkalarla, ~5 km'ye kadar). Bulunamazsa null.
int? _snapToWater(SeaMask m, int cx, int cy, {int maxR = 10}) {
  if (m.isWater(cx, cy)) return cy * m.width + cx;
  for (int r = 1; r <= maxR; r++) {
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx.abs() != r && dy.abs() != r) continue; // yalnız halka
        final int nx = cx + dx, ny = cy + dy;
        if (m.isWater(nx, ny)) return ny * m.width + nx;
      }
    }
  }
  return null;
}

/// İki hücre arasındaki süpürme (supercover) çizgisi tamamen su mu?
bool _clearLine(SeaMask m, int x0, int y0, int x1, int y1) {
  int dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
  int x = x0, y = y0;
  final int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  int err = dx - dy;
  while (true) {
    if (m.isLand(x, y)) return false;
    if (x == x1 && y == y1) return true;
    final int e2 = 2 * err;
    // Süpürme: köşe geçişinde İKİ ara hücre de denetlenir (sızma olmaz).
    if (e2 > -dy && e2 < dx) {
      if (m.isLand(x + sx, y) || m.isLand(x, y + sy)) return false;
    }
    if (e2 > -dy) { err -= dy; x += sx; }
    if (e2 < dx) { err += dx; y += sy; }
  }
}

/// Küçük ikili yığın (min-heap) — (öncelik, düğüm) çiftleri.
class _Heap {
  _Heap(int cap)
      : _f = Float64List(math.max(64, cap)),
        _v = Int32List(math.max(64, cap));

  Float64List _f;
  Int32List _v;
  int _n = 0;

  bool get isNotEmpty => _n > 0;

  void push(double f, int v) {
    if (_n == _f.length) {
      final Float64List nf = Float64List(_f.length * 2)..setRange(0, _n, _f);
      final Int32List nv = Int32List(_v.length * 2)..setRange(0, _n, _v);
      _f = nf; _v = nv;
    }
    int i = _n++;
    _f[i] = f; _v[i] = v;
    while (i > 0) {
      final int p = (i - 1) >> 1;
      if (_f[p] <= _f[i]) break;
      _swap(i, p); i = p;
    }
  }

  int pop() {
    final int top = _v[0];
    _n--;
    if (_n > 0) {
      _f[0] = _f[_n]; _v[0] = _v[_n];
      int i = 0;
      while (true) {
        final int l = 2 * i + 1, r = l + 1;
        int s = i;
        if (l < _n && _f[l] < _f[s]) s = l;
        if (r < _n && _f[r] < _f[s]) s = r;
        if (s == i) break;
        _swap(i, s); i = s;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final double tf = _f[a]; _f[a] = _f[b]; _f[b] = tf;
    final int tv = _v[a]; _v[a] = _v[b]; _v[b] = tv;
  }
}
