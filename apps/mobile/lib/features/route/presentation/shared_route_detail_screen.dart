import 'dart:async' show unawaited;

import 'package:dockly_api/dockly_api.dart'
    show GeoPoint, SharedRouteDetail, SharedRouteStop;
import 'package:dockly_core/dockly_core.dart' show AppFailure;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../community/application/reputation_controller.dart'
    show hasRealAccountProvider;
import '../../community/presentation/reputation_shell.dart'
    show formatCount, formatNm;
import '../../map/application/map_controller.dart';
import '../../profile/presentation/captain_profile_screen.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/shared_routes_controller.dart';
import '../domain/sea_trip.dart';

/// ROTA KARTI — paylaşılan rotanın detayı (Sosyalleşme Hafta 3, kurucu
/// onayı 2026-10-24; demodaki "Rota Kartı" ekranının gerçeği).
///
/// Gizlilik dürüstlüğü: yalnız paylaşanın seçtiği DURAKLAR görünür; konum
/// geçmişi yoktur. Mesafe/süre beyan etiketiyle sunulur. Yazar adı kaptan
/// profiline köprülüdür. Kaydet/Yaptım hesap ister — misafire kibar not.
class SharedRouteDetailScreen extends ConsumerStatefulWidget {
  const SharedRouteDetailScreen({required this.routeId, super.key});

  final String routeId;

  @override
  ConsumerState<SharedRouteDetailScreen> createState() =>
      _SharedRouteDetailScreenState();
}

class _SharedRouteDetailScreenState
    extends ConsumerState<SharedRouteDetailScreen> {
  bool _busy = false;

  Future<void> _toggle({required bool save}) async {
    final L10n t = ref.read(l10nProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!ref.read(hasRealAccountProvider)) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.rtSignInNote)));
      return;
    }
    setState(() => _busy = true);
    try {
      final gw = ref.read(sharedRoutesGatewayProvider);
      if (save) {
        await gw.toggleSave(widget.routeId);
      } else {
        await gw.toggleDone(widget.routeId);
      }
      ref.invalidate(sharedRouteDetailProvider(widget.routeId));
    } catch (error) {
      if (!mounted) return;
      // Ham istisna arayüze SIZMAZ (gözden geçirme kuralı).
      final String text = error is AppFailure ? error.message : t.rtLoadFailed;
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// HARİTADA AÇ (saha hatası 2026-10-26: "rotaya tıklıyorum, haritada
  /// açılmıyor"): duraklardan gerçek rota kurulur — ilk durak başlangıç,
  /// kalanlar sıralı duraklar; çizgiyi her zamanki deniz motoru çizer
  /// (kayıtlı rota açma mekanizmasının birebir aynısı). Ardından Keşfet'e
  /// dönülür ve bu sayfa kapanır — kaptan rotayı haritada bulur.
  void _openOnMap(SharedRouteDetail d) {
    final List<SharedRouteStop> stops = d.stops;
    if (stops.length < 2) return;
    final SharedRouteStop first = stops.first;
    final RouteOrigin origin = RouteOrigin(
      pos: GeoPoint(lat: first.lat!, lon: first.lon!),
      name: first.name,
    );
    final List<RouteWaypoint> waypoints = <RouteWaypoint>[
      for (final SharedRouteStop s in stops.skip(1))
        RouteWaypoint(
          pos: GeoPoint(lat: s.lat!, lon: s.lon!),
          id: s.locationId,
          name: s.name,
        ),
    ];
    unawaited(ref
        .read(mapControllerProvider.notifier)
        .openSavedRoute(origin, waypoints, name: d.summary.name));
    ref.read(shellTabProvider.notifier).state = 0; // Keşfet
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<SharedRouteDetail> async =
        ref.watch(sharedRouteDetailProvider(widget.routeId));
    return Scaffold(
      appBar: AppBar(title: Text(t.rtTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.rtLoadFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(sharedRouteDetailProvider(widget.routeId)),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (SharedRouteDetail d) => _body(context, t, d),
      ),
    );
  }

  Widget _body(BuildContext context, L10n t, SharedRouteDetail d) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(d.summary.name,
                  key: const ValueKey<String>('rtd-name'),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (d.status == 'pending')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(t.rtPendingChip,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8A6A12))),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          <String>[
            '${formatNm(t, d.summary.distanceNm)} nm',
            if (d.summary.durationHours != null)
              '≈ ${formatNm(t, d.summary.durationHours!)} sa',
            L10n.fmt(t.rtStopCountFmt, formatCount(t, d.summary.stopCount)),
            if (d.summary.season != null)
              L10n.fmt(t.rtSeasonFmt, d.summary.season!),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: sub),
        ),
        if (d.boatSuggestion != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(L10n.fmt(t.rtBoatFmt, d.boatSuggestion!),
              style: theme.textTheme.bodySmall?.copyWith(color: sub)),
        ],
        const SizedBox(height: 10),
        // YAZAR — kaptan profiline köprü (Hafta 1B ekranı).
        InkWell(
          key: const ValueKey<String>('rtd-author'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) =>
                    CaptainProfileScreen(userId: d.summary.authorId)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const DocklyIcon(DocklyIcons.sailing,
                    size: 15, color: DocklyColors.accentTurquoise),
                const SizedBox(width: 6),
                Text(d.summary.authorName,
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DocklyColors.brandPrimary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // HARİTADA AÇ — EN ÜSTTE (saha geri bildirimi 2026-10-26: "rotaya
        // basınca haritada göremiyorum" — düğme sayfanın altında kaldığı için
        // fark edilmiyordu; artık ilk bakışta görünür). Eski sunucu koordinat
        // göndermiyorsa düğme dürüstçe GİZLENİR (yarım rota çizilmez).
        if (d.stops.length >= 2 &&
            d.stops.every(
                (SharedRouteStop s) => s.lat != null && s.lon != null)) ...<Widget>[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey<String>('rtd-open-map'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => _openOnMap(d),
              icon: const DocklyIcon(DocklyIcons.navigation,
                  size: 16, color: Colors.white),
              label: Text(t.rtOpenMapBtn),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // DURAKLAR — çizgi yok; sıra numaralı liste (gizlilik dürüstlüğü).
        Text(t.rtStopsCap,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: .8, color: sub)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
          ),
          child: Column(
            children: <Widget>[
              for (final SharedRouteStop s in d.stops)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DocklyColors.brandPrimary
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${s.seq}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: DocklyColors.brandPrimary)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(s.name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // PAYLAŞANIN NOTLARI — deneyim + uyarılar.
        Text(t.rtExperienceCap,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: .8, color: sub)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
          ),
          child: Text(d.body, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('rtd-save'),
                onPressed: _busy ? null : () => _toggle(save: true),
                icon: DocklyIcon(
                    d.savedByMe ? DocklyIcons.favorite : DocklyIcons.favoriteBorder,
                    size: 16,
                    color: Colors.white),
                label: Text(
                    '${t.rtSaveBtn} · ${formatCount(t, d.summary.saveCount)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey<String>('rtd-done'),
                onPressed: _busy ? null : () => _toggle(save: false),
                child: Text(
                    '✓ ${t.rtDoneBtn} · ${formatCount(t, d.summary.doneCount)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // BEYAN DÜRÜSTLÜĞÜ — sarı bilgi kutusu (tekne kartıyla aynı dil).
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF2DFAE)),
          ),
          child: Text(
            'ℹ️ ${t.rtBeyanNote}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF7A5B12)),
          ),
        ),
      ],
    );
  }
}
