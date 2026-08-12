import 'package:dockly_api/dockly_api.dart' show LocationSummary;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../search/presentation/search_screen.dart';
import '../domain/launch_answers.dart';

/// SORU EKRANLARI — E3 / E4 / E5 (onaylı tasarım 2026-08).
///
/// Ortak iskelet: ilerleme çubuğu + "Soruları atla" (kalan TÜM soruları
/// atlar — onaylı iyileştirme), başlık, alt başlık, içerik, CTA ve
/// "Profil'den değiştirilebilir" notu. Her cevap isteğe bağlıdır; atlayan
/// kullanıcı cevaplayanla AYNI haritayı görür.
class QuestionShell extends ConsumerWidget {
  const QuestionShell({
    required this.stepIndex, // 1..kLaunchQuestionCount
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
                                value: stepIndex / kLaunchQuestionCount,
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
// E3 — TEKNE TİPİ: KALDIRILDI (Faz 1)
//
// Kullanıcıya sorulan İLK soruydu ve cevabı hiçbir yerde okunmuyordu
// (bkz. launch_answers.dart). Bir soruyu sormanın bedeli var: ilk iki
// dakikada en çok kullanıcı kaybediliyor. Karşılığı olmayan soru
// sorulmaz.
// ============================================================================

// ============================================================================
// E4 — BOY + SU ÇEKİMİ
// ============================================================================

class BoatSizeScreen extends ConsumerStatefulWidget {
  const BoatSizeScreen({
    required this.initialLengthM,
    required this.initialDraftM,
    required this.onContinue,
    required this.onSkipAll,
    this.initialName,
    this.initialMarina,
    super.key,
  });

  final double initialLengthM;
  final double initialDraftM;
  final String? initialName;
  final LocationSummary? initialMarina;

  /// Ölçülere ek: tekne adı ve bağlı marina (kullanıcı isteği 2026-08).
  /// İkisi de İSTEĞE BAĞLI — boş bırakan kullanıcı aynen devam eder.
  final void Function(
    double lengthM,
    double draftM,
    String? boatName,
    LocationSummary? homeMarina,
  ) onContinue;
  final VoidCallback onSkipAll;

  @override
  ConsumerState<BoatSizeScreen> createState() => _BoatSizeScreenState();
}

class _BoatSizeScreenState extends ConsumerState<BoatSizeScreen> {
  late double _len = widget.initialLengthM.clamp(6.0, 30.0);
  late double _draft = widget.initialDraftM.clamp(0.5, 4.0);
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  late LocationSummary? _marina = widget.initialMarina;

  /// Repo genelindeki sayı biçimi (nokta ondalık): 12 → '12', 12.5 → '12.5'.
  static String _m(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _continue() {
    final String name = _name.text.trim();
    widget.onContinue(_len, _draft, name.isEmpty ? null : name, _marina);
  }

  /// Bağlı marinayı MEVCUT arama ekranıyla seçtirir (yeni liste kurulmaz;
  /// arama sunucusu ad/yer bilir). Seçim kipi sonucu geri döndürür.
  Future<void> _pickMarina() async {
    final LocationSummary? picked =
        await Navigator.of(context).push<LocationSummary>(
      MaterialPageRoute<LocationSummary>(
        builder: (BuildContext _) => SearchScreen(
          pickDestination: true,
          pickHint: ref.read(l10nProvider).marinaPickTitle,
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _marina = picked);
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    return QuestionShell(
      stepIndex: 1,
      title: t.qSizeTitle,
      subtitle: t.qSizeSub,
      ctaLabel: t.qContinue,
      onCta: _continue,
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
          const SizedBox(height: 14),
          // TEKNE ADI + BAĞLI MARİNA (kullanıcı isteği 2026-08). İkisi de
          // isteğe bağlı: soru sayısı artmaz, aynı ekranda iki hafif alan.
          _NameAndMarinaCard(
            nameController: _name,
            marina: _marina,
            onPickMarina: _pickMarina,
            onClearMarina: () => setState(() => _marina = null),
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

/// Tekne adı + bağlı marina kartı (kullanıcı isteği 2026-08). Ad serbest
/// metindir; marina MEVCUT arama ekranından seçilir (uydurma liste yok —
/// kayıtlarımızdan gelir). Marina seçilince kazanç cümlesi görünür:
/// "Haritayı {marina} çevresinde açarız."
class _NameAndMarinaCard extends ConsumerWidget {
  const _NameAndMarinaCard({
    required this.nameController,
    required this.marina,
    required this.onPickMarina,
    required this.onClearMarina,
  });

  final TextEditingController nameController;
  final LocationSummary? marina;
  final VoidCallback onPickMarina;
  final VoidCallback onClearMarina;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final LocationSummary? m = marina;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: DocklyColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            t.qBoatNameLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DocklyColors.text2,
            ),
          ),
          TextField(
            key: const ValueKey<String>('launch-boat-name'),
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: InputDecoration(
              hintText: t.qBoatNameHint,
              counterText: '',
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t.qMarinaLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DocklyColors.text2,
            ),
          ),
          const SizedBox(height: 8),
          if (m == null)
            OutlinedButton.icon(
              key: const ValueKey<String>('launch-marina-pick'),
              onPressed: onPickMarina,
              icon: const DocklyIcon(DocklyIcons.search, size: 16),
              label: Text(t.qMarinaPick),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    key: const ValueKey<String>('launch-marina-change'),
                    onTap: onPickMarina,
                    child: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DocklyColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('launch-marina-clear'),
                  tooltip: t.clearTooltip,
                  icon: const DocklyIcon(DocklyIcons.clear, size: 16),
                  onPressed: onClearMarina,
                ),
              ],
            ),
          if (m != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '✓  ${L10n.fmt(t.qMarinaBenefit, m.name)}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF155E56)),
            ),
          ],
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
      stepIndex: 2,
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
