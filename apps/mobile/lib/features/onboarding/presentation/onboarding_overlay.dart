import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/onboarding_controller.dart';

/// Karartma rengi — marka lacivertinin koyusu.
const Color _dimColor = Color(0xC7071626);

/// TANITIM KARTLARI v2 (kullanıcı isteği 2026-08): uygulama İLK açılışta
/// kartları kendiliğinden gösterir; EKRANIN HERHANGİ BİR YERİNE dokunmak
/// sonraki kartı getirir (spot ışığı/ölçüm yok — her cihazda sorunsuz).
/// Sağ üstte "Atla"; son kartta dokunuş tanıtımı bitirir. Profil'den
/// yeniden izlenebilir.
class TourOverlay extends ConsumerWidget {
  const TourOverlay({required this.step, super.key});

  final int step;

  /// Adım ikonları (kart başlıklarıyla aynı sırada).
  static const List<DocklyIconData> _icons = <DocklyIconData>[
    DocklyIcons.sailing, // hoş geldin
    DocklyIcons.place, // harita ve koylar
    DocklyIcons.checkCircle, // filtreler
    DocklyIcons.explore, // konumum
    DocklyIcons.errorOutline, // SOS
    DocklyIcons.navigation, // deniz rotası
    DocklyIcons.edit, // rota düzenleme & kaydetme
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final int s = step.clamp(0, kTourStepCount - 1);
    final bool last = s == kTourStepCount - 1;
    final String title = s < t.tourTitles.length ? t.tourTitles[s] : '';
    final String body = s < t.tourBodies.length ? t.tourBodies[s] : '';
    return GestureDetector(
      key: ValueKey<String>('onb-tour-step-$s'),
      behavior: HitTestBehavior.opaque,
      // EKRANA DOKUN → SONRAKİ KART (son kartta biter). Alttaki harita bu
      // sırada dokunuş almaz (opaque karartma).
      onTap: () =>
          ref.read(onboardingControllerProvider.notifier).nextStep(),
      child: ColoredBox(
        color: _dimColor,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              // ATLA — her an çıkış (kararı zaten işlendi; bir daha açılmaz).
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => ref
                        .read(onboardingControllerProvider.notifier)
                        .skipTour(),
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 56,
                              height: 56,
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
                                  _icons[s],
                                  size: 26,
                                  color: const Color(0xFF7FE3D9),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                for (int i = 0; i < kTourStepCount; i++)
                                  Container(
                                    width: i == s ? 16 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: i == s
                                          ? DocklyColors.brandPrimary
                                          : theme.dividerColor
                                              .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              last ? t.tourTapHintLast : t.tourTapHint,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: DocklyColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
