import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/onboarding_controller.dart';
import 'tour_targets.dart';

/// Karartma rengi — marka lacivertinin koyusu.
const Color _dimColor = Color(0xC7071626);

/// TANITIM TURU v4 — PREMIUM (kullanıcı isteği 2026-08): kaba çizgi-ok
/// yerine, kaliteli uygulama tanıtımlarındaki dil kullanılır —
///  • anlatılan bölge YUMUŞAK IŞIMALI vurgu halkasıyla aydınlık kalır ve
///    yerine "oturma" animasyonuyla gelir;
///  • kart, hedefe KONUŞMA BALONU UCUYLA bağlanır (havada uçan ok yok);
///  • kartta adım sayacı (3/10), akıcı geçiş animasyonu ve İleri/Başla
///    düğmesi vardır; ekranın herhangi bir yerine dokunmak da ilerletir;
///  • tur gerekirse SAYFA DEĞİŞTİRİR (Kayıtlarım, Günlük) ve son kart
///    "Hazırsın" deyip Keşfet'e döner.
/// Hedef ölçülemezse kart ortada, vurgusuz gösterilir — tur asla kırılmaz.
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({required this.step, super.key});

  final int step;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

/// Adım tanımı: hangi sekmede geçer + (varsa) vurgulanacak hedef + ikon.
class _TourStepDef {
  const _TourStepDef({required this.icon, this.tab = 0, this.target});

  final DocklyIconData icon;
  final int tab;
  final GlobalKey? target;
}

