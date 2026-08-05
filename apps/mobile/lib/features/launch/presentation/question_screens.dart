import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../domain/launch_answers.dart';

/// SORU EKRANLARI — E3 / E4 / E5 (onaylı tasarım 2026-08).
///
/// Ortak iskelet: ilerleme çubuğu + "Soruları atla" (kalan TÜM soruları
/// atlar — onaylı iyileştirme), başlık, alt başlık, içerik, CTA ve
/// "Profil'den değiştirilebilir" notu. Her cevap isteğe bağlıdır; atlayan
/// kullanıcı cevaplayanla AYNI haritayı görür.
class QuestionShell extends ConsumerWidget {
  const QuestionShell({
    required this.stepIndex, // 1..3
    required this.title,
    required this.subtitle,
    required this.child,
    required this.ctaLabel,
    required this.onCta,
    required this.onSkipAll,
    this.footnote,
    super.key,
  });

  final int stepIndex;
  final String title;
  final String subtitle;
  final Widget child;
  final String ctaLabel;
  final VoidCallback onCta;
  final VoidCallback onSkipAll;
  final String? footnote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                // Geniş ekranda (masaüstü web) içerik telefon genişliğinde
                // ortalanır — kartlar dev gibi büyümesin.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: stepIndex / 3,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE3E9F1),
                                color: DocklyColors.accentTurquoise,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            key: const ValueKey<String>('launch-skip-all'),
                            onPressed: onSkipAll,
                            child: Text(
                              t.qSkipAll,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: DocklyColors.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: DocklyColors.text1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style:
                            text.bodyMedium?.copyWith(color: DocklyColors.text2),
                      ),
                      const SizedBox(height: 20),
                      child,
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey<String>('launch-q-cta'),
                          style: FilledButton.styleFrom(
                            backgroundColor: DocklyColors.brandPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: onCta,
                          child: Text(
                            ctaLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                          if (footnote != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                footnote!,
                                textAlign: TextAlign.center,
                                style: text.bodySmall
                                    ?.copyWith(color: DocklyColors.text2),
                              ),
                            ),
                          ],
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

// ============================================================================
// E3 — TEKNE TİPİ
// ============================================================================

class BoatTypeScreen extends ConsumerWidget {
  const BoatTypeScreen({
    required this.selected,
    required this.onSelect,
    required this.onContinue,
    required this.onSkipAll,
    super.key,
  });

