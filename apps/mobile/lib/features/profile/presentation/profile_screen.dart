import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../academy/presentation/academy_screen.dart';
import '../../auth/presentation/account_section.dart';
import '../../community/presentation/contributions_block.dart';
import '../../community/presentation/sailor_profile_card.dart';
import '../../deck/presentation/deck_screen.dart' show deckSegmentProvider;
import '../../emergency/presentation/emergency_screen.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../legal/presentation/legal_screen.dart';
import '../../route/presentation/saved_routes_screen.dart';
import '../../shell/application/shell_tab_provider.dart';

/// Profil sekmesi (misafir). Hesap bölümünü ve DİL seçimini barındırır
/// (kullanıcı kararı 2026-07: dil cihazdan otomatik; burada küçük bir açılır
/// menüyle elle değiştirilebilir).
///
/// TEK EV TAMİRİ (UX denetimi P1, kullanıcı onayı 2026-08): aynı içerik iki
/// kapıdan açılmaz. (1) Buradaki TEKNE KARTI kaldırıldı — teknenin evi Teknem
/// sekmesidir; Profil'de yalnız oraya götüren KÖPRÜ satırı durur. (2)
/// "Kaptanın Günlüğü" satırı artık ayrı bir ekran AÇMAZ; Defter sekmesinin
/// Notlar bölümüne YÖNLENDİRİR. Hiçbir içerik/özellik silinmedi — yalnız
/// kapılar tekilleşti, kaptanın zihin haritası netleşti.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          // ACİL DURUM girişi en üstte — panik anında aranacak ilk yer burası.
          _EmergencyEntryCard(
            t: t,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()),
            ),
          ),
          const SizedBox(height: 24),
          // TEKNEM KÖPRÜSÜ (tek ev): kart değil köprü — dokununca Teknem
          // sekmesine geçilir. Boy/su çekimi/düzenleme hepsi orada.
          _NavRow(
            icon: DocklyIcons.sailing,
            label: t.sectionBoat,
            onTap: () => ref.read(shellTabProvider.notifier).state = 3,
          ),
          const SizedBox(height: 28),
          Text(t.sectionAccount, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // Giriş/kayıt (paket 1): oturum yoksa giriş kartı, varsa hesap kartı.
          const AccountSection(),
          // DENİZCİ PROFİLİM (Teknem Konsept A, kullanıcı onayı 2026-08):
          // kart Teknem'den BURAYA taşındı — o kaptanın kimliğidir, teknenin
          // değil. Hesap yoksa kendini çizmez (davranış aynen korunur).
          const SailorProfileCard(),
          // KATKILARIM (topluluk 2026-08): hesap kartının HEMEN ALTINDA üç
          // sayaç. Hesap yoksa hiç çizilmez — misafirin Profil ekranı
          // bugünküyle birebir aynı kalır.
          const ContributionsBlock(),
          // MODERASYON (topluluk 2026-08): yalnız moderatör rolüne görünür.
          const ModerationRow(),
          const SizedBox(height: 16),
          // DİL — az yer kaplayan tek satır; menü aşağı açılır.
          const _LanguageRow(),
          const SizedBox(height: 16),
          // KAYITLARIM (v2.0 geçiş dönemi): eski Kayıtlarım sekmesi Profil'e
          // indi. Ekran şimdilik rotaları da listeler; satır etiketi ekran
          // başlığıyla AYNI kalır ki kaptan nereye gittiğini bilsin. Favori
          // yerler ayrı ekrana ayrılınca etiket favSectionPlaces olacak.
          _NavRow(
            icon: DocklyIcons.favorite,
            label: t.navFavorites,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // KAYITLI ROTALAR (rota planlama 2026-08): cihazdaki rota kayıtları.
          _NavRow(
            icon: DocklyIcons.navigation,
            label: t.savedRoutesTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SavedRoutesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // KAPTANIN GÜNLÜĞÜ (tek ev tamiri, UX P1 2026-08): satır artık
          // ikinci bir ekran açmaz — notların TEK evi Defter'in Notlar
          // bölümüdür; buradan oraya yönlendirilir.
          _NavRow(
            icon: DocklyIcons.edit,
            label: t.logbookTitle,
            onTap: () {
              ref.read(deckSegmentProvider.notifier).state = 2; // Notlar
              ref.read(shellTabProvider.notifier).state = 2; // Defter
            },
          ),
          const SizedBox(height: 12),
          // DENİZCİLİK AKADEMİSİ (v2.0, kurucu onayı 2026-08): 10 kısa
          // rehber — çevrimdışı çalışır, dört dilde yazılmıştır.
          _NavRow(
            icon: DocklyIcons.helpOutline,
            label: t.academyTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AcademyScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // TANITIM TURU (2026-08): tur istendiği an yeniden izlenebilir —
          // dokununca Keşfet sekmesine dönülür ve tur başlar.
          const _TourReplayRow(),
          const SizedBox(height: 12),
          // YASAL METİNLER (Faz 0): gizlilik, KVKK aydınlatma, kullanım
          // koşulları. Mağaza şartı ve KVKK yükümlülüğü; içerik uygulamanın
          // içinde, çevrimdışı okunur.
          _NavRow(
            icon: DocklyIcons.shield,
            label: t.legalRow,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LegalScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profildeki gezinme satırı (dil satırıyla aynı görsel dil): ikon + etiket +
/// ok; dokununca [onTap].
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final DocklyIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Tanıtım turunu tekrar izle" satırı — dil satırıyla aynı görsel dil.
class _TourReplayRow extends ConsumerWidget {
  const _TourReplayRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(onboardingControllerProvider.notifier).replayTour();
          ref.read(shellTabProvider.notifier).state = 0; // Keşfet'e dön
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.infoOutline,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.onbReplay, style: theme.textTheme.bodyMedium),
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

/// Dil satırı: ikon + etiket + kompakt açılır menü (kullanıcı isteği:
/// "alta açılan küçük bir menü, fazla yer kaplamasın"). Diller kendi adıyla
/// listelenir; seçim anında uygulanır ve cihazda saklanır.
class _LanguageRow extends ConsumerWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocale current = ref.watch(appLocaleProvider);
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          DocklyIcon(DocklyIcons.language,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(t.languageLabel, style: theme.textTheme.bodyMedium)),
          DropdownButton<AppLocale>(
            value: current,
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface),
            items: <DropdownMenuItem<AppLocale>>[
              for (final AppLocale l in AppLocale.values)
                DropdownMenuItem<AppLocale>(
                  value: l,
                  child: Text(l.nativeName),
                ),
            ],
            onChanged: (AppLocale? l) {
              if (l != null) ref.read(appLocaleProvider.notifier).set(l);
            },
          ),
        ],
      ),
    );
  }
}

/// Kırmızı acil durum giriş kartı — tek dokunuşla Acil Durum sayfası.
class _EmergencyEntryCard extends StatelessWidget {
  const _EmergencyEntryCard({required this.t, required this.onOpen});

  final L10n t;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.errorOutline,
                  color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(t.emergencyTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onErrorContainer)),
                    const SizedBox(height: 2),
                    Text(
                      t.emergencySub,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer
                              .withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 18, color: theme.colorScheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// _BoatCard ve _BoatEmptyCard KALDIRILDI (tek ev tamiri, UX P1 2026-08):
// tekne kartının evi Teknem sekmesi; Profil yalnız köprü satırı taşır.
