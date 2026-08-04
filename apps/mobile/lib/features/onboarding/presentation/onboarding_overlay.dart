import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/onboarding_controller.dart';
import 'tour_targets.dart';

/// Karartma rengi (spot ışığı dışı) — marka lacivertinin koyusu.
const Color _dimColor = Color(0x9E071626);

/// KARŞILAMA KARTI (tanıtım 2026-08): yalnız İLK açılışta, karar verilene dek.
/// "Şimdi değil" bir daha sormaz; "Turu başlat" 6 adımlı turu açar.
class OnboardingWelcomeCard extends ConsumerWidget {
  const OnboardingWelcomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: _dimColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              key: const ValueKey<String>('onb-welcome'),
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFF0E3052), DocklyColors.brandDeep],
                        ),
                      ),
                      child: const Center(
                        child: DocklyIcon(DocklyIcons.sailing,
                            size: 26, color: Color(0xFF7FE3D9)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.onbWelcomeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.onbWelcomeBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DocklyButton(
                            label: t.onbNotNow,
                            variant: DocklyButtonVariant.secondary,
                            onPressed: () => ref
                                .read(onboardingControllerProvider.notifier)
                                .dismissWelcome(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DocklyButton(
                            label: t.onbStartTour,
                            onPressed: () => ref
                                .read(onboardingControllerProvider.notifier)
                                .startTour(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SPOT IŞIKLI TUR: aktif adımın hedefi aydınlanır, gerisi kararır; balonla
/// kısa açıklama + ilerleme noktaları + Atla/İleri. Hedefin ekran konumu
/// çizimden SONRA ölçülür (ilk karede spot'suz başlar, hemen oturur).
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({required this.step, super.key});

  final int step;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _hole = null;
      _scheduleMeasure();
    }
  }

  GlobalKey? get _targetKey => switch (widget.step) {
        1 => tourKeyChips,
        2 => tourKeyLocate,
        3 => tourKeySos,
        4 => tourKeySearch,
        _ => null, // 0 = harita geneli, 5 = koy kartı (alt alan) — spot yok
      };

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final GlobalKey? key = _targetKey;
      final RenderObject? target = key?.currentContext?.findRenderObject();
      final RenderObject? own = context.findRenderObject();
      if (key == null || target is! RenderBox || own is! RenderBox ||
          !target.attached || !own.attached) {
        setState(() => _hole = null);
        return;
      }
      // Hedefin, KAPLAMANIN kendi koordinatlarındaki dikdörtgeni.
      final Offset topLeft =
          own.globalToLocal(target.localToGlobal(Offset.zero));
      setState(() => _hole = (topLeft & target.size).inflate(6));
    });
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final int step = widget.step.clamp(0, kTourStepCount - 1);
    final String title =
        step < t.tourTitles.length ? t.tourTitles[step] : '';
    final String body = step < t.tourBodies.length ? t.tourBodies[step] : '';
    final bool last = step == kTourStepCount - 1;

    final Widget balloon = Material(
      key: ValueKey<String>('onb-tour-step-$step'),
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (int i = 0; i < kTourStepCount; i++)
                  Container(
                    width: i == step ? 14 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == step
                          ? DocklyColors.brandPrimary
                          : theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref
                      .read(onboardingControllerProvider.notifier)
                      .skipTour(),
                  child: Text(t.onbSkip),
                ),
                const SizedBox(width: 2),
                DocklyButton(
                  label: last ? t.onbDone : t.onbNext,
                  onPressed: () => ref
                      .read(onboardingControllerProvider.notifier)
                      .nextStep(),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Balon konumu: spot varsa deliğin altına/üstüne; 0. adım ortada,
    // son adım (koy kartı) alt bölgede.
    final Rect? hole = _hole;
    Widget positionedBalloon;
    if (hole == null) {
      positionedBalloon = step == kTourStepCount - 1
          ? Positioned(left: 16, right: 16, bottom: 32, child: balloon)
          : Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.sizeOf(context).height * 0.30,
              child: balloon,
            );
    } else {
      final double screenH = MediaQuery.sizeOf(context).height;
      positionedBalloon = hole.center.dy < screenH / 2
          ? Positioned(left: 16, right: 16, top: hole.bottom + 14, child: balloon)
          : Positioned(
              left: 16,
              right: 16,
              bottom: screenH - hole.top + 14,
              child: balloon,
            );
    }

    // Karartma dokunuşları yutar (tur sırasında alttaki harita etkileşimsiz);
    // çıkış her an "Atla" ile.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: _SpotlightPainter(hole: hole)),
          ),
          positionedBalloon,
        ],
      ),
    );
  }
}

/// Karartma + spot deliği: delik dışı [_dimColor], delik kenarı beyaz halka.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect screen = Offset.zero & size;
    final Rect? h = hole;
    if (h == null) {
      canvas.drawRect(screen, Paint()..color = _dimColor);
      return;
    }
    final RRect spot =
        RRect.fromRectAndRadius(h, Radius.circular(h.shortestSide / 2));
    final Path dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(screen),
      Path()..addRRect(spot),
    );
    canvas.drawPath(dim, Paint()..color = _dimColor);
    canvas.drawRRect(
      spot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
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