  final BoatTypeChoice? selected;
  final ValueChanged<BoatTypeChoice> onSelect;
  final VoidCallback onContinue;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    String label(BoatTypeChoice c) => switch (c) {
          BoatTypeChoice.sail => t.qTypeSail,
          BoatTypeChoice.motor => t.qTypeMotor,
          BoatTypeChoice.catamaran => t.qTypeCat,
          BoatTypeChoice.gulet => t.qTypeGulet,
        };
    return QuestionShell(
      stepIndex: 1,
      title: t.qTypeTitle,
      subtitle: t.qTypeSub,
      ctaLabel: t.qContinue,
      onCta: onContinue,
      onSkipAll: onSkipAll,
      footnote: t.qLaterNote,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: <Widget>[
          for (final BoatTypeChoice c in BoatTypeChoice.values)
            _TypeCard(
              key: ValueKey<String>('boat-type-${c.id}'),
              choice: c,
              label: label(c),
              selected: selected == c,
              onTap: () => onSelect(c),
            ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.choice,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final BoatTypeChoice choice;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: DocklyColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? DocklyColors.accentTurquoise
                : const Color(0xFFE3E9F1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 72,
                    height: 56,
                    child: CustomPaint(painter: _BoatTypePainter(choice)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DocklyColors.text1,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: DocklyColors.accentTurquoise,
                    shape: BoxShape.circle,
                  ),
                  child: const DocklyIcon(
                    DocklyIcons.checkCircle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Özgün mini tekne çizimleri — E3 kartları (onaylı taslaktaki oranlarla).
class _BoatTypePainter extends CustomPainter {
  const _BoatTypePainter(this.type);

  final BoatTypeChoice type;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint deep = Paint()..color = DocklyColors.brandDeep;
    final Paint blue = Paint()..color = DocklyColors.brandPrimary;
    final Paint turq = Paint()..color = const Color(0xFF7FE7DC);
    switch (type) {
      case BoatTypeChoice.sail:
        // Direk + iki yelken + gövde.
        canvas.drawRect(
            Rect.fromLTWH(w * 0.48, h * 0.06, w * 0.045, h * 0.68), deep);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.46, h * 0.10)
            ..lineTo(w * 0.16, h * 0.66)
            ..lineTo(w * 0.46, h * 0.66)
            ..close(),
          blue,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.54, h * 0.20)
            ..lineTo(w * 0.76, h * 0.66)
            ..lineTo(w * 0.54, h * 0.66)
            ..close(),
          turq,
        );
        canvas.drawPath(_hull(w * 0.10, h * 0.74, w * 0.80, h * 0.18), deep);
      case BoatTypeChoice.motor:
        // Kabinli motoryat.
        canvas.drawRect(
            Rect.fromLTWH(w * 0.38, h * 0.16, w * 0.24, h * 0.16),
            Paint()..color = const Color(0xFF7FA8CF));
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.24, h * 0.34)
            ..lineTo(w * 0.66, h * 0.34)
            ..quadraticBezierTo(w * 0.82, h * 0.36, w * 0.84, h * 0.52)
            ..lineTo(w * 0.20, h * 0.52)
            ..close(),
          blue,
        );
        canvas.drawPath(_hull(w * 0.10, h * 0.56, w * 0.80, h * 0.20), deep);
      case BoatTypeChoice.catamaran:
        // Çift gövde + yelkenler.
        canvas.drawRect(
            Rect.fromLTWH(w * 0.485, h * 0.08, w * 0.04, h * 0.52), deep);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.47, h * 0.12)
            ..lineTo(w * 0.24, h * 0.56)
            ..lineTo(w * 0.47, h * 0.56)
            ..close(),
          blue,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.55, h * 0.22)
            ..lineTo(w * 0.70, h * 0.56)
            ..lineTo(w * 0.55, h * 0.56)
            ..close(),
          turq,
        );
        canvas.drawPath(_hull(w * 0.08, h * 0.64, w * 0.34, h * 0.15), deep);
        canvas.drawPath(_hull(w * 0.58, h * 0.64, w * 0.34, h * 0.15), deep);
        canvas.drawRect(
            Rect.fromLTWH(w * 0.20, h * 0.66, w * 0.60, h * 0.05), deep);
      case BoatTypeChoice.gulet:
        // İki direkli ahşap tekne.
        canvas.drawRect(
            Rect.fromLTWH(w * 0.30, h * 0.10, w * 0.04, h * 0.52), deep);
        canvas.drawRect(
            Rect.fromLTWH(w * 0.62, h * 0.20, w * 0.04, h * 0.42), deep);
        final Paint cream = Paint()..color = const Color(0xFFF2E4C8);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.36, h * 0.14)
            ..lineTo(w * 0.56, h * 0.58)
            ..lineTo(w * 0.36, h * 0.58)
            ..close(),
          cream,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.68, h * 0.24)
            ..lineTo(w * 0.86, h * 0.58)
            ..lineTo(w * 0.68, h * 0.58)
            ..close(),
          cream,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.06, h * 0.62)
            ..quadraticBezierTo(w * 0.5, h * 0.74, w * 0.94, h * 0.62)
            ..lineTo(w * 0.84, h * 0.82)
            ..lineTo(w * 0.16, h * 0.82)
            ..close(),
          deep,
        );
    }
  }

  /// Basit gövde: üstten alta daralan yamuk.
  Path _hull(double x, double y, double width, double height) => Path()
    ..moveTo(x, y)
    ..lineTo(x + width, y)
    ..lineTo(x + width * 0.86, y + height)
    ..lineTo(x + width * 0.14, y + height)
    ..close();

  @override
  bool shouldRepaint(_BoatTypePainter oldDelegate) =>
      oldDelegate.type != type;
}

// ============================================================================
// E4 — BOY + SU ÇEKİMİ
// ============================================================================

class BoatSizeScreen extends ConsumerStatefulWidget {
  const BoatSizeScreen({
    required this.initialLengthM,
    required this.initialDraftM,
    required this.onContinue,
    required this.onSkipAll,
    super.key,
  });

  final double initialLengthM;
  final double initialDraftM;
  final void Function(double lengthM, double draftM) onContinue;
  final VoidCallback onSkipAll;

  @override
  ConsumerState<BoatSizeScreen> createState() => _BoatSizeScreenState();
}

class _BoatSizeScreenState extends ConsumerState<BoatSizeScreen> {
  late double _len = widget.initialLengthM.clamp(6.0, 30.0);
  late double _draft = widget.initialDraftM.clamp(0.5, 4.0);

