import 'dart:async';
import 'dart:math' as math;

import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Açılış (splash) kapısı — KOYBUL "Marka Yüzeyi" tasarımı (2026-08, kullanıcı
/// seçimi: konsept A). Fotoğraf YOK: yüzey tamamen koddan çizilir — her ekran
/// boyutunda (telefon/tablet/bilgisayar, dikey/yatay) kusursuz ölçeklenir ve
/// ~900 KB görsel yükünü ortadan kaldırır (açılış hızlanır).
///
/// GÜNDÜZ/GECE duyarlılığı korunur: 07:00-19:00 aydınlık yüzey, sonrası derin
/// lacivert. Açılış ekranı hâlâ görünürken alttaki uygulamanın "beklemesi"
/// gereken işler (karşılama sorusu gibi) bu sağlayıcıyı dinler. Varsayılan
/// TRUE: SplashGate KULLANILMADAN kurulan ağaçlarda (testler) hiçbir şey
/// beklemez; SplashGate açılışta false yapar, bitince true'ya çevirir.
final StateProvider<bool> splashDoneProvider = StateProvider<bool>((ref) => true);

class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({
    required this.child,
    // 1500ms: kullanıcı isteği (açılış hızlansın) — marka animasyonu korunur
    // ama bekletmez.
    this.duration = const Duration(milliseconds: 1500),
    this.now,
    super.key,
  });

  final Widget child;

  /// Açılış ekranının minimum görünme süresi (testte kısaltılır).
  final Duration duration;

  /// Saat kaynağı — testte sabitlenir; null → [DateTime.now].
  final DateTime Function()? now;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

/// Gece kabulü: 19:00 dahil sonrası ya da 07:00 öncesi ("hava kararınca").
bool splashIsNight(DateTime t) => t.hour >= 19 || t.hour < 7;

class _SplashGateState extends ConsumerState<SplashGate> {
  Timer? _timer;
  Timer? _removeTimer;
  bool _done = false; // süre doldu → kararma başlar
  bool _gone = false; // kararma bitti → açılış ağaçtan kalkar

  @override
  void initState() {
    super.initState();
    // PERF (algılanan hız): uygulama açılış ekranının ARKASINDA hemen kurulur;
    // harita, karolar ve veri splash oynarken yüklenir — kararma bittiğinde
    // kullanıcı HAZIR bir haritayla karşılaşır (soğuk başlangıç kasması biter).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(splashDoneProvider.notifier).state = false;
    });
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      setState(() => _done = true);
      ref.read(splashDoneProvider.notifier).state = true;
      // Kararma animasyonu bitince açılış katmanı tamamen kaldırılır
      // (animasyon denetleyicileri dursun — arka planda boşa iş yapmasın).
      _removeTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _gone = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime t = (widget.now ?? DateTime.now)();
    final bool night = splashIsNight(t);
    // TEK-RESSAM KURALI (kullanıcı kararı 2026-08): WEB'de açılışı yalnız
    // index.html'deki katman çizer; Flutter web'de İKİNCİ bir açılış çizmez.
    // Böylece devralma diye bir an kalmaz — logonun oynaması/boyut
    // değiştirmesi kategorik olarak imkânsızdır. iOS/Android'de HTML katmanı
    // olmadığından BrandSplash orada tek ressam olarak çalışmayı sürdürür.
    // Zamanlayıcı her platformda korunur (splashDoneProvider sözleşmesi).
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (!_gone && !kIsWeb)
          IgnorePointer(
            ignoring: _done,
            child: AnimatedOpacity(
              opacity: _done ? 0 : 1,
              duration: const Duration(milliseconds: 450),
              // TEK tasarım her cihazda: marka yüzeyi kendini ekrana ölçekler.
              child: BrandSplash(night: night),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// KOYBUL MARKA YÜZEYİ — logoyla aynı dili konuşan sade kurumsal açılış.
// BOYUT SÖZLEŞMESİ (kullanıcı kararı 2026-08): işaret yüksekliği HER YERDE
// aynı formülle hesaplanır → clamp(ekranın kısa kenarı × 0.30, 130, 220).
// Web ön-açılışı (index.html) CSS'te BİREBİR aynı formülü kullanır
// (clamp(130px, 30vmin, 220px)) — devralma anında logo asla büyümez/küçülmez.
// TEK animasyon: dalga üzerinde giden yelkenli (yükleme göstergesi).
// =============================================================================

/// Paylaşılan boyut formülü — index.html'deki CSS clamp ile birebir.
double koybulMarkHeight(Size screen) =>
    (math.min(screen.width, screen.height) * 0.30).clamp(130.0, 220.0);

class BrandSplash extends StatefulWidget {
  const BrandSplash({required this.night, super.key});

  final bool night;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  /// Yelkenlinin dalga üzerindeki yolculuğu (tek ve sürekli animasyon).
  late final AnimationController _sail = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _sail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool night = widget.night;
    // Konsept A renkleri (marka sayfasıyla hizalı).
    final List<Color> bg = night
        ? const <Color>[Color(0xFF0B1220), Color(0xFF0E3052)]
        : const <Color>[Color(0xFFF7FAFD), Color(0xFFE9F2F9)];
    final Color ink = night ? const Color(0xFFF2F5F9) : DocklyColors.brandDeep;
    final Color slogan = night ? const Color(0xFF93A1B8) : const Color(0xFF5B6B84);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bg,
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double markH =
                koybulMarkHeight(Size(c.maxWidth, c.maxHeight));
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Align(
                  alignment: const Alignment(0, -0.30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: markH,
                        height: markH,
                        child: CustomPaint(
                          key: const ValueKey<String>('koybul-mark'),
                          painter: KoybulMarkPainter(night: night),
                        ),
                      ),
                      SizedBox(height: markH * 0.169),
                      Text(
                        'Koybul',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: markH * 0.354,
                          letterSpacing: -0.5,
                          height: 1.0,
                          color: ink,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: markH * 0.077),
                      Text(
                        'Denizde yerini bul.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: markH * 0.131,
                          height: 1.0,
                          color: slogan,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.82),
                  child: _SailWaveLoader(
                    anim: _sail,
                    width: markH * 1.15,
                    ink: ink,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Koybul işareti — marka sayfasındaki vektörün birebir Dart karşılığı.
/// Gündüz: lacivert gövde + beyaz disk; gece: beyaz gövde + lacivert disk;
/// yelken her zaman Ege turkuazı.
class KoybulMarkPainter extends CustomPainter {
  KoybulMarkPainter({required this.night});

  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.height / 78.0; // birim uzayı 10..88 → yükseklik
    final double ox = size.width / 2 - 50 * s;
    final double oy = size.height / 2 - 49 * s;
    Offset t(double x, double y) => Offset(x * s + ox, y * s + oy);

    final Color body = night ? const Color(0xFFF2F5F9) : DocklyColors.brandDeep;
    final Color disc = night ? DocklyColors.brandDeep : Colors.white;
    final Color wave = body;
    const Color sail = DocklyColors.accentTurquoise;

    // Gövde: mercek + iğne sentezi.
    final Path bodyPath = Path()
      ..moveTo(t(50, 10).dx, t(50, 10).dy)
      ..cubicTo(t(66.6, 10).dx, t(66.6, 10).dy, t(80, 23.4).dx, t(80, 23.4).dy,
          t(80, 40).dx, t(80, 40).dy)
      ..cubicTo(t(80, 51.5).dx, t(80, 51.5).dy, t(73.5, 61.5).dx,
          t(73.5, 61.5).dy, t(64, 66.5).dx, t(64, 66.5).dy)
      ..lineTo(t(52.5, 86).dx, t(52.5, 86).dy)
      ..cubicTo(t(51.4, 87.9).dx, t(51.4, 87.9).dy, t(48.6, 87.9).dx,
          t(48.6, 87.9).dy, t(47.5, 86).dx, t(47.5, 86).dy)
      ..lineTo(t(36, 66.5).dx, t(36, 66.5).dy)
      ..cubicTo(t(26.5, 61.5).dx, t(26.5, 61.5).dy, t(20, 51.5).dx,
          t(20, 51.5).dy, t(20, 40).dx, t(20, 40).dy)
      ..cubicTo(t(20, 23.4).dx, t(20, 23.4).dy, t(33.4, 10).dx, t(33.4, 10).dy,
          t(50, 10).dx, t(50, 10).dy)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = body);

    // İç disk.
    canvas.drawCircle(t(50, 40), 20 * s, Paint()..color = disc);

    // Su çizgisi: (36.5,45.5)-(63.5,45.5) alt yayı — merkez (50,24.72) r 24.78.
    final Rect waveRect = Rect.fromCircle(center: t(50, 24.72), radius: 24.78 * s);
    final Paint wavePaint = Paint()
      ..color = wave
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6 * s
      ..strokeCap = StrokeCap.round;
    const double a1 = 2.1467; // atan2(20.78, -13.5)
    const double a2 = 0.9946; // atan2(20.78, 13.5)
    canvas.drawArc(waveRect, a1, a2 - a1, false, wavePaint);

    // Yelken.
    final Path sailPath = Path()
      ..moveTo(t(49, 24.5).dx, t(49, 24.5).dy)
      ..cubicTo(t(54.5, 29.5).dx, t(54.5, 29.5).dy, t(58.5, 35).dx,
          t(58.5, 35).dy, t(59.5, 41.5).dx, t(59.5, 41.5).dy)
      ..lineTo(t(49, 41.5).dx, t(49, 41.5).dy)
      ..close();
    canvas.drawPath(sailPath, Paint()..color = sail);
  }

  @override
  bool shouldRepaint(KoybulMarkPainter oldDelegate) => oldDelegate.night != night;
}

/// Yükleme göstergesi: dalga üzerinde SOLDAN SAĞA giden minik yelkenli —
/// açılıştaki TEK animasyon (kullanıcı kararı 2026-08). Yelken, logodaki
/// yelkenin küçüğüdür; gövde logodaki su yayının küçüğü — marka tutarlı.
class _SailWaveLoader extends StatelessWidget {
  const _SailWaveLoader({
    required this.anim,
    required this.width,
    required this.ink,
  });

  final Animation<double> anim;
  final double width;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const ValueKey<String>('splash-sail'),
      animation: anim,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          size: Size(width, width * 0.30),
          painter: _SailWavePainter(t: anim.value, ink: ink),
        );
      },
    );
  }
}

