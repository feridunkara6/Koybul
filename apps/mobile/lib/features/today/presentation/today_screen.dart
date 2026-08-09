import 'package:dockly_api/dockly_api.dart' show GeoPoint, WeatherForecast;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../../core/widgets/section_card.dart';
import '../../checklist/application/checklist_controller.dart';
import '../../checklist/presentation/checklist_sheet.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../../map/presentation/route_origin_menu.dart' show startSeaRoute;
import '../../shell/application/shell_tab_provider.dart';
import '../../weather/application/weather_controller.dart';
import '../../weather/presentation/weather_card.dart';
import '../application/suggestion_engine.dart';
import '../domain/day_suggestion.dart';
import '../domain/day_summary.dart';

/// BUGÜN sekmesi (v2.0 vizyonu, kurucu onayı 2026-08): günlük alışkanlık
/// merkezi. İçerik GERÇEK verilerle sınırlıdır: günün hava/rüzgâr kartı
/// (MET Norway) + AKILLI KOY ÖNERİSİ ("Bugün Nereye?" — kural tabanlı,
/// NEDEN rozetli, kesinlik iddiasız) + seyir öncesi kontrol listesi.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    // Hava konumu: GPS varsa gerçek konum, yoksa haritada bakılan bölge.
    final GeoPoint? pos =
        ref.watch(devicePositionProvider) ?? ref.watch(originProvider);
    final DateTime now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            // GÜN IŞIĞI başlık kartı — Bugün'ün sıcak kimliği (onaylı tema).
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFF59E0B), Color(0xFFF97316)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.navToday,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // GÜN SATIRI (onaylı E2: "Çrş 7 Ağu"): haftanın günü kısa
                  // adıyla — kaptan hangi gün olduğunu bir bakışta görür.
                  Text(
                    '${t.weekdayShort[(now.weekday - 1) % 7]} '
                    '${now.day} ${t.monthShort[now.month - 1]}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFF3E0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // GÜNÜN ÖZETİ (onaylı E2): RÜZGÂR · EN İYİ SAAT · DENİZ.
            // Üçü de aynı tahminden türetilir; veri yoksa şerit çizilmez.
            if (pos != null) _DaySummaryStrip(pos: pos),
            // Günün havası — konum bilinmiyorsa dürüst yönlendirme.
            if (pos != null)
              WeatherCard(position: pos, accent: const Color(0xFFF59E0B))
            else
              SectionCard(
                icon: DocklyIcons.infoOutline,
                title: t.wxTitle,
                child: Text(
                  t.todayNoPos,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            // BUGÜN NEREYE? — akıllı öneri (yalnız konum varken; konum
            // yokken hava kartındaki dürüst yönlendirme zaten görünür).
            if (pos != null) _SuggestSection(pos: pos),
            // Seyir öncesi kontrol listesi — onaylı E2: ilerleme (0/10) ve
            // "çıkmadan tamamla" uyarısı kartın üstünde görünür.
            const _ChecklistCard(),
          ],
        ),
      ),
    );
  }
}

/// GÜN IŞIĞI kimliği — Bugün ekranının vurgu rengi (onaylı tema).
const Color _amber = Color(0xFFF59E0B);

/// SEYİR ÖNCESİ KONTROL kartı: kaç madde işaretlendi + listeyi aç.
class _ChecklistCard extends ConsumerWidget {
  const _ChecklistCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final ChecklistState s = ref.watch(checklistProvider);
    final int mask =
        ref.read(checklistProvider.notifier).maskFor(DateTime.now());
    int checked = 0;
    for (int i = 0; i < kChecklistItemCount; i++) {
      if ((mask >> i) & 1 == 1) checked++;
    }
    final bool allDone = s.ready && checked == kChecklistItemCount;
    return SectionCard(
      icon: DocklyIcons.checkCircle,
      title: t.checklistTooltip,
      accent: allDone ? DocklyColors.success : _amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            allDone
                ? t.checklistAllDone
                : L10n.fmt2(t.checklistProgressFmt, '$checked',
                    '$kChecklistItemCount'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: allDone
                  ? DocklyColors.success
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey<String>('today-checklist'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: () => showChecklistSheet(context),
              child: Text(t.checklistOpenBtn),
            ),
          ),
        ],
      ),
    );
  }
}

/// GÜNÜN ÖZETİ ŞERİDİ (onaylı E2): RÜZGÂR · EN İYİ SAAT · DENİZ.
/// Hepsi aynı MET Norway tahmininden türetilir. Tahmin gelmediyse ya da
/// hesaplanamıyorsa şerit HİÇ çizilmez (0-uydurma).
class _DaySummaryStrip extends ConsumerWidget {
  const _DaySummaryStrip({required this.pos});