/// v4 adımları — sırası l10n `tourTitles`/`tourBodies` ile birebir aynıdır.
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
  /// Ölçülen hedef dikdörtgeni (ekran koordinatı) — null ise kart ortada.
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
      // bırakmak, vurgulu adımlarda 1 karelik "ortada kart" titremesi yapardı.
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

  void _next() =>
      ref.read(onboardingControllerProvider.notifier).nextStep();

  /// "Atla" — tur kapanır; hangi sayfada olursak olalım Keşfet'e dönülür.
  void _skip() {
    ref.read(shellTabProvider.notifier).state = 0;
    ref.read(onboardingControllerProvider.notifier).skipTour();
  }

  /// Adımlar arası akıcı geçiş: içerik yumuşakça kayarak belirir.
  Widget _stepSwitcher(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget c, Animation<double> a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(a),
          child: c,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<int>(widget.step), child: child),
    );
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
    // Kart, hedefin BOŞ kalan yarısına konur; balon ucu hedefi işaret eder.
    final bool cardBelow = spot != null && spot.center.dy < screen.height / 2;
    // Kart genişliği/konumu — balon ucunun yatay hizası hedefe göre hesaplanır.
    final double cardW =
        (screen.width - 32) < 420 ? (screen.width - 32) : 420.0;
    // Kart hedefe YATAYDA da yaklaşır (tablet/geniş ekran cilası): balon ucu
    // hedefin tam altına/üstüne oturur; kart ekran kenarından taşmaz.
    final double cardLeft = spot == null
        ? (screen.width - cardW) / 2
        : (spot.center.dx - cardW / 2)
            .clamp(16.0, screen.width - 16.0 - cardW);
    final double tailLeft = spot == null
        ? 0
        : (spot.center.dx - cardLeft - 11).clamp(20.0, cardW - 42.0);
    final Widget card = _TourCard(
      step: s,
      last: last,
      title: title,
      body: body,
      icon: _def.icon,
      t: t,
      onNext: _next,
    );
    return GestureDetector(
      key: ValueKey<String>('onb-tour-step-$s'),
      behavior: HitTestBehavior.opaque,
      // EKRANA DOKUN → SONRAKİ ADIM (İleri düğmesi de aynı işi yapar).
      // Alttaki ekran bu sırada dokunuş almaz (karartma alt menüyü de kapsar).
      onTap: _next,
      child: Stack(
        children: <Widget>[
          // Karartma: hedef varsa yumuşak ışımalı VURGU (yerine oturma
          // animasyonuyla), yoksa düz karartma.
          Positioned.fill(
            child: spot == null
                ? const ColoredBox(color: _dimColor)
                : TweenAnimationBuilder<double>(
                    key: ValueKey<String>('spot-anim-$s'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double v, Widget? _) =>
                        CustomPaint(
                      key: const ValueKey<String>('onb-tour-spot'),
                      painter: _SpotDimPainter(hole: spot.inflate(9), t: v),
                    ),
                  ),
          ),
          // ATLA — buzlu cam hap (premium dil); her an çıkış.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _skip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Text(
                        t.onbSkip,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (spot == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardW),
                  child: _stepSwitcher(card),
                ),
              ),
            )
          else
            // Kart + balon ucu: hedefin hemen yanında, ona bağlı görünür.
            Positioned(
              left: cardLeft,
              width: cardW,
              top: cardBelow ? spot.bottom + 18 : null,
              bottom: cardBelow ? null : screen.height - spot.top + 18,
              child: _stepSwitcher(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (cardBelow)
                      Padding(
                        padding: EdgeInsets.only(left: tailLeft),
                        child: const _CardTail(pointsUp: true),
                      ),
                    card,
                    if (!cardBelow)
                      Padding(
                        padding: EdgeInsets.only(left: tailLeft),
                        child: const _CardTail(pointsUp: false),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tur kartı (premium): ikon + başlık + adım sayacı hapı + gövde +
/// animasyonlu ilerleme noktaları + İleri/Başla düğmesi.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.last,
    required this.title,
    required this.body,
    required this.icon,
    required this.t,
    required this.onNext,
  });

  final int step;
  final bool last;
  final String title;
  final String body;
  final DocklyIconData icon;
  final L10n t;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 16,
      shadowColor: const Color(0x59071626),
      borderRadius: BorderRadius.circular(22),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                ),
                const SizedBox(width: 8),
                // ADIM SAYACI (3/10): kullanıcı turda nerede, bilir.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${step + 1}/$kTourStepCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: DocklyColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                for (int i = 0; i < kTourStepCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: i == step ? 18 : 6,
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
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(last ? t.tourStartBtn : t.onbNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta bağlı balon ucu: hedefe bakan yumuşak (ucu kavisli) üçgen —
/// kart hedefe "bağlı" görünür; havada uçan ok yoktur.
class _CardTail extends StatelessWidget {
  const _CardTail({required this.pointsUp});

  /// true → uç yukarıyı (üstteki hedefi) gösterir; false → aşağıyı.
  final bool pointsUp;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 10),
      painter: _CardTailPainter(
        pointsUp: pointsUp,
        color: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

class _CardTailPainter extends CustomPainter {
  const _CardTailPainter({required this.pointsUp, required this.color});

  final bool pointsUp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double base = pointsUp ? size.height : 0;
    final double tip = pointsUp ? 0 : size.height;
    final double bulge = pointsUp ? 2.0 : -2.0;
    final Path p = Path()
      ..moveTo(0, base)
      ..lineTo(size.width * 0.5 - 3, tip + bulge)
      ..quadraticBezierTo(
          size.width * 0.5, tip - bulge * 0.5, size.width * 0.5 + 3, tip + bulge)
      ..lineTo(size.width, base)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CardTailPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp || oldDelegate.color != color;
}

/// Delikli karartma + yumuşak ışıma: hedefin çevresi aydınlık kalır; halka,
/// içten dışa incelen turkuaz katmanlarla "ışıldar" (bulanıklaştırma yok —
/// her cihaz/çizim motorunda birebir aynı görünür). [t] 0→1 yerleşme
/// animasyonudur: delik hafif geniş başlar, yerine oturur; ışıma belirir.
class _SpotDimPainter extends CustomPainter {
  const _SpotDimPainter({required this.hole, required this.t});

  final Rect hole;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect h = hole.inflate((1 - t) * 10);
    final RRect r = RRect.fromRectAndRadius(h, const Radius.circular(16));
    final Path dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(r),
    );
    canvas.drawPath(dim, Paint()..color = _dimColor);
    const Color glow = Color(0xFF7FE3D9);
    canvas.drawRRect(
      r.inflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = glow.withValues(alpha: 0.10 * t),
    );
    canvas.drawRRect(
      r.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = glow.withValues(alpha: 0.26 * t),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95 * t),
    );
  }

  @override
  bool shouldRepaint(_SpotDimPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.t != t;
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