class _SailWavePainter extends CustomPainter {
  _SailWavePainter({required this.t, required this.ink});

  final double t;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double amp = size.height * 0.13; // dalga genliği
    final double baseY = size.height * 0.66;
    double waveY(double x) => baseY + amp * math.sin(2 * math.pi * 2 * x / w);

    // Dalga: iki tam periyotluk sakin sinüs (statik — animasyon teknede).
    final Path wavePath = Path()..moveTo(0, waveY(0));
    for (double x = 2; x <= w; x += 2) {
      wavePath.lineTo(x, waveY(x));
    }
    canvas.drawPath(
      wavePath,
      Paint()
        ..color = ink.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // Tekne: dalga boyunca yol alır; eğim dalganın türevinden gelir (bata
    // çıka gerçekçi ilerler). Uçlarda yumuşak görünüp kaybolur.
    final double bx = w * (0.04 + 0.92 * t);
    final double by = waveY(bx);
    final double slope =
        amp * (4 * math.pi / w) * math.cos(2 * math.pi * 2 * bx / w);
    final double angle = math.atan(slope) * 0.85;
    final double edge = math.min(t, 1 - t);
    final double fade = (edge / 0.12).clamp(0.0, 1.0);

    final double k = size.height * 0.052; // tekne ölçeği
    canvas.save();
    canvas.translate(bx, by - 1.5);
    canvas.rotate(angle);
    // Yelken (logodaki yelkenin oranlarıyla).
    final Path sail = Path()
      ..moveTo(0, -12 * k)
      ..cubicTo(4.6 * k, -8.2 * k, 8.2 * k, -3.6 * k, 9 * k, -1.2 * k)
      ..lineTo(0, -1.2 * k)
      ..close();
    canvas.drawPath(
      sail,
      Paint()..color = DocklyColors.accentTurquoise.withValues(alpha: fade),
    );
    // Gövde: logodaki su yayının minik yankısı.
    final Path hull = Path()
      ..moveTo(-8 * k, 0)
      ..quadraticBezierTo(0, 5 * k, 8 * k, 0);
    canvas.drawPath(
      hull,
      Paint()
        ..color = ink.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SailWavePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.ink != ink;
}
