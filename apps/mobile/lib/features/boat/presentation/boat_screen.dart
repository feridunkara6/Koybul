import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../deck/presentation/deck_screen.dart' show deckSegmentProvider;
import '../../launch/domain/launch_answers.dart' show kHomeMarinaFocusZoom;
import '../../map/application/map_controller.dart' show mapFocusProvider;
import '../../map/domain/map_viewport.dart' show MapFocusRequest;
import '../../onboarding/presentation/tour_targets.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/maintenance_controller.dart';
import '../application/my_boat_controller.dart';
import '../data/maintenance_catalog.dart';
import '../domain/maintenance.dart';
import '../domain/my_boat.dart';
import 'boat_sheet.dart';
import 'maintenance_screen.dart';

/// TEKNEM sekmesi — KONSEPT A: tek sayfa + aşamalı açılım (UX denetimi P1,
/// kullanıcı onayı 2026-08). "Teknemin kimlik kartı cebimde" ruhu: ilk bakış
/// ÜÇ karta iner ve hiçbir özellik silinmez:
///
///  1) KİMLİK KARTI — ad büyük, düzenleme sağ üstte kalem ikonu (tek CTA
///     kuralı), ölçüler + bağlı marina; marina satırına dokunmak haritayı
///     marina çevresinde açar.
///  2) BAKIM ÖZETİ — tek satır: "N kalem ilgi bekliyor" / "hepsi güncel".
///     Dokununca tam liste kendi ekranında (MaintenanceScreen — içerik
///     birebir taşındı).
///  3) DEFTER KÖPRÜSÜ — sezon istatistiği Teknem'de KOPYALANMAZ (tek ev);
///     köprü Defter'in Seyirler bölümüne götürür.
///
/// "Denizci Profilim" kartı buradan Profil sekmesine taşındı — o kaptanın
/// kimliğidir, teknenin değil (rapor bölüm 4/5, onaylı karar).
class BoatScreen extends ConsumerWidget {
  const BoatScreen({super.key});

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final MyBoat? boat = ref.watch(myBoatProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.navBoat)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          // Tur hedefi: "Teknem" adımı bu kimlik kartını vurgular.
          KeyedSubtree(
            key: tourKeyBoatCard,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0E8577), Color(0xFF071626)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const DocklyIcon(DocklyIcons.sailing,
                          size: 22, color: Color(0xFF7FE3D9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          // Kimlik sırası: teknenin ADI (kullanıcı isteği
                          // 2026-08) → marka → genel başlık.
                          boat?.name ?? boat?.brand ?? t.sectionBoat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      // DÜZENLE sağ üstte kalem ikonu (Konsept A: kartta tek
                      // CTA). Tekne yokken ikon yerine alttaki davet düğmesi
                      // kalır — boş durumda net bir çağrı gerekir.
                      if (boat != null)
                        IconButton(
                          key: const ValueKey<String>('boat-edit'),
                          tooltip: t.editLabel,
                          visualDensity: VisualDensity.compact,
                          icon: const DocklyIcon(DocklyIcons.edit,
                              size: 18, color: Color(0xFFEAF6FF)),
                          onPressed: () => showBoatSheet(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bağlı marina — dokununca HARİTA marina çevresinde açılır
                  // (Konsept A wireframe sözü: "harita buradan açılır").
                  if (boat?.homeMarina != null) ...<Widget>[
                    InkWell(
                      key: const ValueKey<String>('boat-marina-map'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        // CI DERSİ (tasarım 4 kırmızısı): `boat` bu kapanışın
                        // içinde zaten null-olamaz kabul ediliyor (koşul
                        // `boat?.homeMarina != null` kapanış yaratılırken
                        // terfiyi sabitliyor); fazladan `!` analizörde
                        // unnecessary_non_null_assertion uyarısı üretir ve
                        // --fatal-infos bunu kırmızı sayar.
                        final HomeMarina hm = boat.homeMarina!;
                        final MapFocusRequest? prev =
                            ref.read(mapFocusProvider);
                        ref.read(mapFocusProvider.notifier).state =
                            MapFocusRequest(
                          point: GeoPoint(lat: hm.lat, lon: hm.lon),
                          seq: (prev?.seq ?? 0) + 1,
                          zoom: kHomeMarinaFocusZoom,
                        );
                        ref.read(shellTabProvider.notifier).state = 0;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            const DocklyIcon(DocklyIcons.amMooring,
                                size: 13, color: Color(0xFF9BD8CF)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                boat!.homeMarina!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD7E6F5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const DocklyIcon(DocklyIcons.openInNew,
                                size: 11, color: Color(0xFF9BD8CF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (boat == null)
                    Text(
                      t.boatEmptyBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFD7E6F5),
                        height: 1.45,
                      ),
                    )
                  else
                    Text(
                      '${L10n.fmt(t.boatLengthFmt, _num(boat.lengthM))}'
                      '${boat.draftM != null ? ' · ${L10n.fmt(t.boatDraftFmt, _num(boat.draftM!))}' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFEAF6FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (boat == null) ...<Widget>[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        key: const ValueKey<String>('boat-edit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFFFF),
                          foregroundColor: const Color(0xFF0E8577),
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        onPressed: () => showBoatSheet(context),
                        child: Text(t.boatDefineCta),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // BAKIM ÖZETİ (Konsept A): 10 kalem her açılışta tam boy durmaz —
          // kaptan çoğu gün yalnız "ilgi bekleyen var mı?" diye bakar.
          const _MaintenanceSummaryRow(),
          const SizedBox(height: 12),
          // DEFTER KÖPRÜSÜ (tek ev): istatistik burada KOPYALANMAZ.
          const _DeckBridgeRow(),
        ],
      ),
    );
  }
}

/// Tek satırlık bakım özeti: durum + (varsa) "N kalem ilgi bekliyor" rozeti.
/// Dokununca tam liste kendi ekranında açılır. Sayım, eski bölümle AYNI
/// kuralla yapılır: "kayıt yok" ilgi BEKLEMEZ (0 uydurma — kaptan girmediyse
/// uygulama bir şey iddia etmez).
class _MaintenanceSummaryRow extends ConsumerWidget {
  const _MaintenanceSummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<MaintenanceTask> tasks =
        maintenanceCatalog(ref.watch(appLocaleProvider));
    ref.watch(maintenanceProvider);
    final MaintenanceController ctrl = ref.read(maintenanceProvider.notifier);
    final DateTime now = DateTime.now();
    int needsAttention = 0;
    int logged = 0;
    for (final MaintenanceTask task in tasks) {
      final MaintenanceStatus s =
          maintenanceStatus(task, ctrl.recordFor(task.id), now: now);
      if (s == MaintenanceStatus.overdue || s == MaintenanceStatus.dueSoon) {
        needsAttention++;
      }
      if (s != MaintenanceStatus.notLogged) logged++;
    }
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey<String>('maint-open'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MaintenanceScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.amTool,
                  size: 20,
                  color: needsAttention > 0
                      ? DocklyColors.warning
                      : theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(t.maintTitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    // Alt satır yalnız rozet YOKKEN: hepsi günceldeyse övgü,
                    // hiç kayıt yoksa ne yapılacağı. Rozet varken durum
                    // zaten rozette — satır kendini tekrar etmez.
                    if (needsAttention == 0) ...<Widget>[
                      const SizedBox(height: 1),
                      Text(
                        logged > 0 ? t.maintAllGood : t.maintLead,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (needsAttention > 0) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  key: const ValueKey<String>('maint-summary'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DocklyColors.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    L10n.fmt(t.maintSummaryFmt, '$needsAttention'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Defter köprüsü: sezon istatistiği Teknem'de yaşamaz (tek ev, onaylı P3
/// "yapılmaması gerekenler" kuralı) — köprü Defter'in Seyirler bölümüne
/// götürür.
class _DeckBridgeRow extends ConsumerWidget {
  const _DeckBridgeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey<String>('boat-deck-bridge'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(deckSegmentProvider.notifier).state = 0; // Seyirler
          ref.read(shellTabProvider.notifier).state = 2; // Defter
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.edit,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.boatDeckBridge,
                    style: theme.textTheme.bodyMedium),
              ),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
