import 'dart:async' show unawaited;

import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../location/application/location_controller.dart';
import '../../map/application/map_controller.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../../logbook/application/logbook_controller.dart';
import '../../logbook/domain/log_entry.dart';
import '../../logbook/presentation/logbook_screen.dart'
    show LogbookBody, showLogEntryEditor;
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/presentation/tour_targets.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/saved_route.dart';
import '../../route/domain/sea_route.dart' show haversineNm;
import '../../route/domain/sea_trip.dart';
import '../../route/presentation/saved_routes_screen.dart' show SavedRouteCard;
import '../application/trip_log_controller.dart';
import '../domain/sea_trip_log.dart';

/// Defter segmenti: 0 = Seyirler · 1 = Rotalarım · 2 = Notlar.
///
/// TEK EV TAMİRİ (UX denetimi P1, kullanıcı onayı 2026-08): segment artık
/// SAĞLAYICIDA tutulur — Profil'deki "Kaptanın Günlüğü" satırı ayrı bir
/// ekran açmak yerine Defter sekmesine geçip bu segmenti Notlar'a çevirir.
/// Aynı içerik iki kapıdan açılmaz; kapı tek, ev tek.
final StateProvider<int> deckSegmentProvider = StateProvider<int>((ref) => 0);

/// DEFTER sekmesi (v2.0 vizyonu, kurucu onayı 2026-08): denizcinin arşivi.
/// Üç bölüm: SEYİRLER (planlanan + gerçekleşen seferler, sezon özeti) ·
/// ROTALARIM · NOTLAR (eski Günlük). Seyir akışı (v2.1): haritada rota çiz →
/// "Seyri planla" → buradaki PLANLANDI kartında "Gerçekleşti ✓" → deftere
/// işlenir. İki-dokunuşlu başlat/bitir modeli emekli (tasarım raporu §9).
class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    // ÖRNEKLİ TUR: Defter adımında Rotalarım segmenti gösterilir ve ÖRNEK
    // rozetli kart eklenir (kalıcı değildir; adım geçince kaybolur —
    // kullanıcının kendi segment tercihi sağlayıcıda el değmeden korunur).
    final bool tourDemo = ref.watch(onboardingControllerProvider
            .select((OnboardingState s) => s.tourStep)) ==
        kTourStepSaved;
    final int seg = tourDemo ? 1 : ref.watch(deckSegmentProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.navDeck)),
      // Not ekleme yalnız Notlar segmentinde (heroTag: Günlük ekranındaki
      // FAB ile Hero çakışması olmasın — ikisi de açık olabilir).
      floatingActionButton: seg == 2
          ? FloatingActionButton.extended(
              heroTag: 'deck-note-fab',
              key: const ValueKey<String>('deck-note-new'),
              onPressed: () => showLogEntryEditor(context, ref),
              icon: const DocklyIcon(DocklyIcons.edit,
                  size: 18, color: Colors.white),
              label: Text(t.logbookNew),
              backgroundColor: DocklyColors.brandPrimary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: <Widget>[
          // Segment şeridi YATAY KAYDIRILABİLİR (CI dersi 2026-08: üç çip
          // dar telefon ekranına sığmayıp taşıyordu — RenderFlex overflow).
          // Kaydırma her dilde/yazı boyutunda taşmayı imkânsız kılar.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: <Widget>[
                _SegChip(
                  label: t.deckTabTrips,
                  selected: seg == 0,
                  onTap: () =>
                      ref.read(deckSegmentProvider.notifier).state = 0,
                ),
                const SizedBox(width: 8),
                _SegChip(
                  label: t.deckTabRoutes,
                  selected: seg == 1,
                  onTap: () =>
                      ref.read(deckSegmentProvider.notifier).state = 1,
                ),
                const SizedBox(width: 8),
                _SegChip(
                  label: t.deckTabNotes,
                  selected: seg == 2,
                  onTap: () =>
                      ref.read(deckSegmentProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
          Expanded(
            child: seg == 0
                ? const _TripsTab()
                : seg == 1
                    ? _RoutesTab(tourDemo: tourDemo)
                    : const LogbookBody(),
          ),
        ],
      ),
    );
  }
}

