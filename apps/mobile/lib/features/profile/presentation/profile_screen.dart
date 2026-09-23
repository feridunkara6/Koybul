import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../academy/presentation/academy_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_section.dart';
import '../../community/presentation/contributions_block.dart';
import '../../community/presentation/sailor_profile_card.dart';
import '../../deck/presentation/deck_screen.dart' show deckSegmentProvider;
import '../../emergency/presentation/emergency_screen.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../premium/application/premium_controller.dart';
import '../../premium/presentation/premium_screen.dart';
import '../../legal/presentation/legal_screen.dart';
import '../../legal/presentation/sources_screen.dart';
import '../../route/presentation/saved_routes_screen.dart';
import '../../shell/application/shell_tab_provider.dart';

/// Profil sekmesi — KAPTAN KARTI konsepti (Konsept A, kurucu onayı
/// 2026-09-23): üstte lacivert-mavi degrade kimlik başlığı (avatar + hesap +
/// premium rozeti), altında vurgulu Acil Durum ve Premium kartları; kalan
/// satırlar Denizcilik / Uygulama / Hakkında başlıkları altında GRUPLU
/// kartlarda, her satır kendi renk rozetli ikonunu taşır. Hiçbir özellik
/// eklenmedi/silinmedi — yalnız sunum ve hiyerarşi yenilendi.
///
/// TEK EV TAMİRİ (UX denetimi P1, kullanıcı onayı 2026-08) korunur: tekne
/// kartı yok (Teknem köprüsü var), "Kaptanın Günlüğü" Defter/Notlar'a
/// yönlendirir. Dil, kompakt açılır menüdür (kullanıcı kararı 2026-07).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          // KİMLİK BAŞLIĞI — kaptan kartı (AppBar'ın yerini alır).
          const _ProfileHero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ACİL DURUM en üstte — panik anında aranacak ilk yer burası.
                _EmergencyEntryCard(
                  t: t,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const EmergencyScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                // KOYBUL PREMIUM — sade ama fark edilir kart (sıkmama
                // sözleşmesi K7: kampanya/ısrar yok; paket ekranı yalnız
                // dokununca açılır).
                const _PremiumCard(),
                const SizedBox(height: 8),
                // HESAP bölümü — giriş kartı / hesap kartı + kaptan kimliği.
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 10, bottom: 7),
                  child: Text(t.sectionAccount.toUpperCase(),
                      style: _groupTitleStyle(theme)),
                ),
                const AccountSection(),
                // DENİZCİ PROFİLİM (Teknem Konsept A, kullanıcı onayı
                // 2026-08): kaptanın kimliği — hesap yoksa kendini çizmez.
                const SailorProfileCard(),
                // KATKILARIM (topluluk 2026-08): hesap yoksa hiç çizilmez.
                const ContributionsBlock(),
                // MODERASYON (topluluk 2026-08): yalnız moderatöre görünür.
                const ModerationRow(),
                // DENİZCİLİK — kaptanın varlıkları.
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 18, bottom: 7),
                  child: Text(t.profileGroupSea.toUpperCase(),
                      style: _groupTitleStyle(theme)),
                ),
                _GroupCard(children: <Widget>[
                  _GroupRow(
                    icon: DocklyIcons.sailing,
                    tint: DocklyColors.brandPrimary,
                    label: t.sectionBoat,
                    // TEKNEM KÖPRÜSÜ (tek ev): kart değil köprü — dokununca
                    // Teknem sekmesine geçilir; düzenleme hepsi orada.
                    onTap: () => ref.read(shellTabProvider.notifier).state = 3,
                  ),
                  _GroupRow(
                    icon: DocklyIcons.favorite,
                    tint: DocklyColors.error,
                    label: t.navFavorites,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const FavoritesScreen()),
                    ),
                  ),
                  _GroupRow(
                    icon: DocklyIcons.navigation,
                    tint: DocklyColors.accentTurquoise,
                    label: t.savedRoutesTitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const SavedRoutesScreen()),
                    ),
                  ),
                  _GroupRow(
                    icon: DocklyIcons.edit,
                    tint: DocklyColors.brandDeep,
                    label: t.logbookTitle,
                    // Notların TEK evi Defter/Notlar — yönlendirme (UX P1).
                    onTap: () {
                      ref.read(deckSegmentProvider.notifier).state = 2; // Notlar
                      ref.read(shellTabProvider.notifier).state = 2; // Defter
                    },
                  ),
                ]),
                // UYGULAMA — öğrenme ve ayarlar.
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 18, bottom: 7),
                  child: Text(t.profileGroupApp.toUpperCase(),
                      style: _groupTitleStyle(theme)),
                ),
                _GroupCard(children: <Widget>[
                  _GroupRow(
                    icon: DocklyIcons.helpOutline,
                    tint: DocklyColors.warning,
                    label: t.academyTitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const AcademyScreen()),
                    ),
                  ),
                  _GroupRow(
                    icon: DocklyIcons.infoOutline,
                    tint: DocklyColors.brandPrimary,
                    label: t.onbReplay,
                    // Tur istendiği an yeniden izlenebilir (2026-08).
                    onTap: () {
                      ref.read(onboardingControllerProvider.notifier).replayTour();
                      ref.read(shellTabProvider.notifier).state = 0; // Keşfet
                    },
                  ),
                  const _LanguageGroupRow(),
                ]),
                // HAKKINDA — yasal ve atıflar.
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 18, bottom: 7),
                  child: Text(t.profileGroupAbout.toUpperCase(),
                      style: _groupTitleStyle(theme)),
                ),
                _GroupCard(children: <Widget>[
                  _GroupRow(
                    icon: DocklyIcons.shield,
                    tint: DocklyColors.text2,
                    label: t.legalRow,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const LegalScreen()),
                    ),
                  ),
                  _GroupRow(
                    icon: DocklyIcons.viewList,
                    tint: DocklyColors.text2,
                    label: t.srcRow,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const SourcesScreen()),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle? _groupTitleStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      );
}

