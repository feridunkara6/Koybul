import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/presentation/account_gate.dart';
import '../../../core/origin_provider.dart';
import '../application/community_controller.dart';
import 'note_card.dart';
import 'note_composer_screen.dart';
import 'notes_list_screen.dart';

/// Koy detayındaki "Kaptan Notları" bölümü.
///
/// UYARI notları bu karta GİRMEZ — ayrı bir şerit olarak sayfanın üstünde,
/// rüzgâr uyarısının yanında durur ([HazardNotesBand]). Emniyet bilgisi
/// listenin içinde kaybolmamalı.
class NotesSection extends ConsumerWidget {
  const NotesSection({
    required this.locationId,
    required this.locationName,
    required this.position,
    this.accent,
    super.key,
  });

  final String locationId;
  final String locationName;
  final GeoPoint position;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<Note>> async = ref.watch(notesForLocationProvider(locationId));
    final List<Note> local = ref.watch(noteOverridesProvider)[locationId] ?? const <Note>[];

    // Hata durumunda bölüm gizlenmez ama teknik detay gösterilmez: kaptan
    // "not yok mu, yüklenemedi mi?" belirsizliği yaşamasın diye davet kalır.
    // Sayım TÜM notları kapsar (uyarılar dahil): "Tümü" bağlantısı da tümünü
    // açar. Kartın gövdesinde ise uyarılar yoktur — onlar üstteki şeritte.
    final List<Note> all = mergeNotes(async.valueOrNull ?? const <Note>[], local);
    final List<Note> inCard =
        all.where((Note n) => n.kind != NoteKind.hazard).toList(growable: false);
    final List<Note> shown = inCard.take(2).toList(growable: false);

    return SectionCard(
      key: const ValueKey<String>('notes-section'),
      accent: accent,
      icon: DocklyIcons.edit,
      title: all.isEmpty ? t.noteSectionTitle : '${t.noteSectionTitle} · ${all.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (async.isLoading && all.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (all.isEmpty)
            Text(
              t.noteSectionEmpty,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else ...<Widget>[
            for (final Note n in shown) NoteCard(note: n, locationId: locationId),
            // Yalnızca uyarı varsa kart gövdesi boş kalır — başlıktaki sayıyla
            // çelişmesin diye nerede olduklarını söyleriz.
            if (inCard.isEmpty)
              Text(
                t.noteOnlyHazards,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            if (all.length > shown.length)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey<String>('notes-see-all'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotesListScreen(
                        locationId: locationId,
                        locationName: locationName,
                        position: position,
                      ),
                    ),
                  ),
                  child: Text('${t.noteAllCta} · ${L10n.fmt(t.noteCountFmt, '${all.length}')}'),
                ),
              ),
          ],
          const SizedBox(height: 8),
          AddNoteButton(
            locationId: locationId,
            locationName: locationName,
            position: position,
          ),
        ],
      ),
    );
  }
}

/// Kesikli çerçeveli davet düğmesi — kilit ikonu YOK, davet var (tasarım kararı).
class AddNoteButton extends ConsumerWidget {
  const AddNoteButton({
    required this.locationId,
    required this.locationName,
    required this.position,
    super.key,
  });

  final String locationId;
  final String locationName;
  final GeoPoint position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey<String>('note-add'),
        onPressed: () => openNoteComposer(context, ref,
            locationId: locationId, locationName: locationName, position: position),
        icon: const DocklyIcon(DocklyIcons.edit, size: 18),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        label: Text(t.noteAddCta),
      ),
    );
  }
}

/// Not yazma akışı: önce üyelik kapısı, sonra düzenleyici. Cihaz konumu varsa
/// GPS isteyen tipler (güncel durum / uyarı) seçilebilir olur.
Future<void> openNoteComposer(
  BuildContext context,
  WidgetRef ref, {
  required String locationId,
  required String locationName,
  required GeoPoint position,
}) async {
  final L10n t = ref.read(l10nProvider);
  await requireAccount(
    context,
    ref,
    message: t.gateNoteMsg,
    onAllowed: () {
      final GeoPoint? device = ref.read(devicePositionProvider);
      Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => NoteComposerScreen(
            locationId: locationId,
            locationName: locationName,
            position: position,
            devicePosition: device,
          ),
        ),
      );
    },
  );
}

/// Sayfanın üstündeki AÇIK UYARI şeridi — rüzgâr uyarısıyla aynı görsel dilde.
class HazardNotesBand extends ConsumerWidget {
  const HazardNotesBand({required this.locationId, super.key});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Note>> async = ref.watch(notesForLocationProvider(locationId));
    final List<Note> local = ref.watch(noteOverridesProvider)[locationId] ?? const <Note>[];
    final List<Note> hazards = mergeNotes(async.valueOrNull ?? const <Note>[], local)
        .where((Note n) => n.kind == NoteKind.hazard)
        .toList(growable: false);
    if (hazards.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey<String>('hazard-band'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: <Widget>[
          for (final Note n in hazards) NoteCard(note: n, locationId: locationId),
        ],
      ),
    );
  }
}
