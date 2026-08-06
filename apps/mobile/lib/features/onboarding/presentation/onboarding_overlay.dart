import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/onboarding_controller.dart';
import 'tour_targets.dart';

/// Karartma rengi — marka lacivertinin koyusu.
const Color _dimColor = Color(0xC7071626);

/// TANITIM TURU v3 (kullanıcı isteği 2026-08): kart, anlattığı bölgeyi SPOT
/// IŞIĞI + OKLA gösterir; gerekirse SAYFA DEĞİŞİR (Kayıtlarım, Günlük) ve
/// tanıtım o sayfada devam eder. Ekrana dokunmak ilerletir; son kart
/// "Hazırsın" der ve Keşfet'e dönülür. Hedef ölçülemezse kart ortada,
/// spot'suz gösterilir — tur asla kırılmaz (v2 dersi).
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({required this.step, super.key});

  final int step;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

/// Adım tanımı: hangi sekmede geçer + (varsa) okla gösterilecek hedef + ikon.
class _TourStepDef {
  const _TourStepDef({required this.icon, this.tab = 0, this.target});

  final DocklyIconData icon;
  final int tab;
  final GlobalKey? target;
}

/// v3 adımları — sırası l10n `tourTitles`/`tourBodies` ile birebir aynıdır.
final List<_TourStepDef> _tourSteps = <_TourStepDef>[
  const _TourStepDef(icon: DocklyIcons.sailing), // ① hoş geldin
  const _TourStepDef(icon: DocklyIcons.place), // ② harita ve koylar
  _TourStepDef(icon: DocklyIcons.checkCircle, target: tourKeyChips), // ③
  _TourStepDef(icon: DocklyIcons.explore, target: tourKeyLocate), // ④
  _TourStepDef(icon: DocklyIcons.errorOutline, target: tourKeySos), // ⑤
  const _TourStepDef(icon: DocklyIcons.navigation), // ⑥ deniz rotası
  const _TourStepDef(icon: DocklyIcons.edit), // ⑦ rota düzenle & kaydet
  const _TourStepDef(icon: DocklyIcons.favorite, tab: 2), // ⑧ Kayıtlarım
  const _TourStepDef(icon: DocklyIcons.edit, tab: 3), // ⑨ Günlük
  const _TourStepDef(icon: DocklyIcons.sailing), // ⑩ hazırsın (Keşfet'te)
];

