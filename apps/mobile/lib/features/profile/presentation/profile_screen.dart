import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_section.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart';
import '../../emergency/presentation/emergency_screen.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../logbook/presentation/logbook_screen.dart';
import '../../route/presentation/saved_routes_screen.dart';
import '../../shell/application/shell_tab_provider.dart';

/// Profil sekmesi (misafir). Kalıcı tekne bilgisini gösterir/düzenler, hesap
/// bölümünü ve DİL seçimini barındırır (kullanıcı kararı 2026-07: dil cihazdan
/// otomatik; burada küçük bir açılır menüyle elle değiştirilebilir).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MyBoat? boat = ref.watch(myBoatProvider);
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
          Text(t.sectionBoat, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (boat == null)
            _BoatEmptyCard(t: t, onDefine: () => showBoatSheet(context))
          else
            _BoatCard(
              t: t,
              boat: boat,
              onEdit: () => showBoatSheet(context),
              onRemove: () => ref.read(myBoatProvider.notifier).clear(),
            ),
          const SizedBox(height: 28),
          Text(t.sectionAccount, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // Giriş/kayıt (paket 1): oturum yoksa giriş kartı, varsa hesap kartı.
          const AccountSection(),
          const SizedBox(height: 16),
          // DİL — az yer kaplayan tek satır; menü aşağı açılır.
          const _LanguageRow(),
          const SizedBox(height: 16),
          // KAYITLI ROTALAR (rota planlama 2026-08): cihazdaki rota kayıtları.
          _NavRow(
            icon: DocklyIcons.navigation,
            label: t.savedRoutesTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SavedRoutesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // KAPTANIN GÜNLÜĞÜ (kullanıcı onayı 2026-08): seyir notları.
          _NavRow(
            icon: DocklyIcons.edit,
            label: t.logbookTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LogbookScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // TANITIM TURU (2026-08): tur istendiği an yeniden izlenebilir —
          // dokununca Keşfet sekmesine dönülür ve tur başlar.
          const _TourReplayRow(),
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

class _BoatCard extends StatelessWidget {
  const _BoatCard({
    required this.t,
    required this.boat,
    required this.onEdit,
    required this.onRemove,
  });

  final L10n t;
  final MyBoat boat;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const DocklyIcon(DocklyIcons.sailing, color: DocklyColors.brandPrimary),
                const SizedBox(width: 10),
                Text(L10n.fmt(t.boatLengthFmt, _fmt(boat.lengthM)),
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              boat.draftM != null
                  ? L10n.fmt(t.boatDraftFmt, _fmt(boat.draftM!))
                  : t.boatDraftUnknown,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const DocklyIcon(DocklyIcons.edit, size: 18),
                  label: Text(t.editLabel),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const DocklyIcon(DocklyIcons.deleteOutline, size: 18),
                  label: Text(t.removeLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _BoatEmptyCard extends StatelessWidget {
  const _BoatEmptyCard({required this.t, required this.onDefine});

  final L10n t;
  final VoidCallback onDefine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(t.boatEmptyBody),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: DocklyButton(label: t.boatDefineCta, onPressed: onDefine),
            ),
          ],
        ),
      ),
    );
  }
}
