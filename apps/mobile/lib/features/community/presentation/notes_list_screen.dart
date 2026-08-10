import 'package:dockly_api/dockly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/community_controller.dart';
import 'note_card.dart';
import 'notes_section.dart';

/// Bir noktanın TÜM notları. Uyarılar en üstte kalır (mergeNotes sıralaması).
class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({
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
    final AsyncValue<List<Note>> async = ref.watch(notesForLocationProvider(locationId));
    final List<Note> local = ref.watch(noteOverridesProvider)[locationId] ?? const <Note>[];
    final List<Note> all = mergeNotes(async.valueOrNull ?? const <Note>[], local);

    return Scaffold(
      appBar: AppBar(title: Text(t.noteSectionTitle)),
      body: async.isLoading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                Text(locationName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (all.isEmpty)
                  Text(
                    t.noteSectionEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                for (final Note n in all) NoteCard(note: n, locationId: locationId),
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