class _TourOverlayState extends ConsumerState<TourOverlay> {
  /// Ölçülen hedef dikdörtgeni (genel/ekran koordinatı) — null ise kart ortada.
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    // Hedef bir önceki karede zaten yerleşmiş — HEMEN ölçmek ilk kareyi de
    // doğru çizer (ortada kart + sıçrama yok). Sekme işi çerçeve sonrasına.
    _targetRect = _measure(_def);
    _sync();
  }

  @override
  void didUpdateWidget(TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      // SENKRON ÖLÇÜM (inceleme dersi 2026-08): ölçümü çerçeve sonrasına
      // bırakmak, oklu adımlarda 1 karelik "ortada kart" titremesi yapardı.
      _targetRect = _measure(_def);
      _sync();
    }
  }

  _TourStepDef get _def =>
      _tourSteps[widget.step.clamp(0, _tourSteps.length - 1)];

  /// Hedefin ekran dikdörtgeni — ölçülemiyorsa null (kart ortada gösterilir).
  Rect? _measure(_TourStepDef d) {
    final RenderObject? ro = d.target?.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      return ro.localToGlobal(Offset.zero) & ro.size;
    }
    return null;
  }

  /// Adım kurulumu (çerçeve SONRASI — yerleşim bitmişken): gerekiyorsa sekme
  /// değiştirilir (tanıtım o sayfada açılır), sonra hedef ölçümü doğrulanır.
  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final _TourStepDef d = _def; // dokunuşlar hızlıysa GÜNCEL adım esastır
      if (ref.read(shellTabProvider) != d.tab) {
        ref.read(shellTabProvider.notifier).state = d.tab;
        // Hedefli adım sekme de değiştiriyorsa ölçüm YENİ sekme yerleştikten
        // sonra yapılmalı — bir sonraki çerçeveye ertelenir (gelecek adımlar
        // için hazır; bugünkü sekme-değiştiren adımlar hedefsizdir).
        if (d.target != null) {
          _sync();
          return;
        }
      }
      final Rect? r = _measure(d);
      if (r != _targetRect) setState(() => _targetRect = r);
    });
  }

  /// "Atla" — tur kapanır; hangi sayfada olursak olalım Keşfet'e dönülür.
  void _skip() {
    ref.read(shellTabProvider.notifier).state = 0;
    ref.read(onboardingControllerProvider.notifier).skipTour();
  }

  @override
  Widget build(BuildContext context) {
    assert(_tourSteps.length == kTourStepCount,
        'adım tanımları l10n listeleriyle aynı boyda olmalı');
    final L10n t = ref.watch(l10nProvider);
    final int s = widget.step.clamp(0, kTourStepCount - 1);
    final bool last = s == kTourStepCount - 1;
    final String title = s < t.tourTitles.length ? t.tourTitles[s] : '';
    final String body = s < t.tourBodies.length ? t.tourBodies[s] : '';
    final Size screen = MediaQuery.sizeOf(context);
    final Rect? spot = _targetRect;
    // Kart, hedefin BOŞ kalan yarısına konur; ok aradaki boşlukta hedefi
    // işaret eder (kullanıcı isteği: "okla o bölgeyi göstererek").
    final bool cardBelow = spot != null && spot.center.dy < screen.height / 2;
    final Widget card = _TourCard(
      step: s,
      last: last,
      title: title,
      body: body,
      icon: _def.icon,
      t: t,
    );
    return GestureDetector(
      key: ValueKey<String>('onb-tour-step-$s'),
      behavior: HitTestBehavior.opaque,
      // EKRANA DOKUN → SONRAKİ ADIM (son adımda biter). Alttaki ekran bu
      // sırada dokunuş almaz (opaque karartma alt menüyü de kapsar).
      onTap: () =>
          ref.read(onboardingControllerProvider.notifier).nextStep(),
      child: Stack(
        children: <Widget>[
          // Karartma: hedef varsa DELİKLİ (spot ışığı + çerçeve), yoksa düz.
          Positioned.fill(
            child: spot == null
                ? const ColoredBox(color: _dimColor)
                : CustomPaint(
                    key: const ValueKey<String>('onb-tour-spot'),
                    painter: _SpotDimPainter(hole: spot.inflate(7)),
                  ),
          ),
          // ATLA — her an çıkış (karar zaten işlendi; bir daha açılmaz).
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    t.onbSkip,
                    style: TextStyle(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (spot == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: card,
                ),
              ),
            )
          else ...<Widget>[
            // OK: kart ile spot arasındaki boşlukta, hedefi işaret eder.
            Positioned(
              left: (spot.center.dx - 40).clamp(8.0, screen.width - 88.0),
              top: cardBelow ? spot.bottom + 10 : null,
              bottom: cardBelow ? null : screen.height - spot.top + 10,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(80, 44),
                  painter: _TourArrowPainter(pointsUp: cardBelow),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: cardBelow ? spot.bottom + 60 : null,
              bottom: cardBelow ? null : screen.height - spot.top + 60,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: card,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tur kartı: ikon + başlık + gövde + ilerleme noktaları + dokunuş ipucu.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.last,
    required this.title,
    required this.body,
    required this.icon,
    required this.t,
  });

  final int step;
  final bool last;
  final String title;
  final String body;
  final DocklyIconData icon;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF0E3052),
                        DocklyColors.brandDeep,
                      ],
                    ),
                  ),
                  child: Center(
                    child: DocklyIcon(
                      icon,
                      size: 20,
                      color: const Color(0xFF7FE3D9),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            // İlerleme noktaları + dokunuş ipucu ALT ALTA — dar ekranda ve
            // uzun çevirilerde (RU) taşma olmaz.
            Row(
              children: <Widget>[
                for (int i = 0; i < kTourStepCount; i++)
                  Container(
                    width: i == step ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == step
                          ? DocklyColors.brandPrimary
                          : theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              last ? t.tourTapHintLast : t.tourTapHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: DocklyColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delikli karartma: hedefin çevresi aydınlık kalır (spot ışığı) ve ince
/// beyaz çerçeveyle vurgulanır.
class _SpotDimPainter extends CustomPainter {
  const _SpotDimPainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect r = RRect.fromRectAndRadius(hole, const Radius.circular(14));
    final Path dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(r),
    );
    canvas.drawPath(dim, Paint()..color = _dimColor);
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpotDimPainter oldDelegate) => oldDelegate.hole != hole;
}

/// Karttan hedefe uzanan kıvrımlı ok (uçta V başlık).
class _TourArrowPainter extends CustomPainter {
  const _TourArrowPainter({required this.pointsUp});

  /// true → ok yukarıyı (üstteki hedefi) gösterir; false → aşağıyı.
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92);
    final double tipY = pointsUp ? 3 : size.height - 3;
    final double tailY = pointsUp ? size.height - 3 : 3;
    final Offset tip = Offset(size.width / 2, tipY);
    final Path path = Path()
      ..moveTo(size.width * 0.78, tailY)
      ..quadraticBezierTo(
        size.width * 0.72,
        (tailY + tipY) / 2,
        tip.dx,
        tipY + (pointsUp ? 6 : -6),
      );
    canvas.drawPath(path, line);
    final double d = pointsUp ? 1 : -1;
    canvas.drawLine(tip, tip + Offset(-6, 8 * d), line);
    canvas.drawLine(tip, tip + Offset(6, 8 * d), line);
  }

  @override
  bool shouldRepaint(_TourArrowPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp;
}

/// İLK-DOKUNUŞ İPUCU BALONU: özellik ilk kez kullanılırken tek seferlik küçük
/// açıklama; "Anladım" ile kapanır ve cihazda işlenir (bir daha görünmez).
class OnboardingHintBubble extends ConsumerWidget {
  const OnboardingHintBubble({
    required this.hintKey,
    required this.title,
    required this.body,
    super.key,
  });

  final String hintKey;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Material(
      key: ValueKey<String>('onb-hint-$hintKey'),
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: DocklyIcon(DocklyIcons.infoOutline,
                        size: 14, color: DocklyColors.brandPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref
                    .read(onboardingControllerProvider.notifier)
                    .markHintSeen(hintKey),
                child: Text(t.onbGotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
