import 'package:dockly_api/dockly_api.dart' show LocationDetail;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../premium/presentation/premium_screen.dart';
import '../application/location_detail_controller.dart';

/// KİLİT KARTI (P4, kurucu onayı 2026-09-22 — premium v3 raporu §6 taslak 9).
///
/// Vitrin detayında (access='teaser') güvenlik özetinin ALTINDA durur: kilitli
/// içerik burada anlatılır ve iki yol sunulur — Premium tanıtımı ya da (üyeyse)
/// KEŞİF HAKKI ile bu koyu açmak. SIKMAMA SÖZLEŞMESİ: kart sayfada TEK premium
/// çağrısıdır, kendiliğinden hiçbir pencere açmaz, kapatma/geri her an serbest.
///
/// Sahte "bulanık veri" ÇİZİLMEZ: kilitli veri istemciye hiç inmediği için
/// bulanıklaştıracak gerçek bir şey yoktur; sahtesini basmak uydurma olurdu.
class PremiumLockCard extends ConsumerStatefulWidget {
  const PremiumLockCard({required this.detail, super.key});

  final LocationDetail detail;

  @override
  ConsumerState<PremiumLockCard> createState() => _PremiumLockCardState();
}

class _PremiumLockCardState extends ConsumerState<PremiumLockCard> {
  bool _busy = false;

  Future<void> _unlock() async {
    final L10n t = ref.read(l10nProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final int remaining =
          await ref.read(kesifGatewayProvider).unlock(widget.detail.id);
      // Sunucu koyu bu ay için açtı — detay yeniden çekilir, artık tam gelir.
      ref.invalidate(locationDetailProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.fmt(t.detUnlockedFmt, '$remaining'))),
      );
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool member = auth is Authenticated && !auth.isGuest;
    final int? remaining = widget.detail.explorationRemaining;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                DocklyIcon(DocklyIcons.lockOutline,
                    size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.detLockTitle, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.detLockBody,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const PremiumScreen()),
                      ),
              child: Text(t.detLockCta),
            ),
            // KEŞİF HAKKI satırı — yalnız HESAPLI üyeye (rapor K2):
            //  hakkı varsa: tek dokunuşla bu koyu aç;
            //  hakkı bittiyse: dürüst bilgi (gelecek ay yenilenir).
            if (member && remaining != null) ...<Widget>[
              const SizedBox(height: 8),
              if (remaining > 0)
                OutlinedButton(
                  onPressed: _busy ? null : _unlock,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(L10n.fmt(t.detUnlockFmt, '$remaining')),
                )
              else
                Text(
                  t.detUnlockNone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
            // Misafir/oturumsuz: üyeliğin somut faydası tek satırda (ayda 3
            // koy hediyesi) — dokununca giriş sayfası açılır.
            if (!member) ...<Widget>[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : () => showSignInSheet(context),
                child: Text(t.detLockSignIn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
