import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/sign_in_screen.dart';

/// KARŞILAMA EKRANI — E2 (onaylı tasarım 2026-08).
///
/// Tek ekran, kaydırmalı tanıtım sayfası YOK: kavisli deniz illüstrasyonu,
/// iki renkli başlık, üç değer satırı, tek birincil CTA. Kayıt duvarı yok —
/// "Giriş yap" köşede seçenektir ve akışı TAMAMLAMAZ (dönünce kaldığı
/// yerden sürer). Sosyal kanıt rakamı bilerek yok: 0 uydurma veri kuralı.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({required this.onStart, super.key});

  /// "Keşfe başla" — karar cihaza işlenir, kabuğa geçilir.
  final VoidCallback onStart;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /// Giriş animasyonu: değer satırları 60 ms arayla aşağıdan süzülür
  /// (onaylı animasyon notu). Tek yönlü, tekrar etmez — testler beklemez.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Erişilebilirlik: hareket azaltma açıksa animasyon atlanır.
      if (MediaQuery.of(context).disableAnimations) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// Satır için kademeli süzülme: [i] 0..4 → gecikmeli aralık.
  /// CI DERSİ: Interval'ın sonu 1.0'ı AŞAMAZ (assert) — katsayılar son
  /// öğe (i=4) tam 1.0'da bitecek şekilde seçildi: 0.48..1.00.
  Widget _rise(int i, Widget child) {
    final Animation<double> a = CurvedAnimation(
      parent: _enter,
      curve: Interval(0.12 * i, 0.52 + 0.12 * i, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey<String>('launch-welcome'),
      backgroundColor: DocklyColors.bgBase,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double heroH = (c.maxHeight * 0.34).clamp(180.0, 320.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                children: <Widget>[
                  // Kavisli deniz illüstrasyonu (koddan çizim — görsel yükü 0).
                  SizedBox(
                    height: heroH,
                    width: double.infinity,
                    child: const CustomPaint(painter: _HeroSeaPainter()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      children: <Widget>[
                        _rise(
                          0,
                          Column(
                            children: <Widget>[
                              Text(
                                t.launchTitleA,
                                textAlign: TextAlign.center,
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DocklyColors.text1,
                                ),
                              ),
                              Text(
                                t.launchTitleB,
                                textAlign: TextAlign.center,
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DocklyColors.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _rise(
                          1,
                          _ValueRow(
                            icon: DocklyIcons.place,
                            tint: DocklyColors.accentTurquoise,
                            label: t.launchVal1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _rise(
                          2,
                          _ValueRow(
                            icon: DocklyIcons.navigation,
                            tint: DocklyColors.brandPrimary,
                            label: t.launchVal2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _rise(
                          3,
                          _ValueRow(
                            icon: DocklyIcons.star,
                            tint: DocklyColors.warning,
                            label: t.launchVal3,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _rise(
                          4,
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const ValueKey<String>('launch-start'),
                              style: FilledButton.styleFrom(
                                backgroundColor: DocklyColors.brandPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              onPressed: widget.onStart,
                              child: Text(
                                t.launchCta,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // "Giriş yap" akışı TAMAMLAMAZ — dönünce devam edilir.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              t.launchHaveAccount,
                              style: text.bodyMedium
                                  ?.copyWith(color: DocklyColors.text2),
                            ),
                            TextButton(
                              key: const ValueKey<String>('launch-signin'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        const SignInScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                t.signInBtn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: DocklyColors.brandPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.launchGuestNote,
                          textAlign: TextAlign.center,
                          style: text.bodySmall
                              ?.copyWith(color: DocklyColors.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Değer satırı: renkli ikon rozeti + tek satır metin (onaylı E2 düzeni).
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.tint,
    required this.label,
  });

  final DocklyIconData icon;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DocklyColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DocklyColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: DocklyIcon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DocklyColors.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kavisli deniz sahnesi: gök geçişi + güneş + iki dalga bandı + yelkenli.
/// Onaylı E2 illüstrasyonunun koddan çizimi — her ekran boyutuna ölçeklenir,
/// görsel dosya yükü sıfırdır (splash "marka yüzeyi" ilkesiyle aynı).
class _HeroSeaPainter extends CustomPainter {
  const _HeroSeaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Alt kenarı kavisli sahne maskesi.
    final Path scene = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.86)
      ..quadraticBezierTo(w * 0.5, h * 1.02, 0, h * 0.86)
      ..close();
    canvas.save();
    canvas.clipPath(scene);

    // Gök: lacivert → marka mavisi.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0C3B66), DocklyColors.brandPrimary],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Güneş.
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.30),
      h * 0.09,
      Paint()..color = DocklyColors.warning.withValues(alpha: 0.9),
    );

    // Dalga bantları.
    final Path wave1 = Path()..moveTo(0, h * 0.72);
    wave1.quadraticBezierTo(w * 0.25, h * 0.66, w * 0.5, h * 0.72);
    wave1.quadraticBezierTo(w * 0.75, h * 0.78, w, h * 0.72);
    wave1
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      wave1,
      Paint()..color = DocklyColors.brandDeep.withValues(alpha: 0.55),
    );
    final Path wave2 = Path()..moveTo(0, h * 0.78);
    wave2.quadraticBezierTo(w * 0.25, h * 0.72, w * 0.5, h * 0.78);
    wave2.quadraticBezierTo(w * 0.75, h * 0.84, w, h * 0.78);
    wave2
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      wave2,
      Paint()..color = DocklyColors.accentTurquoise.withValues(alpha: 0.35),
    );

    // Yelkenli silueti (E2 taslağındaki oranlarla).
    final double bx = w * 0.42;
    final double by = h * 0.62;
    final double k = h * 0.012; // ölçek birimi
    // Gövde.
    final Path hull = Path()
      ..moveTo(bx, by + 12 * k)
      ..lineTo(bx + 20 * k, by + 12 * k)
      ..lineTo(bx + 17 * k, by + 16.5 * k)
      ..lineTo(bx + 3 * k, by + 16.5 * k)
      ..close();
    canvas.drawPath(hull, Paint()..color = DocklyColors.brandDeep);
    // Direk.
    canvas.drawRect(
      Rect.fromLTWH(bx + 9.3 * k, by - 10 * k, 1.3 * k, 22 * k),
      Paint()..color = DocklyColors.brandDeep,
    );
    // Ana yelken (beyaz) + flok (turkuaz).
    final Path main = Path()
      ..moveTo(bx + 8.6 * k, by - 9.3 * k)
      ..lineTo(bx - 2.2 * k, by + 10.7 * k)
      ..lineTo(bx + 8.6 * k, by + 10.7 * k)
      ..close();
    canvas.drawPath(main, Paint()..color = Colors.white);
    final Path jib = Path()
      ..moveTo(bx + 11.4 * k, by - 7.2 * k)
      ..lineTo(bx + 19.3 * k, by + 10.7 * k)
      ..lineTo(bx + 11.4 * k, by + 10.7 * k)
      ..close();
    canvas.drawPath(jib, Paint()..color = const Color(0xFF7FE7DC));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroSeaPainter oldDelegate) => false;
}