/// KAPTAN KARTI başlığı: degrade zemin, avatar, hesap bilgisi, premium rozeti.
/// Oturum yokken/misafirken kimlik "Hoş geldin, Kaptan" davetine döner —
/// giriş düğmeleri aşağıdaki hesap kartındadır (davranış değişmedi).
class _ProfileHero extends ConsumerWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool signedIn = auth is Authenticated && !auth.isGuest;
    final String? email =
        signedIn ? ref.watch(authGatewayProvider).currentEmail : null;
    final bool premium = ref.watch(isPremiumActiveProvider);
    // Avatar: e-postanın ilk iki harfi; e-posta yoksa yelken glifi.
    final String local =
        (email ?? '').split('@').first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final String initials =
        local.isEmpty ? '' : local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[DocklyColors.brandDeep, DocklyColors.brandPrimary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55), width: 2),
                ),
                child: Center(
                  child: initials.isEmpty
                      ? const DocklyIcon(DocklyIcons.sailing,
                          size: 22, color: Colors.white)
                      : Text(initials,
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      signedIn ? t.accOpen : t.profileGuestHello,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      signedIn ? (email ?? '') : t.accTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
              if (premium) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFFBBF24), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const DocklyIcon(DocklyIcons.star,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('Premium',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium kartı: amber tonlu, degrade rozetli; etkinse "Premium etkin",
/// değilse "Premium'a geç" ibaresi. Dokununca paket ekranı açılır.
class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final bool premium = ref.watch(isPremiumActiveProvider);
    return Material(
      color: DocklyColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: DocklyColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFFBBF24), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: DocklyIcon(DocklyIcons.award,
                      size: 17, color: Colors.white),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(t.premRow,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                premium ? t.premActive : t.premBuy,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: premium
                      ? DocklyColors.success
                      : const Color(0xFFB45309),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 15, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gruplu kart: satırlar ince ayraçlarla tek yuvarlak kart içinde.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                      height: 1,
                      thickness: 1,
                      indent: 54,
                      color: theme.dividerColor.withValues(alpha: 0.3)),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grup satırı: renk rozetli ikon + etiket + (isteğe bağlı kuyruk) + ok.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  final DocklyIconData icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: <Widget>[
            _IconChip(icon: icon, tint: tint),
            const SizedBox(width: 11),
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            DocklyIcon(DocklyIcons.arrowForward,
                size: 15, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Renk rozetli ikon karesi — satırların sol görsel çıpası.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.tint});

  final DocklyIconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(child: DocklyIcon(icon, size: 16, color: tint)),
    );
  }
}

/// Dil satırı (grup içinde): rozetli ikon + etiket + kompakt açılır menü
/// (kullanıcı isteği: "alta açılan küçük bir menü, fazla yer kaplamasın").
class _LanguageGroupRow extends ConsumerWidget {
  const _LanguageGroupRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocale current = ref.watch(appLocaleProvider);
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: Row(
        children: <Widget>[
          const _IconChip(icon: DocklyIcons.language, tint: DocklyColors.text2),
          const SizedBox(width: 11),
          Expanded(
            child: Text(t.languageLabel,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
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
