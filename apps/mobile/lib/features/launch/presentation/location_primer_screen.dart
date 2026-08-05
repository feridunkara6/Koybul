import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';

/// KONUM ÖN-İZİN EKRANI — E6 (onaylı tasarım 2026-08).
///
/// Tarayıcının soğuk izin penceresi ANCAK mavi düğmeden sonra açılır: kullanıcı
/// hazır değilse "bölgemle devam" der ve tarayıcıya red hiç kaydedilmez (webde
/// red kalıcıdır — en kritik izin ilkemiz). İki çıkış da eşit saygındır;
/// izin gelmezse hiçbir özellik kilitlenmez, harita bölge odağıyla açılır.
class LocationPrimerScreen extends ConsumerStatefulWidget {
  const LocationPrimerScreen({
    required this.onUseLocation,
    required this.onContinueWithout,
    super.key,
  });

  /// "Konumumu kullan" — kapı locateMe'yi bekler, sonra akışı bitirir.
  final Future<void> Function() onUseLocation;

  /// "Şimdilik bölgemle devam" — izin penceresi hiç açılmaz.
  final VoidCallback onContinueWithout;

  @override
  ConsumerState<LocationPrimerScreen> createState() =>
      _LocationPrimerScreenState();
}

class _LocationPrimerScreenState extends ConsumerState<LocationPrimerScreen> {
  bool _busy = false; // çifte dokunuş koruması (izin penceresi açıkken)

  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onUseLocation();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DocklyColors.bgBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        children: <Widget>[
                          // İllüstrasyon: konum halkası içinde tekne imleci +
                          // çevrede koy çapaları. TEK SEFERLİK büyüme (tekrar
                          // eden animasyon yok — sükunet + test güvenliği).
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.86, end: 1),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            builder: (BuildContext context, double s,
                                    Widget? child) =>
                                Transform.scale(scale: s, child: child),
                            child: const SizedBox(
                              width: 190,
                              height: 190,
                              child:
                                  CustomPaint(painter: _LocationPrimerPainter()),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            t.locTitle,
                            textAlign: TextAlign.center,
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DocklyColors.text1,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _BenefitRow(text: '📍  ${t.locBenefit1}'),
                          const SizedBox(height: 8),
                          _BenefitRow(text: '⚓  ${t.locBenefit2}'),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const ValueKey<String>('launch-loc-use'),
                              style: FilledButton.styleFrom(
                                backgroundColor: DocklyColors.brandPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              onPressed: _busy ? null : _use,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      t.locUseBtn,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const ValueKey<String>('launch-loc-skip'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFE3E9F1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: _busy ? null : widget.onContinueWithout,
                              child: Text(
                                t.locSkipBtn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: DocklyColors.text2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            t.locTrustNote,
                            textAlign: TextAlign.center,
                            style: text.bodySmall
                                ?.copyWith(color: DocklyColors.text2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: DocklyColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DocklyColors.hairline),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: DocklyColors.text1),
      ),
    );
  }
}

/// Konum halkası + tekne imleci + koy çapaları (onaylı E6 illüstrasyonu).
class _LocationPrimerPainter extends CustomPainter {
  const _LocationPrimerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;
    // Halkalar (statik — nefes animasyonu yerine sakin katmanlar).
    canvas.drawCircle(c, r * 0.94, Paint()..color = const Color(0xFFE7F1FC));
    canvas.drawCircle(c, r * 0.64, Paint()..color = const Color(0xFFD2E6F9));
    canvas.drawCircle(
      c,
      r * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = DocklyColors.brandPrimary.withValues(alpha: 0.35),
    );
    // Tekne imleci: yön oku gibi damla (38° döndürülmüş).
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.66);
    final double k = r * 0.012;
    final Path cursor = Path()
      ..moveTo(0, -30 * k)
      ..cubicTo(12 * k, -12 * k, 12 * k, 10 * k, 0, 26 * k)
      ..cubicTo(-12 * k, 10 * k, -12 * k, -12 * k, 0, -30 * k)
      ..close();
    canvas.drawPath(cursor, Paint()..color = DocklyColors.brandPrimary);
    final Path shade = Path()
      ..moveTo(0, -30 * k)
      ..cubicTo(12 * k, -12 * k, 12 * k, 10 * k, 0, 26 * k)
      ..lineTo(0, -30 * k)
      ..close();
    canvas.drawPath(shade, Paint()..color = const Color(0xFF0A63B5));
    canvas.restore();
    // Koy çapaları (turkuaz noktalar).
    final Paint anchor = Paint()..color = DocklyColors.accentTurquoise;
    canvas.drawCircle(Offset(c.dx + r * 0.55, c.dy - r * 0.48), 9, anchor);
    canvas.drawCircle(Offset(c.dx - r * 0.60, c.dy + r * 0.32), 9, anchor);
  }

  @override
  bool shouldRepaint(_LocationPrimerPainter oldDelegate) => false;
}
