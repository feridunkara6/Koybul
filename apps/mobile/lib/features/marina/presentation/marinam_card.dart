import 'package:dockly_api/dockly_api.dart' show MarinaCommunity, MyMarinaBoat;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart' show showBoatSheet;
import '../application/marina_controller.dart';
import 'marina_community_screen.dart';

/// MARİNAM kartı — Tekne sekmesi (onaylı görsel konsept Ekran 11).
///
/// AÇIK RIZA İLKESİ: telefondaki tekne kendiliğinden sunucuya GİTMEZ;
/// "Topluluğa katıl" düğmesi tek katılım yoludur ve katılan tekne varsayılan
/// GİZLİDİR (yalnız isimsiz sayıya eklenir). "Marinada görün" ve "tip/boy/
/// marka paylaş" anahtarları sunucuda tutulur; kart sunucu kaydını tek
/// doğruluk kaynağı sayar.
class MarinamCard extends ConsumerStatefulWidget {
  const MarinamCard({super.key});

  @override
  ConsumerState<MarinamCard> createState() => _MarinamCardState();
}

class _MarinamCardState extends ConsumerState<MarinamCard> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Katılım / anahtar / eşitleme: hepsi aynı PUT ucundan geçer.
  Future<void> _put({
    required MyBoat local,
    required bool visible,
    required bool shareSpecs,
  }) async {
    if (_busy) return;
    final String? typeCode = serverBoatTypeCode(local.typeId);
    final String? name = local.name?.trim();
    if (name == null || name.isEmpty || typeCode == null) {
      _snack(ref.read(l10nProvider).marinamNeedNameType);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(marinaGatewayProvider).upsertMyBoat(
            name: name,
            boatTypeCode: typeCode,
            lengthM: local.lengthM,
            brand: local.brand,
            // Hafta 2 (Tekne Kartı): model + yıl da sunucuya gider ki
            // kartta MODELE ÖZEL çizim seçilebilsin.
            model: local.model,
            buildYear: local.buildYear,
            marinaLocationId: local.homeMarina!.id,
            visible: visible,
            shareSpecs: shareSpecs,
          );
      ref.invalidate(myServerBoatProvider);
      ref.invalidate(marinaCommunityProvider(local.homeMarina!.id));
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final bool member = auth is Authenticated && !auth.isGuest;

    // DURUM 1: hesap yok → topluluk için giriş daveti.
    if (!member) {
      return _Shell(
        t: t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.marinamNeedAccount,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 10),
            _WhiteButton(
              keyValue: 'marinam-signin',
              label: t.accCta,
              onTap: () => showSignInSheet(context),
            ),
          ],
        ),
      );
    }

    // DURUM 2: tekne/marina seçilmemiş → marina seçim daveti.
    if (boat == null || boat.homeMarina == null) {
      return _Shell(
        t: t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.marinamNeedMarina,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 10),
            _WhiteButton(
              keyValue: 'marinam-pick',
              label: t.marinaPickTitle,
              onTap: () => showBoatSheet(context),
            ),
          ],
        ),
      );
    }

    final HomeMarina marina = boat.homeMarina!;
    final AsyncValue<MyMarinaBoat?> server = ref.watch(myServerBoatProvider);

    return _Shell(
      t: t,
      marinaName: marina.name,
      child: server.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ),
        ),
        error: (Object e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(e is AppFailure ? e.message : '$e',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 8),
            _WhiteButton(
              keyValue: 'marinam-retry',
              label: t.retryLabel,
              onTap: () => ref.invalidate(myServerBoatProvider),
            ),
          ],
        ),
        data: (MyMarinaBoat? mine) {
          final bool joined = mine != null && mine.marinaId == marina.id;
          if (!joined) {
            // DURUM 3: henüz katılmamış (ya da marinası değişmiş) → açık rıza.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(t.marinamJoinSub,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white.withValues(alpha: .9))),
                const SizedBox(height: 10),
                _WhiteButton(
                  keyValue: 'marinam-join',
                  label: _busy ? t.busyLabel : t.marinamJoinCta,
                  onTap: _busy
                      ? null
                      : () => _put(
                            local: boat,
                            visible: mine?.visible ?? false,
                            shareSpecs: mine?.shareSpecs ?? false,
                          ),
                ),
              ],
            );
          }
          // DURUM 4: kayıtlı → sayılar + topluluk + rıza anahtarları.
          return _JoinedBody(
            t: t,
            marinaId: marina.id,
            mine: mine,
            busy: _busy,
            onSee: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => MarinaCommunityScreen(marinaId: marina.id)),
            ),
            onVisible: (bool v) =>
                _put(local: boat, visible: v, shareSpecs: mine.shareSpecs),
            onSpecs: (bool v) =>
                _put(local: boat, visible: mine.visible, shareSpecs: v),
          );
        },
      ),
    );
  }
}

/// Kart kabuğu — Kaptan Kartı ailesinden lacivert→mavi degrade.
class _Shell extends StatelessWidget {
  const _Shell({required this.t, required this.child, this.marinaName});

  final L10n t;
  final Widget child;
  final String? marinaName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[DocklyColors.brandDeep, DocklyColors.brandPrimary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Text('🏠', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                marinaName ?? t.marinamTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(t.marinamSub,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .75))),
          ),
          child,
        ],
      ),
    );
  }
}

class _JoinedBody extends ConsumerWidget {
  const _JoinedBody({
    required this.t,
    required this.marinaId,
    required this.mine,
    required this.busy,
    required this.onSee,
    required this.onVisible,
    required this.onSpecs,
  });

  final L10n t;
  final String marinaId;
  final MyMarinaBoat mine;
  final bool busy;
  final VoidCallback onSee;
  final ValueChanged<bool> onVisible;
  final ValueChanged<bool> onSpecs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<MarinaCommunity> community =
        ref.watch(marinaCommunityProvider(marinaId));
    final String total =
        community.valueOrNull != null ? '${community.valueOrNull!.total}' : '…';
    final String visible = community.valueOrNull != null
        ? '${community.valueOrNull!.visibleCount}'
        : '…';

    Widget count(String v, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: <Widget>[
              Text(v,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 8.5,
                      letterSpacing: .3,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );

    Widget toggle({
      required String keyValue,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) =>
        Row(children: <Widget>[
          Expanded(
            child: Text(title,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Switch(
            key: ValueKey<String>(keyValue),
            value: value,
            onChanged: busy ? null : onChanged,
            activeTrackColor: DocklyColors.success,
          ),
        ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(children: <Widget>[
          count(total, t.mcTotalCap),
          const SizedBox(width: 10),
          count(visible, t.mcVisibleCap),
        ]),
        const SizedBox(height: 10),
        _WhiteButton(
            keyValue: 'marinam-see', label: t.marinamSeeCta, onTap: onSee),
        const SizedBox(height: 4),
        toggle(
          keyValue: 'marinam-visible',
          title: t.marinamVisibleToggle,
          value: mine.visible,
          onChanged: onVisible,
        ),
        toggle(
          keyValue: 'marinam-specs',
          title: t.marinamSpecsToggle,
          value: mine.shareSpecs,
          onChanged: onSpecs,
        ),
        Text(
          '🔒 ${t.marinamPrivacyNote}',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: Colors.white.withValues(alpha: .75)),
        ),
      ],
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton(
      {required this.keyValue, required this.label, required this.onTap});

  final String keyValue;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey<String>(keyValue),
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: DocklyColors.brandDeep,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}
