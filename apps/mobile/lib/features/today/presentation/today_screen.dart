import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../../core/widgets/section_card.dart';
import '../../checklist/presentation/checklist_sheet.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../../weather/presentation/weather_card.dart';
import '../application/suggestion_engine.dart';
import '../domain/day_suggestion.dart';

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
                  Text(
                    '${now.day}.${now.month}.${now.year}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFF3E0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
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
            // Seyir öncesi kontrol listesi — çıkmadan tamamla.
            SectionCard(
              icon: DocklyIcons.checkCircle,
              title: t.checklistTooltip,
              child: Align(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// GÜN IŞIĞI kimliği — Bugün ekranının vurgu rengi (onaylı tema).
const Color _amber = Color(0xFFF59E0B);

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
                      for (final DaySuggestion s in items)
                        _SuggestCard(suggestion: s),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
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

/// Tek öneri kartı: ad + tip + uygunluk hapı + NEDEN rozetleri.
/// Dokununca detay sayfası açılır (öneri asla kendi başına karar vermez).
class _SuggestCard extends ConsumerWidget {
  const _SuggestCard({required this.suggestion});

  final DaySuggestion suggestion;

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
    }
  }

  /// Uyarı rozetleri (rüzgâra açık / tekne sığmaz) kimlik rengiyle ASLA
  /// boyanmaz — onaylı tema kuralı: uyarı her ekranda uyarı rengindedir.
  static bool _isWarning(SuggestReasonKind k) =>
      k == SuggestReasonKind.exposed || k == SuggestReasonKind.boatTooBig;

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
                  // UYGUNLUK HAPI — karşılaştırma içindir, kesinlik değil.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      L10n.fmt(t.suggestScoreFmt, '${s.score}'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