/// SEYİRLER bölümü (v2.1 "Planla → Gerçekleşti", kurucu onayı 2026-08):
/// planlanan seferler üstte (eylem düğmeli), gerçekleşenler altta; sezon
/// özeti YALNIZ gerçekleşenlerden beslenir. Eski "süren seyir" kartı
/// kaldırıldı (başlat/bitir modeli emekli — tasarım raporu §9).
class _TripsTab extends ConsumerWidget {
  const _TripsTab();

  /// Dakikayı "%s sa %s dk" / "%s dk" biçiminde yazar (rota süresiyle aynı dil).
  static String _fmtDuration(L10n t, int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return h > 0 ? L10n.fmt2(t.etaHmFmt, '$h', '$m') : L10n.fmt(t.etaMFmt, '$m');
  }

  static String _fmtNm(double nm) =>
      nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<SeaTripLog> trips = ref.watch(tripLogProvider);
    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.tripsEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final List<SeaTripLog> planned = <SeaTripLog>[
      for (final SeaTripLog x in trips)
        if (x.isPlanned) x,
    ];
    final List<SeaTripLog> done = <SeaTripLog>[
      for (final SeaTripLog x in trips)
        if (!x.isPlanned) x,
    ];
    // SEZON ÖZETİ: içinde bulunulan yılın GERÇEKLEŞEN seferleri (0-uydurma:
    // plan istatistik değildir; süre yalnız bilinen kayıtlardan toplanır).
    final int year = DateTime.now().year;
    final List<SeaTripLog> season = <SeaTripLog>[
      for (final SeaTripLog x in done)
        if (DateTime.fromMillisecondsSinceEpoch(x.dateMs).year == year) x,
    ];
    double seasonNm = 0;
    int seasonMin = 0;
    for (final SeaTripLog x in season) {
      seasonNm += x.distanceNm;
      seasonMin += x.durMin ?? 0;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
      children: <Widget>[
        if (season.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF0E3052), Color(0xFF071626)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  L10n.fmt(t.tripSeasonFmt, '$year'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7FE3D9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SeasonStat(
                        caption: t.deckTabTrips,
                        value: '${season.length}',
                      ),
                    ),
                    Expanded(
                      child: _SeasonStat(
                        caption: t.routeStatDistance,
                        value: '≈ ${_fmtNm(seasonNm)} ${t.nmUnit}',
                      ),
                    ),
                    Expanded(
                      child: _SeasonStat(
                        caption: t.routeStatDuration,
                        value: _fmtDuration(t, seasonMin),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // PLANLANANLAR üstte (eylem bekleyen kartlar), GERÇEKLEŞENLER altta
        // (arşiv). Her grup kendi içinde tarihçe sırasında (en yeni başta).
        for (final SeaTripLog x in planned) _PlannedTripCard(trip: x),
        for (final SeaTripLog x in done) _TripCard(trip: x),
      ],
    );
  }
}

/// Sezon kartı hücresi: küçük başlık + belirgin beyaz değer.
class _SeasonStat extends StatelessWidget {
  const _SeasonStat({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            caption,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFB8CBE0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
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
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// PLANLANAN sefer kartı: PLANLANDI rozeti + rota adı + ≈ mesafe + plan
/// tarihi + "Gerçekleşti ✓" düğmesi. Plan istatistiklere sayılmaz; kaptan
/// seferi yaptığında alttan açılan onay sayfasıyla deftere işler.
class _PlannedTripCard extends ConsumerWidget {
  const _PlannedTripCard({required this.trip});

  final SeaTripLog trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(trip.dateMs);
    final String stats = <String>[
      '${d.day}.${d.month}.${d.year}',
      if (trip.distanceNm > 0)
        '≈ ${_TripsTab._fmtNm(trip.distanceNm)} ${t.nmUnit}',
      if (trip.stops > 0) '${t.routeStatStops}: ${trip.stops}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: DocklyColors.brandPrimary.withValues(alpha: 0.08),
        border: Border.all(
          color: DocklyColors.brandPrimary.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DocklyColors.brandPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.tripPlannedBadge,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(trip.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(stats, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.tripDeleteTooltip,
                icon: DocklyIcon(DocklyIcons.deleteOutline,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () =>
                    ref.read(tripLogProvider.notifier).remove(trip.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                key: ValueKey<String>('trip-done-${trip.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _showMarkDoneSheet(context, trip),
                child: Text(t.tripMarkDone),
              ),
              // ROTA BİRLEŞTİRME (v2.2, kurucu onayı 2026-08): plan rotayı
              // taşıyorsa buradan haritaya geri çağrılır — kayıtlı rotayla
              // AYNI dürüst yol: çizgi saklanmaz, aynı motorla yeniden
              // hesaplanır. Rotasız eski planlarda düğme çıkmaz (0-uydurma).
              if (trip.hasRoute)
                OutlinedButton(
                  key: ValueKey<String>('trip-open-${trip.id}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => _openOnMap(context, ref),
                  child: Text(t.savedOpenBtn),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Haritada aç" — kayıtlı rota kartıyla aynı akış: Konumum başlangıçlı
  /// planda GPS yoksa izin akışı kendiliğinden başlar; izin gelmezse dürüst
  /// uyarı. Rota kurulunca Keşfet sekmesine dönülür.
  Future<void> _openOnMap(BuildContext context, WidgetRef ref) async {
    final RouteOrigin origin = trip.routeOrigin!;
    if (origin.isDevice && ref.read(devicePositionProvider) == null) {
      await ref.read(locationControllerProvider.notifier).locateMe();
      if (!context.mounted) return;
      if (ref.read(devicePositionProvider) == null) {
        final L10n t = ref.read(l10nProvider);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(t.routeNeedOrigin),
            duration: const Duration(seconds: 6),
          ));
        return;
      }
    }
    unawaited(ref
        .read(mapControllerProvider.notifier)
        .openSavedRoute(origin, trip.routeWaypoints!, name: trip.name));
    ref.read(shellTabProvider.notifier).state = 0; // Keşfet'e dön
  }
}

/// "Gerçekleşti" onay sayfasını alttan açar (klavye için inset korumalı).
void _showMarkDoneSheet(BuildContext context, SeaTripLog trip) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _MarkDoneSheet(trip: trip),
    ),
  );
}

/// GERÇEKLEŞTİ onayı: tarih (Bugün/Dün/Tarih seç) + isteğe bağlı süre çipleri
/// + isteğe bağlı not (Kaptanın Günlüğü'ne düşer). Tek zorunlu bilgi tarih —
/// varsayılan Bugün; iki dokunuşla iş biter (tasarım raporu §5).
class _MarkDoneSheet extends ConsumerStatefulWidget {
  const _MarkDoneSheet({required this.trip});

  final SeaTripLog trip;

  @override
  ConsumerState<_MarkDoneSheet> createState() => _MarkDoneSheetState();
}

class _MarkDoneSheetState extends ConsumerState<_MarkDoneSheet> {
  /// Seçili sefer günü (gün hassasiyeti yeter — saat iddiası yok).
  late DateTime _day;

  /// 0 = Bugün · 1 = Dün · 2 = takvimden seçildi.
  int _dayChoice = 0;

  /// Denizde geçen süre (dk) — null = belirtilmedi (dürüst boşluk).
  int? _durMin;

  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = DateTime.now();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(now) ? now : _day,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = picked;
      _dayChoice = 2;
    });
  }

  Future<void> _save() async {
    final L10n t = ref.read(l10nProvider);
    // Öğlen 12:00 sabitlenir: gün doğru, saat iddiasız (yaz saati sınırında
    // gün kaymasın diye gece yarısı yerine gün ortası).
    final int dateMs =
        DateTime(_day.year, _day.month, _day.day, 12).millisecondsSinceEpoch;
    await ref
        .read(tripLogProvider.notifier)
        .markDone(widget.trip.id, dateMs: dateMs, durMin: _durMin);
    // Not düşüldüyse Kaptanın Günlüğü'ne rota bağlamıyla işlenir — hikâye
    // Notlar'da, sayılar Seyirler'de (tek ev ilkesiyle uyumlu ayrım).
    final String note = _note.text.trim();
    if (note.isNotEmpty) {
      await ref.read(logbookProvider.notifier).add(LogEntry(
            id: 'l${DateTime.now().millisecondsSinceEpoch}',
            dateMs: dateMs,
            text: note,
            ctxRoute: widget.trip.name,
            ctxNm: widget.trip.distanceNm > 0 ? widget.trip.distanceNm : null,
            ctxStops: widget.trip.stops > 0 ? widget.trip.stops : null,
          ));
    }
    if (!mounted) return;
    // Mesajcı POP'TAN ÖNCE alınır: sayfa kapanınca bu context ağaçtan düşer,
    // sonradan ScaffoldMessenger.of araması sorun çıkarabilirdi.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(t.tripDoneSnack)));
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(t.tripDoneSheetTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(widget.trip.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const ValueKey<String>('trip-done-today'),
                  label: Text(t.dateToday),
                  selected: _dayChoice == 0,
                  onSelected: (_) => setState(() {
                    _dayChoice = 0;
                    _day = today;
                  }),
                ),
                ChoiceChip(
                  key: const ValueKey<String>('trip-done-yesterday'),
                  label: Text(t.dateYesterday),
                  selected: _dayChoice == 1,
                  onSelected: (_) => setState(() {
                    _dayChoice = 1;
                    _day = today.subtract(const Duration(days: 1));
                  }),
                ),
                ChoiceChip(
                  key: const ValueKey<String>('trip-done-pick'),
                  label: Text(_dayChoice == 2
                      ? '${_day.day}.${_day.month}.${_day.year}'
                      : t.datePickLabel),
                  selected: _dayChoice == 2,
                  onSelected: (_) => _pickDay(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(t.tripDurQ,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (String, int) c in <(String, int)>[
                  (t.dur2h, 120),
                  (t.durHalf, 240),
                  (t.durFull, 480),
                ])
                  ChoiceChip(
                    label: Text(c.$1),
                    selected: _durMin == c.$2,
                    // İkinci dokunuş seçimi kaldırır — süre isteğe bağlıdır.
                    onSelected: (bool sel) =>
                        setState(() => _durMin = sel ? c.$2 : null),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: t.tripNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('trip-done-save'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _save,
                child: Text(t.tripDoneSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GERÇEKLEŞEN sefer kartı: ad + tarih + plan mesafesi (≈) + süre (yalnız
/// biliniyorsa — yeni akışta süre isteğe bağlıdır, uydurma değer yazılmaz).
class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip});

  final SeaTripLog trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(trip.dateMs);
    final String date = '${d.day}.${d.month}.${d.year}';
    final String stats = <String>[
      if (trip.durMin != null) _TripsTab._fmtDuration(t, trip.durMin!),
      if (trip.distanceNm > 0)
        '≈ ${_TripsTab._fmtNm(trip.distanceNm)} ${t.nmUnit}',
      if (trip.stops > 0) '${t.routeStatStops}: ${trip.stops}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(date,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: DocklyColors.brandPrimary,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(trip.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(stats, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: t.tripDeleteTooltip,
            icon: DocklyIcon(DocklyIcons.deleteOutline,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () =>
                ref.read(tripLogProvider.notifier).remove(trip.id),
          ),
        ],
      ),
    );
  }
}

/// Segment çipi — Defter içi sekme (Rotalarım / Notlar).
class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? DocklyColors.brandPrimary.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? DocklyColors.brandPrimary.withValues(alpha: 0.5)
                : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? DocklyColors.brandPrimary : null,
          ),
        ),
      ),
    );
  }
}

class _RoutesTab extends ConsumerWidget {
  const _RoutesTab({required this.tourDemo});

