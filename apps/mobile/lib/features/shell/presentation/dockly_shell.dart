import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../boat/presentation/boat_screen.dart';
import '../../deck/presentation/deck_screen.dart';
import '../../map/application/map_controller.dart' show mapControllerProvider;
import '../../map/domain/map_state.dart' show MapState;
import '../../map/presentation/map_screen.dart'
    show MapScreen, todayInviteDismissedProvider;
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/presentation/onboarding_overlay.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../today/presentation/today_screen.dart';
import '../application/shell_tab_provider.dart';

/// Uygulama kabuğu — v2.0 navigasyonu (kurucu onayı 2026-08, 5 sekme):
/// Keşfet (harita) · Bugün · Defter · Teknem · Profil.
///
/// Arama haritanın içindeki arama düğmesine katlandı (aynı işi iki yüzey
/// yapmasın); favori yerler Profil'den erişilir; Günlük, Defter'in "Notlar"
/// segmenti oldu; rotalar Defter'de yaşar. "Taleplerim" ekranı Faz 0'da
/// KALDIRILDI: içi boş bir "yakında" sayfasıydı.
///
/// IndexedStack ile sekmeler arası geçişte durum korunur (harita konumu vb.).
/// Tüm sekmeler misafir modda çalışır (favoriler cihazda saklanır);
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
    // TANITIM TURU v3 (kullanıcı isteği 2026-08): kaplama KABUĞUN üstünde —
    // tur sekme değiştirebilir (Kayıtlarım/Günlük adımları) ve karartma alt
    // menüyü de kapsar. select: kabuk yalnız TUR ADIMI değişince yeniden
    // kurulur (ipucu işaretlemeleri kabuğu ilgilendirmez).
    final int tourStep = ref.watch(onboardingControllerProvider
        .select((OnboardingState s) => s.tourStep));
    final Widget shell = Scaffold(
      body: IndexedStack(
        index: index,
        children: <Widget>[
          const MapScreen(), // her zaman canlı (harita durumu korunur)
          _built[1] ? const TodayScreen() : const SizedBox.shrink(),
          _built[2] ? const DeckScreen() : const SizedBox.shrink(),
          _built[3] ? const BoatScreen() : const SizedBox.shrink(),
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
              // Bugün'e bir kez gidildiyse haritadaki davet kartı emekli olur
              // (onaylı E1: davet ısrar etmez).
              if (i == 1) {
                ref.read(todayInviteDismissedProvider.notifier).state = true;
              }
              ref.read(shellTabProvider.notifier).state = i;
            },
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.exploreOutlined),
                selectedIcon: const DocklyIcon(DocklyIcons.explore),
                label: t.navExplore,
              ),
              // BUGÜN (v2.0): günlük alışkanlık merkezi — hava + kontrol
              // listesi; akıllı koy önerisi sonraki paketle buraya gelir.
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.starBorder),
                selectedIcon: const DocklyIcon(DocklyIcons.star),
                label: t.navToday,
              ),
              // DEFTER: rotalar + notlar (denizcinin arşivi).
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.edit),
                selectedIcon: const DocklyIcon(DocklyIcons.edit),
                label: t.navDeck,
              ),
              // TEKNEM: teknenin evi (v2.0'da bakım da buraya).
              NavigationDestination(
                icon: const DocklyIcon(DocklyIcons.sailingOutlined),
                selectedIcon: const DocklyIcon(DocklyIcons.sailing),
                label: t.navBoat,
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
    return Stack(
      children: <Widget>[
        shell,
        if (tourStep >= 0)
          Positioned.fill(child: TourOverlay(step: tourStep)),
        // Davet, alt yüzeylerin ÜSTÜNDE durur. Üç incelik, üçü de inceleme
        // bulgusu:
        // · Yükseklik: haritanın "Bugün" davet kartıyla AYNI banda oturur.
        //   O kart gövde içinde 78'de duruyor; kabuk katmanında aynı yer
        //   78 + sekme çubuğu (64 + 1 çizgi) = 143'tür. Altındaki "Yakın
        //   limanlar" rayı (~62 px) böylece açıkta kalır, dokunuşu çalınmaz.
        // · Alt boşluk cihazdan gelir (iPhone ana çubuğu, Android tuşları);
        //   sabit sayı verilseydi davet sekme adlarının üstüne binerdi.
        // · Haritada bir koy KARTI açıkken çıkmaz. Ölçüt kartın kendi ölçütü
        //   (`selectedPin`), kimlik değil: kimlik seçili kalıp kart kapanmış
        //   olabilir (pin görünümden çıkınca) — o durumda tek seferlik davet
        //   sebepsiz yere kaybolurdu.
        if (tourStep < 0 &&
            ref.watch(onboardingControllerProvider
                .select((OnboardingState s) => s.tourInvite)) &&
            ref.watch(mapControllerProvider
                .select((MapState s) => s.selectedPin == null)))
          Positioned(
            left: 12,
            right: 12,
            bottom: 143 + MediaQuery.paddingOf(context).bottom,
            child: const _TourInvite(),
          ),
      ],
    );
  }
}

/// TUR DAVETİ (Faz 1). Eskiden 10 kartlık tur zorla başlıyordu; artık tek
/// satırlık bir soru soruluyor. Ekranı KAPATMAZ — kullanıcı isterse daveti
/// hiç okumadan haritayla oynamaya başlayabilir.
class _TourInvite extends ConsumerWidget {
  const _TourInvite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final OnboardingController c =
        ref.read(onboardingControllerProvider.notifier);
    return Material(
      key: const ValueKey<String>('tour-invite'),
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      // Tema kartı rengi: karanlık kipte de doğru zemin (sabit beyaz değil).
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                t.tourInviteMsg,
                style: const TextStyle(fontSize: 13.5, height: 1.35),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('tour-invite-no'),
              onPressed: c.declineTourInvite,
              child: Text(t.tourInviteNo),
            ),
            TextButton(
              key: const ValueKey<String>('tour-invite-yes'),
              onPressed: c.acceptTourInvite,
              child: Text(
                t.tourInviteYes,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
