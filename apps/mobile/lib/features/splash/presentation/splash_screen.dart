import 'dart:async';
import 'dart:math' as math;

import 'package:dockly_ui/dockly_ui.dart';
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
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (!_gone)
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
// KOYBUL MARKA YÜZEYİ — logoyla aynı dili konuşan sade kurumsal açılış:
// degrade zemin + hayalet su-yayı halkaları + Koybul işareti + yazı + yükleme
// noktaları. Public: testler gündüz/gece varyantını `night` alanından doğrular.
// =============================================================================

class BrandSplash extends StatefulWidget {
  const BrandSplash({required this.night, super.key});

  final bool night;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  /// Yükleme noktalarının nabzı (sürekli, yumuşak).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
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
    final Color dotPassive =
        night ? const Color(0xFF243A54) : const Color(0xFFC8D6E4);
    final Color halo = night ? const Color(0x0DFFFFFF) : const Color(0x100A2540);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bg,
          ),
        ),
        // SABİT BOYUT (kullanıcı kararı 2026-08): işaret HER ekranda 130px,
        // yazılar 46/17px — web ön-açılışıyla birebir aynı ölçüler. Böylece
        // Flutter devraldığı an hiçbir öğe büyümez/kıpırdamaz.
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Align(
              alignment: const Alignment(0, -0.30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // Hayalet halkalar: logodaki su yayının dev yankıları.
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _HaloArcsPainter(color: halo),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            key: const ValueKey<String>('koybul-mark'),
                            painter: KoybulMarkPainter(night: night),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Koybul',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 46,
                      letterSpacing: -0.5,
                      height: 1.0,
                      color: ink,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Denizde yerini bul.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: 17,
                      height: 1.0,
                      color: slogan,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.80),
              child: _LoadingDots(pulse: _pulse, passive: dotPassive),
            ),
          ],
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

/// Hayalet halkalar: işaretin su yayının dev, çok soluk yankıları — zemine
/// derinlik verir, dikkati dağıtmaz (%5 civarı görünürlük).
class _HaloArcsPainter extends CustomPainter {
  _HaloArcsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Yay merkezi: işaretin disk merkezi (birim 40; widget merkezi birim 49).
    final Offset center = Offset(
      size.width / 2,
      size.height / 2 - size.height * (9 / 78),
    );
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final double f in <double>[1.7, 2.2, 2.7]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.height * f),
        0.4363, // 25°
        2.2689, // 130° süpürme — alt yay (logodaki su çizgisiyle aynı aile)
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_HaloArcsPainter oldDelegate) => oldDelegate.color != color;
}

/// Üç noktalı yükleme göstergesi — turkuaz nabız, soldan sağa akar.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.pulse, required this.passive});

  final Animation<double> pulse;
  final Color passive;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const ValueKey<String>('splash-dots'),
      animation: pulse,
      builder: (BuildContext context, Widget? _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 3; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    passive,
                    DocklyColors.accentTurquoise,
                    _wave(pulse.value, i),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Nokta i için 0..1 nabız değeri — faz kaydırmalı yumuşak sinüs.
  static double _wave(double t, int i) {
    final double x = (t - i * 0.28) * 2 * math.pi;
    return 0.5 + 0.5 * math.sin(x);
  }
}
