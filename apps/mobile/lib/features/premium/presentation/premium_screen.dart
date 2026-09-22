import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../application/premium_controller.dart';
import '../domain/purchase_gateway.dart';

/// KOYBUL PREMIUM paket ekranı (P3, premium v3 raporu §6 taslak 11).
///
/// Kurgu: yıllık paket ÖNDE ve çerçeveli, aylık kıyas çıpası; fiyatlar HER
/// ZAMAN mağazadan gelir (kodda fiyat yok). "Sıkmama sözleşmesi" gereği bu
/// ekran yalnız kullanıcı bir kapıya DOKUNUNCA açılır ve kapatması hep
/// tek dokunuştur (AppBar geri oku).
///
/// Dört hâl: web (yönlendirme mesajı — K6), misafir/oturumsuz (hesap çağrısı),
/// premium zaten etkin (durum kartı), satın alınabilir (paketler).
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.premTitle)),
      body: kIsWeb ? _InfoCard(text: t.premWebMsg) : const _MobileBody(),
    );
  }
}

class _MobileBody extends ConsumerWidget {
  const _MobileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AuthState auth = ref.watch(authControllerProvider);

    if (auth is! Authenticated || auth.isGuest) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Hero(t: t),
          const SizedBox(height: 16),
          _InfoCard(text: t.premNeedAccount, padded: false),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => showSignInSheet(context),
            child: Text(t.premSignInBtn),
          ),
        ],
      );
    }

    final AsyncValue<PremiumMe?> me = ref.watch(premiumMeProvider);
    final PremiumMe? current = me.valueOrNull;
    if (current != null && current.active) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Hero(t: t),
          const SizedBox(height: 16),
          _ActiveCard(t: t, me: current),
        ],
      );
    }
    return const _StoreBody();
  }
}

/// Paket listesi + satın alma akışı (hesap açık, premium kapalı).
class _StoreBody extends ConsumerWidget {
  const _StoreBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final PurchaseUiState s = ref.watch(purchaseControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _Hero(t: t),
        const SizedBox(height: 16),
        switch (s.phase) {
          PurchasePhase.loading =>
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
          PurchasePhase.unavailable => _InfoCard(text: t.premUnavailable, padded: false),
          PurchasePhase.purchasing || PurchasePhase.linking => Column(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                Text(
                  s.phase == PurchasePhase.linking ? t.premLinking : '',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          PurchasePhase.done => _InfoCard(text: t.premDone, padded: false),
          PurchasePhase.ready => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (s.failed) ...<Widget>[
                  _InfoCard(text: t.premPurchaseError, padded: false, warning: true),
                  const SizedBox(height: 12),
                ],
                if (s.restoreChecked) ...<Widget>[
                  _InfoCard(text: t.premRestoreDone, padded: false),
                  const SizedBox(height: 12),
                ],
                for (final PremiumPackage p in s.packages) ...<Widget>[
                  _PackageCard(
                    t: t,
                    package: p,
                    onBuy: () => ref
                        .read(purchaseControllerProvider.notifier)
                        .buy(p),
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton(
                  onPressed: () =>
                      ref.read(purchaseControllerProvider.notifier).restore(),
                  child: Text(t.premRestore),
                ),
                const SizedBox(height: 8),
                Text(
                  t.premCancelNote,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
        },
      ],
    );
  }
}

/// Üst tanıtım bloğu: başlık + 4 özellik satırı (premium v3 raporu §3).
class _Hero extends StatelessWidget {
  const _Hero({required this.t});

  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> feats = <String>[
      t.premFeatDetail,
      t.premFeatRoutes,
      t.premFeatSaves,
      t.premFeatBoat,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(t.premLead, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final String f in feats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DocklyIcon(DocklyIcons.checkCircle,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tek paket kartı — yıllık çerçeveli + "avantajlı seçim" rozeti + dürüst
/// "aylık karşılığı" satırı (yıllık fiyat ÷ 12).
class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.t, required this.package, required this.onBuy});

  final L10n t;
  final PremiumPackage package;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool yearly = package.isYearly;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: yearly ? theme.colorScheme.primary : theme.dividerColor,
          width: yearly ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                yearly ? t.premYearly : t.premMonthly,
                style: theme.textTheme.titleMedium,
              ),
              if (yearly) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    t.premYearlyTag,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ),
              ],
              const Spacer(),
              Text(package.price, style: theme.textTheme.titleMedium),
            ],
          ),
          if (yearly)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                L10n.fmt(t.premPerMonthFmt, package.perMonthLabel),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onBuy, child: Text(t.premBuy)),
        ],
      ),
    );
  }
}

/// Premium zaten etkin: durum kartı (satın alma düğmesi ÇİZİLMEZ).
class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.t, required this.me});

  final L10n t;
  final PremiumMe me;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? until = me.until?.toLocal();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.verified,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(t.premActive, style: theme.textTheme.titleMedium),
            ],
          ),
          if (until != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                L10n.fmt(
                  t.premUntilFmt,
                  '${until.day.toString().padLeft(2, '0')}.'
                  '${until.month.toString().padLeft(2, '0')}.${until.year}',
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t.premCancelNote,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text, this.padded = true, this.warning = false});

  final String text;
  final bool padded;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
    if (!padded) return card;
    return Padding(padding: const EdgeInsets.all(16), child: card);
  }
}