  final bool tourDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<SavedRoute> routes = ref.watch(savedRoutesProvider);
    if (routes.isEmpty && !tourDemo) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.savedEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: <Widget>[
        if (tourDemo)
          KeyedSubtree(
            key: tourKeySavedDemo,
            child: const _DeckDemoRouteCard(),
          ),
        for (final SavedRoute r in routes) SavedRouteCard(route: r),
      ],
    );
  }
}

/// ÖRNEKLİ TUR kartı (Defter adımı): gerçek karta birebir benzer, ÖRNEK
/// rozetlidir, dokunulamaz ve kalıcı değildir. Mesafe gerçek kuş uçuşudur.
class _DeckDemoRouteCard extends ConsumerWidget {
  const _DeckDemoRouteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final SavedRoute demo = SavedRoute(
      id: 'tour-demo-route',
      // "Göcek" özel addır — çevrilmez (koy isimleri kuralı).
      name: t.tourDemoRouteName,
      origin: const RouteOrigin(pos: kTourDemoOrigin, name: 'Göcek'),
      waypoints: <RouteWaypoint>[
        RouteWaypoint(pos: kTourDemoDest, name: t.tourDemoStop),
      ],
      distanceNm: haversineNm(kTourDemoOrigin, kTourDemoDest),
      savedAtMs: 0,
    );
    return Stack(
      children: <Widget>[
        IgnorePointer(child: SavedRouteCard(route: demo)),
        Positioned(
          top: 6,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DocklyColors.brandPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t.tourDemoBadge,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