  /// Repo genelindeki sayı biçimi (nokta ondalık): 12 → '12', 12.5 → '12.5'.
  static String _m(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    return QuestionShell(
      stepIndex: 2,
      title: t.qSizeTitle,
      subtitle: t.qSizeSub,
      ctaLabel: t.qContinue,
      onCta: () => widget.onContinue(_len, _draft),
      onSkipAll: widget.onSkipAll,
      footnote: t.qLaterNote,
      child: Column(
        children: <Widget>[
          _SliderCard(
            label: t.qSizeLen,
            valueText: '${_m(_len)} m',
            valueColor: DocklyColors.brandPrimary,
            min: 6,
            max: 30,
            divisions: 48,
            value: _len,
            minLabel: '6 m',
            maxLabel: '30 m+',
            onChanged: (double v) => setState(() => _len = v),
          ),
          const SizedBox(height: 14),
          _SliderCard(
            label: t.qSizeDraft,
            valueText: '${_draft.toStringAsFixed(1)} m',
            valueColor: DocklyColors.accentTurquoise,
            min: 0.5,
            max: 4,
            divisions: 35,
            value: _draft,
            minLabel: '0.5 m',
            maxLabel: '4 m+',
            onChanged: (double v) => setState(() => _draft = v),
          ),
          const SizedBox(height: 16),
          // CANLI KAZANIM KUTUSU (onaylı): "bu bilgiyi neden veriyorum?"
          // sorusu ekranda, o anki değerlerle cevaplanır.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F8F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '✓  ${L10n.fmt(t.qSizeBenefitDraft, _draft.toStringAsFixed(1))}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF155E56)),
                ),
                const SizedBox(height: 6),
                Text(
                  '✓  ${L10n.fmt(t.qSizeBenefitLen, _m(_len))}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF155E56)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.valueText,
    required this.valueColor,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final Color valueColor;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: DocklyColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E9F1)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DocklyColors.text2,
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: valueColor,
              thumbColor: Colors.white,
              overlayColor: valueColor.withValues(alpha: 0.12),
              inactiveTrackColor: const Color(0xFFE3E9F1),
              trackHeight: 6,
            ),
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: value,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(minLabel,
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xFF98A5B8))),
              Text(maxLabel,
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xFF98A5B8))),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// E5 — SEYİR BÖLGESİ
// ============================================================================

class RegionScreen extends ConsumerWidget {
  const RegionScreen({
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenMap,
    required this.onSkipAll,
    super.key,
  });

  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenMap;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return QuestionShell(
      stepIndex: 3,
      title: t.qRegionTitle,
      subtitle: t.qRegionSub,
      ctaLabel: t.qRegionCta,
      onCta: onOpenMap,
      onSkipAll: onSkipAll,
      footnote: t.qRegionNote,
      child: Column(
        children: <Widget>[
          // Stilize kıyı görseli — seçilen bölge turkuaz pinle işaretlenir
          // (dekoratif; seçim aşağıdaki çiplerle yapılır).
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 130,
              child: CustomPaint(painter: _CoastPainter(selectedIndex)),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < kLaunchRegions.length; i++)
                _RegionChip(
                  key: ValueKey<String>('region-$i'),
                  label: kLaunchRegions[i].name,
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DocklyColors.accentTurquoise : DocklyColors.bgSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? DocklyColors.accentTurquoise
                : const Color(0xFFE3E9F1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : DocklyColors.text2,
          ),
        ),
      ),
    );
  }
}

/// Dekoratif kıyı silueti: deniz zemini + kum rengi kara + bölge noktaları.
/// Seçili bölge turkuaz pin + halka ile vurgulanır.
class _CoastPainter extends CustomPainter {
  const _CoastPainter(this.selectedIndex);

  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    // Deniz.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFDCEBF7));
    // Kara: kuzeyden güneydoğuya inen stilize kıyı şeridi (üst bant).
    final Path land = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.55)
      ..quadraticBezierTo(w * 0.86, h * 0.62, w * 0.74, h * 0.52)
      ..quadraticBezierTo(w * 0.62, h * 0.42, w * 0.52, h * 0.50)
      ..quadraticBezierTo(w * 0.40, h * 0.58, w * 0.30, h * 0.42)
      ..quadraticBezierTo(w * 0.20, h * 0.26, w * 0.10, h * 0.30)
      ..quadraticBezierTo(w * 0.04, h * 0.32, 0, h * 0.22)
      ..close();
    canvas.drawPath(land, Paint()..color = const Color(0xFFEFE7D6));
    // Bölge noktaları.
    for (int i = 0; i < kLaunchRegions.length; i++) {
      final LaunchRegion r = kLaunchRegions[i];
      final Offset p = Offset(r.nx * w, r.ny * h);
      if (i == selectedIndex) {
        canvas.drawCircle(
            p,
            12,
            Paint()
              ..color = DocklyColors.accentTurquoise.withValues(alpha: 0.35));
        canvas.drawCircle(p, 7, Paint()..color = DocklyColors.accentTurquoise);
        canvas.drawCircle(p, 2.6, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(p, 4.5, Paint()..color = const Color(0xFF7FA8CF));
      }
    }
  }

  @override
  bool shouldRepaint(_CoastPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}
