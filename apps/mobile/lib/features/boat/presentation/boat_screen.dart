import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../community/presentation/sailor_profile_card.dart';
import '../../onboarding/presentation/tour_targets.dart';
import '../application/maintenance_controller.dart';
import '../application/my_boat_controller.dart';
import '../data/maintenance_catalog.dart';
import '../domain/maintenance.dart';
import '../domain/my_boat.dart';
import 'boat_sheet.dart';
import 'maintenance_sheet.dart';

/// TEKNEM sekmesi (v2.0 vizyonu, kurucu onayı 2026-08): teknenin evi.
/// Kimlik kartı (boy / su çekimi / marka) + BAKIM TAKİBİ. Profil'deki tekne
/// bölümü geçiş dönemi boyunca durur (hiçbir veri iki kez SAKLANMAZ — ikisi
/// de aynı Teknem modelini okur).
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bağlı marina — kimlik kartında ince satır (varsa).
                  if (boat?.homeMarina != null) ...<Widget>[
                    Row(
                      children: <Widget>[
                        const DocklyIcon(DocklyIcons.amMooring,
                            size: 13, color: Color(0xFF9BD8CF)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            boat!.homeMarina!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFD7E6F5),
                            ),
                          ),
                        ),
                      ],
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
                      child:
                          Text(boat == null ? t.boatDefineCta : t.editLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // DENİZCİ PROFİLİM (topluluk 2026-08): kimlik kartı ile bakım
          // takibi ARASINA girer. Hesap yoksa kendini çizmez — misafirin
          // Teknem sekmesi bugünküyle birebir aynı kalır.
          const SailorProfileCard(),
          const SizedBox(height: 18),
          // BAKIM TAKİBİ (v2.0): kaptanın girdiği kayıtlara göre hatırlatma.
          const _MaintenanceSection(),
        ],
      ),
    );
  }
}

/// BAKIM bölümü: özet satırı + 10 kalem + dürüstlük notu.
class _MaintenanceSection extends ConsumerWidget {
  const _MaintenanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<MaintenanceTask> tasks =
        maintenanceCatalog(ref.watch(appLocaleProvider));
    // Kayıtlar izlenir: "bugün yaptım" sonrası durum rozetleri tazelenir.
    ref.watch(maintenanceProvider);
    final MaintenanceController ctrl = ref.read(maintenanceProvider.notifier);
    final DateTime now = DateTime.now();
    // İLGİ BEKLEYEN = süresi geçen + yaklaşan. "Kayıt yok" SAYILMAZ:
    // kaptan girmediyse uygulama bir şey iddia etmez (0 uydurma).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(t.maintTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (needsAttention > 0)
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
        ),
        const SizedBox(height: 4),
        Text(
          // Hiç kayıt yoksa ne yapılacağı anlatılır; hepsi güncelse övülür.
          needsAttention == 0 && logged > 0 ? t.maintAllGood : t.maintLead,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (final MaintenanceTask task in tasks)
          _MaintenanceRow(
            task: task,
            record: ctrl.recordFor(task.id),
            now: now,
          ),
        const SizedBox(height: 8),
        Text(
          t.maintNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Tek bakım kalemi satırı: ikon + ad + durum rozeti + kalan/gecikme.
class _MaintenanceRow extends ConsumerWidget {
  const _MaintenanceRow({
    required this.task,
    required this.record,
    required this.now,
  });

  final MaintenanceTask task;
  final MaintenanceRecord? record;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final MaintenanceStatus status =
        maintenanceStatus(task, record, now: now);
    final int? left = maintenanceDaysLeft(task, record, now: now);
    final (String label, Color color) = switch (status) {
      MaintenanceStatus.overdue => (t.maintStatusOverdue, DocklyColors.error),
      MaintenanceStatus.dueSoon => (t.maintStatusSoon, DocklyColors.warning),
      MaintenanceStatus.ok => (t.maintStatusOk, DocklyColors.success),
      MaintenanceStatus.notLogged =>
        (t.maintStatusNone, theme.colorScheme.onSurfaceVariant),
    };
    final String? detail = left == null
        ? null
        : (left < 0
            ? L10n.fmt(t.maintOverdueByFmt, '${-left}')
            : L10n.fmt(t.maintDueInFmt, '$left'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        key: ValueKey<String>('maint-${task.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => showMaintenanceSheet(context, task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: <Widget>[
              DocklyIcon(task.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
