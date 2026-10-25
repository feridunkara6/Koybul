import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/widgets/section_card.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../favorites/application/favorites_controller.dart';
import '../../favorites/domain/favorite_location.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/saved_route.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/getting_started_controller.dart';

/// Bugün kimlik rengi (onaylı tema) — today_screen'dekiyle aynı değer.
const Color _amber = Color(0xFFF59E0B);

/// BAŞLANGIÇ GÖREVLERİ kartı (Hoş Geldin Paketi B, kurucu onayı 2026-10-25):
/// yeni kaptana ilk 4 adımı gösterir — tekne, marina, favori, rota.
///
/// Dürüstlük kuralları:
///  - Görev durumları GERÇEK cihaz verisinden okunur (0-uydurma): tekne
///    tanımlıysa ✓, favori varsa ✓... Sahte ilerleme yazılmaz.
///  - Depo okunmadan kart çizilmez (görünüp kaybolan kart titremesi yok).
///  - 4 görev de bittiyse kart KENDİNİ EMEKLİ EDER; "Gizle" ile erken de
///    kapatılır ve karar cihazda kalıcıdır.
/// Satıra dokunmak ilgili sekmeye götürür (görev orada yapılır).
class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool? dismissed = ref.watch(gettingStartedDismissedProvider);
    // null = depo henüz okunmadı; true = kullanıcı kapattı — ikisinde de yok.
    if (dismissed != false) return const SizedBox.shrink();

    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final List<FavoriteLocation> favs = ref.watch(favoritesProvider);
    final List<SavedRoute> routes = ref.watch(savedRoutesProvider);

    // Görevler: (anahtar, etiket, bitti mi, hedef sekme).
    final List<(String, String, bool, int)> tasks =
        <(String, String, bool, int)>[
      ('gs-task-boat', t.gsTaskBoat, boat != null, 3),
      ('gs-task-marina', t.gsTaskMarina, boat?.homeMarina != null, 3),
      ('gs-task-fav', t.gsTaskFav, favs.isNotEmpty, 0),
      ('gs-task-route', t.gsTaskRoute, routes.isNotEmpty, 0),
    ];
    final int done =
        tasks.where(((String, String, bool, int) x) => x.$3).length;
    // Hepsi bitti → kart görevini tamamladı, kendini emekli eder.
    if (done == tasks.length) return const SizedBox.shrink();

    final Color sub = theme.colorScheme.onSurfaceVariant;
    return SectionCard(
      key: const ValueKey<String>('gs-card'),
      icon: DocklyIcons.compass,
      title: t.gsTitle,
      accent: _amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            L10n.fmt2(t.gsProgressFmt, '$done', '${tasks.length}'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: sub,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: done / tasks.length,
              minHeight: 6,
              backgroundColor: _amber.withValues(alpha: 0.15),
              color: _amber,
            ),
          ),
          const SizedBox(height: 6),
          for (final (String, String, bool, int) task in tasks)
            InkWell(
              key: ValueKey<String>(task.$1),
              borderRadius: BorderRadius.circular(10),
              // Bitmiş görevde de dokunuş çalışır (ekrana gitmek zararsız).
              onTap: () =>
                  ref.read(shellTabProvider.notifier).state = task.$4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    DocklyIcon(
                      task.$3 ? DocklyIcons.checkCircle : DocklyIcons.circle,
                      size: 18,
                      color: task.$3 ? DocklyColors.success : sub,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              task.$3 ? FontWeight.w500 : FontWeight.w700,
                          color: task.$3 ? sub : null,
                          decoration:
                              task.$3 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (!task.$3)
                      DocklyIcon(DocklyIcons.arrowForward,
                          size: 14, color: sub),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('gs-hide'),
              onPressed: () => ref
                  .read(gettingStartedDismissedProvider.notifier)
                  .dismiss(),
              child: Text(t.gsHide),
            ),
          ),
        ],
      ),
    );
  }
}
