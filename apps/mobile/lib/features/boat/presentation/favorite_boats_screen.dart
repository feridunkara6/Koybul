import 'package:dockly_api/dockly_api.dart' show FavoriteBoatRef;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/favorites_controller.dart';
import 'boat_card_screen.dart';

/// FAVORİ TEKNELERİM (TK-5, kurucu onayı 2026-10-30).
///
/// Profil → Topluluk altından açılır (Takip Ettiklerim deseni). Satıra
/// dokununca tekne kartı açılır; favoriden çıkarma O kartta yapılır (tek
/// ev kuralı). Misafirde liste hep boştur (controller sunucuya hiç
/// gitmez); boş durum metni kalbe yönlendirir. Görünürlüğü kapanan tekne
/// listeden kendiliğinden düşer (rıza ilkesi — sunucu süzer).
class FavoriteBoatsScreen extends ConsumerWidget {
  const FavoriteBoatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<FavoriteBoatRef>> async =
        ref.watch(favoriteBoatsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.favBoatsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.actionFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(favoriteBoatsProvider),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (List<FavoriteBoatRef> list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  t.favBoatsEmpty,
                  key: const ValueKey<String>('fav-boats-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (BuildContext context, int i) {
              final FavoriteBoatRef f = list[i];
              return _BoatRow(f: f, t: t);
            },
          );
        },
      ),
    );
  }
}

class _BoatRow extends StatelessWidget {
  const _BoatRow({required this.f, required this.t});

  final FavoriteBoatRef f;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Teknik rıza kapalıysa marka/model hiç inmez — satır yalnız ad+marina.
    final String sub = <String>[
      if (f.brand != null && f.model != null) '${f.brand} ${f.model}',
      if (f.marinaName != null) '⚓ ${f.marinaName}',
    ].join(' · ');
    return InkWell(
      key: ValueKey<String>('fav-boat-row-${f.id}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BoatCardScreen(boatId: f.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DocklyColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: DocklyIcon(DocklyIcons.sailing,
                    size: 18, color: DocklyColors.brandPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (sub.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('♥',
                style: TextStyle(color: Color(0xFFC2334D), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