  final GeoPoint pos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<WeatherForecast> wx =
        ref.watch(weatherForecastProvider(weatherKeyFor(pos.lat, pos.lon)));
    // valueOrNull ŞART (CI dersi 2026-08): AsyncValue.value hata durumunda
    // hatayı YENİDEN FIRLATIR — ağ yokken bütün Bugün ekranı çökerdi.
    final DaySummary? s = summarizeDay(wx.valueOrNull);
    if (s == null) return const SizedBox.shrink();
    final String seaLabel = switch (s.sea) {
      SeaState.calm => t.seaCalm,
      SeaState.light => t.seaLight,
      SeaState.choppy => t.seaChoppy,
      SeaState.rough => t.seaRough,
      SeaState.veryRough => t.seaVeryRough,
    };
    final String range = s.maxKn - s.minKn < 1
        ? '${s.maxKn.round()}'
        : '${s.minKn.round()}-${s.maxKn.round()}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      // EŞİT BOY (detay ekranından gelen ders): liste içinde yükseklik
      // SINIRSIZDIR — stretch kullanan Row IntrinsicHeight ile sarılmazsa
      // "sonsuz yükseklik" hatası verir.
      child: IntrinsicHeight(
        child: Row(
          key: const ValueKey<String>('today-summary'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _SummaryTile(
                caption: t.todayWindCap,
                value: L10n.fmt2(
                    t.todayWindRangeFmt, range, t.compassDir(s.dirTr)),
              ),
            ),
            const SizedBox(width: 8),
            if (s.bestFromHour != null && s.bestToHour != null) ...<Widget>[
              Expanded(
                child: _SummaryTile(
                  caption: t.todayBestCap,
                  value: L10n.fmt2(
                    t.todayBestFmt,
                    s.bestFromHour!.toString().padLeft(2, '0'),
                    s.bestToHour!.toString().padLeft(2, '0'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _SummaryTile(caption: t.todaySeaCap, value: seaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Özet kutusu: küçük başlık + belirgin değer. Değer sığmazsa küçülür.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.10),
        border: Border.all(color: _amber.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              caption,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// "BUGÜN NEREYE?" bölümü: kural tabanlı öneriler, NEDEN rozetleri ve
/// uygunluk puanıyla. Dürüstlük: alt satırda "karar kaptanındır" notu;
/// veri eksikse rozet bunu açıkça söyler; hata/boşlukta dürüst metin.
class _SuggestSection extends ConsumerWidget {
  const _SuggestSection({required this.pos});

  final GeoPoint pos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<DaySuggestion>> sugg =
        ref.watch(daySuggestionsProvider(suggestKeyFor(pos)));
    return SectionCard(
      icon: DocklyIcons.star,
      title: t.suggestTitle,
      accent: _amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            t.suggestLead,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          sugg.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
            error: (Object e, StackTrace st) => Text(
              t.suggestFail,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            data: (List<DaySuggestion> items) => items.isEmpty
                ? Text(
                    t.suggestEmpty,
                    style:
                        theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  )
                : Column(
                    children: <Widget>[
                      // ANİMASYON (onaylı E2): kartlar SIRAYLA yumuşak belirir.
                      for (int i = 0; i < items.length; i++)
                        _FadeInUp(
                          delayMs: i * 90,
                          child: _SuggestCard(
                            suggestion: items[i],
                            rank: i + 1,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          // TAHMİN KAYNAĞI + SAATİ (onaylı E2: "Tahmin: MET Norway 06:00").
          _ForecastSourceLine(pos: pos),
          const SizedBox(height: 4),
          // DÜRÜSTLÜK NOTU: öneri tahmindir, karar kaptanındır.
          Text(
            t.suggestDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tahmin kaynağı satırı — hangi servis, hangi saatte alındı.
class _ForecastSourceLine extends ConsumerWidget {
  const _ForecastSourceLine({required this.pos});

  final GeoPoint pos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<WeatherForecast> wx =
        ref.watch(weatherForecastProvider(weatherKeyFor(pos.lat, pos.lon)));
    // Aynı ders: hata varsa satır çizilmez, ekran çökmez.
    final WeatherForecast? f = wx.valueOrNull;
    if (f == null) return const SizedBox.shrink();
    final DateTime at = f.fetchedAt.toLocal();
    final String hm = '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    return Text(
      L10n.fmt2(t.suggestSourceFmt, f.attribution, hm),
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Sırayla yumuşak beliren sarmalayıcı (onaylı E2 animasyonu).
class _FadeInUp extends StatelessWidget {
  const _FadeInUp({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + delayMs),
      curve: Interval(
        // Gecikme, eğrinin başına yerleştirilir — ek zamanlayıcı gerekmez
        // (testlerde bekleyen Timer bırakmaz).
        delayMs / (340 + delayMs),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (BuildContext context, double v, Widget? c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: c),
      ),
      child: child,
    );
  }
}

/// Tek öneri kartı: sıra no + ad + tip + uygunluk HALKASI + NEDEN rozetleri
/// + "Rota çiz". Dokununca detay sayfası açılır (öneri karar vermez).
class _SuggestCard extends ConsumerWidget {
  const _SuggestCard({required this.suggestion, required this.rank});

  final DaySuggestion suggestion;

  /// Listedeki sıra (1, 2, 3) — onaylı tasarımda numaralı gösterilir.
  final int rank;

  /// Rozet metni — türü ve dili arayüz belirler (0 uydurma: yalnız
  /// gerekçesi olan rozet gelir).
  static String _reasonLabel(L10n t, SuggestReason r) {
    switch (r.kind) {
      case SuggestReasonKind.sheltered:
        return t.suggestSheltered;
      case SuggestReasonKind.exposed:
        return L10n.fmt2(
          t.suggestExposedFmt,
          t.windExposedLabel(r.dir ?? ''),
          (r.windKn ?? 0).toStringAsFixed(0),
        );
      case SuggestReasonKind.near:
        final double nm = r.nm ?? 0;
        return L10n.fmt(t.suggestNearFmt,
            nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1));
      case SuggestReasonKind.exposureUnknown:
        return t.suggestNoWindInfo;
      case SuggestReasonKind.boatFits:
        return t.suggestBoatFits;
      case SuggestReasonKind.boatTooBig:
        return t.suggestBoatTooBig;
      case SuggestReasonKind.eta:
        final double nm = r.nm ?? 0;
        final double h = r.etaHours ?? 0;
        final int hh = h.floor();
        final int mm = ((h - hh) * 60).round();
        return L10n.fmt2(
          t.suggestEtaFmt,
          nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1),
          hh > 0
              ? L10n.fmt2(t.etaHmFmt, '$hh', '$mm')
              : L10n.fmt(t.etaMFmt, '$mm'),
        );
      case SuggestReasonKind.depth:
        final double? a = r.depthMinM;
        final double? b = r.depthMaxM;
        final String range = (a != null && b != null && b > a)
            ? '${_num(a)}-${_num(b)}'
            : _num((a ?? b)!);
        return L10n.fmt(t.suggestDepthFmt, range);
      case SuggestReasonKind.bottom:
        return L10n.fmt(t.suggestBottomFmt, t.holdingLabel(r.bottomCode ?? ''));
      case SuggestReasonKind.crowded:
        return t.suggestCrowded;
      case SuggestReasonKind.quiet:
        return t.suggestQuiet;
    }
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Uyarı rozetleri (rüzgâra açık / tekne sığmaz / dolu) kimlik rengiyle
  /// ASLA boyanmaz — onaylı tema kuralı: uyarı her ekranda uyarı rengindedir.
  static bool _isWarning(SuggestReasonKind k) =>
      k == SuggestReasonKind.exposed ||
      k == SuggestReasonKind.boatTooBig ||
      k == SuggestReasonKind.crowded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DaySuggestion s = suggestion;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        key: ValueKey<String>('suggest-${s.place.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) =>
                LocationDetailScreen(idOrSlug: s.place.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // SIRA NUMARASI (onaylı E2: "1. Kille Koyu %92 uygun").
                  Text(
                    '$rank.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          t.typeLabel(s.place.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // UYGUNLUK HALKASI (onaylı E2 animasyonu: halka dolarak
                  // çizilir) — karşılaştırma içindir, kesinlik iddiası değil.
                  _ScoreRing(
                    score: s.score,
                    label: t.suggestScoreFmt,
                    pct: t.suggestScorePctFmt,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // NEDEN ROZETLERİ — öneri gerekçesini şeffaf yapar.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final SuggestReason r in s.reasons)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isWarning(r.kind)
                            ? DocklyColors.warning.withValues(alpha: 0.14)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _reasonLabel(t, r),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _isWarning(r.kind)
                              ? const Color(0xFF92400E)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // ROTA ÇİZ (onaylı E2): öneriden tek dokunuşla haritada rota.
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: ValueKey<String>('suggest-route-${s.place.id}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: _amber,
                    foregroundColor: const Color(0xFF3B2200),
                  ),
                  onPressed: () => startSeaRoute(
                    context,
                    ref,
                    destPos: s.place.position,
                    destId: s.place.id,
                    destName: s.place.name,
                    // Rota çizilince Keşfet sekmesine geçilir — kaptan
                    // rotayı haritada görür (onaylı akış: öneri → rota).
                    onRouted: () =>
                        ref.read(shellTabProvider.notifier).state = 0,
                  ),
                  icon: const DocklyIcon(DocklyIcons.navigation,
                      size: 15, color: Color(0xFF3B2200)),
                  label: Text(t.suggestRouteBtn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// UYGUNLUK HALKASI: yüzdeyi dolarak çizilen ince bir halka içinde gösterir.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.score,
    required this.label,
    required this.pct,
  });

  final int score;

  /// '%{0} uygun' şablonu — erişilebilirlik etiketinde tam metin kullanılır.
  final String label;

  /// Halka içindeki kısa yüzde şablonu ('%{0}' / '{0}%').
  final String pct;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: L10n.fmt(label, '$score'),
      child: SizedBox(
        width: 44,
        height: 44,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double v, Widget? _) => Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 4,
                  backgroundColor: _amber.withValues(alpha: 0.16),
                  valueColor: const AlwaysStoppedAnimation<Color>(_amber),
                ),
              ),
              Text(
                // Yüzde biçimi dile göre değişir (TR "%90", EN "90%").
                L10n.fmt(pct, '$score'),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
