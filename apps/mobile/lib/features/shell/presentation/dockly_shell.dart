import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../map/presentation/map_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reservation/presentation/reservations_placeholder_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../application/shell_tab_provider.dart';

/// Uygulama kabuğu — 5 sekmeli alt menü (docs/01-prd §6.13):
/// Keşfet (harita) · Arama · Favoriler · Taleplerim · Profil.
///
/// IndexedStack ile sekmeler arası geçişte durum korunur (harita konumu vb.).
/// Tüm sekmeler misafir modda çalışır (favoriler/talepler cihazda saklanır);
/// hesap/giriş geldiğinde bunlar buluta senkronlanacak.
class DocklyShell extends ConsumerStatefulWidget {
  const DocklyShell({super.key});

  @override
  ConsumerState<DocklyShell> createState() => _DocklyShellState();
}

class _DocklyShellState extends ConsumerState<DocklyShell> {
  /// PERF (tembel sekmeler): açılışta yalnız Keşfet kurulur; diğer sekmeler
  /// İLK ziyarette kurulur ve sonra durumunu korur (IndexedStack canlı tutar).
  /// Açılışta 5 ekran yerine 1 ekran kurmak ilk kareyi belirgin hızlandırır.
  final List<bool> _built = <bool>[true, false, false, false, false];

  // NOT (Paket 2, 2026-08): eski "teknen kaç metre?" karşılama sorusu emekli
  // edildi — tekne bilgisi artık onaylı açılış akışında (E3–E4) soruluyor ve
  // aynı Teknem modeline yazılıyor. Profil → Teknem her zaman açık.

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider); // dil değişince menü yenilenir
    // Sekme artık sağlayıcıda (tanıtım 2026-08): Profil'deki "turu tekrar
    // izle" Keşfet'e dönebilsin. Dışarıdan gelen geçişte de sekme kurulur.
    final int index = ref.watch(shellTabProvider);
    _built[index] = true;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // Tasarım sistemi §5 (glass tab bar) + mockup: açık cam zemin (0.72 beyaz),
    // ince üst çizgi, PILL GÖSTERGESİZ sekmeler — seçili sekme marka mavisi
    // ikon + etiket, seçili olmayanlar ikincil gri. Dark modda cam koyu yüzey.
    final Color selected =
        dark ? DocklyColors.brandPrimaryDark : DocklyColors.brandPrimary;
    final Color unselected = dark ? DocklyColors.text2Dark : DocklyColors.text2;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: <Widget>[
          const MapScreen(), // her zaman canlı (harita durumu korunur)
          _built[1] ? const SearchScreen() : const SizedBox.shrink(),
          _built[2] ? const FavoritesScreen() : const SizedBox.shrink(),
          _built[3] ? const ReservationsPlaceholderScreen() : const SizedBox.shrink(),
          _built[4] ? const ProfileScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          // bg.glass: light rgba(255,255,255,0.72) / dark rgba(20,28,43,0.72).
          color: dark ? const Color(0xB8141C2B) : const Color(0xB8FFFFFF),
          border: Border(
            top: BorderSide(
              color: dark ? DocklyColors.hairlineDark : DocklyColors.hairline,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            // Mockup'ta seçim pill'i YOK — renk değişimi yeterli.
            indicatorColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            iconTheme: WidgetStateProperty.resolveWith(
              (Set<WidgetState> states) => IconThemeData(
                size: 24,
                color: states.contains(WidgetState.selected) ? selected : unselected,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (Set<WidgetState> states) => TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected) ? selected : unselected,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (int i) {
              setState(() => _built[i] = true); // ilk ziyarette kur, canlı tut
              ref.read(shellTabProvider.notifier).state = i;
            },
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.exploreOutlined),
                selectedIcon: const DocklyIcon(DocklyIcons.explore),
                label: t.navExplore,
              ),
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.search),
                selectedIcon: const DocklyIcon(DocklyIcons.search),
                label: t.navSearch,
              ),
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.favoriteBorder),
                selectedIcon: const DocklyIcon(DocklyIcons.favorite),
                label: t.navFavorites,
              ),
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.eventNoteOutlined),
                selectedIcon: const DocklyIcon(DocklyIcons.eventNote),
                label: t.navRequests,
              ),
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.personOutline),
                selectedIcon: const DocklyIcon(DocklyIcons.person),
                label: t.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
