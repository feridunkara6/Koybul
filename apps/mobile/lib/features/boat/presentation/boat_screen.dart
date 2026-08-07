import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../onboarding/presentation/tour_targets.dart';
import '../application/my_boat_controller.dart';
import '../domain/my_boat.dart';
import 'boat_sheet.dart';

/// TEKNEM sekmesi v0 (v2.0 vizyonu, kurucu onayı 2026-08): teknenin evi.
/// v0 = kimlik kartı (boy / su çekimi / marka) + düzenleme. Bakım takibi
/// v2.0'da, hesap sistemiyle birlikte bu sekmeye gelir. Profil'deki tekne
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
                          boat?.brand ?? t.sectionBoat,
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
        ],
      ),
    );
  }
}
