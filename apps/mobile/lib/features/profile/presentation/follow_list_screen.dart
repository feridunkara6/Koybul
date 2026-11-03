import 'package:dockly_api/dockly_api.dart' show FollowedCaptain;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../application/follow_controller.dart';
import 'captain_avatar.dart';
import 'captain_profile_screen.dart';

/// TAKİPÇİ / TAKİP LİSTESİ (PR-1 profil düzeni, kurucu onayı 2026-11-03).
///
/// Profil başlığındaki TAKİPÇİ/TAKİP sayacına dokununca açılır — hem kendi
/// profilinden hem başka kaptanın kartından. Kurucu kuralı: bu ekran yalnız
/// GİRİŞ YAPMIŞ ÜYEYE açılır (sayaç misafirde hesaba davet eder); ekranın
/// kendisi de oturumsuzken sunucuya hiç gitmez (controller boş döndürür).
/// Satırdaki hızlı düğmeyle listeden ayrılmadan takip edilir (Instagram
/// deseni); satıra dokununca o kaptanın profili açılır.
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    required this.userId,
    required this.displayName,
    this.initialTab = 0,
    super.key,
  });

  /// Listeleri gösterilen kaptan (kendi profilin de olabilir).
  final String userId;

  /// Başlıkta gösterilen ad.
  final String displayName;

  /// 0 = Takipçiler, 1 = Takip.
  final int initialTab;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<FollowedCaptain>> async = _tab == 0
        ? ref.watch(captainFollowersProvider(widget.userId))
        : ref.watch(captainFollowingProvider(widget.userId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.displayName)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: <Widget>[
                _SegBtn(
                  keyValue: 'fl-tab-followers',
                  label: t.flFollowersTab,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 6),
                _SegBtn(
                  keyValue: 'fl-tab-following',
                  label: t.flFollowingTab,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child:
                          Text(t.actionFailed, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(_tab == 0
                          ? captainFollowersProvider(widget.userId)
                          : captainFollowingProvider(widget.userId)),
                      child: Text(t.retryLabel),
                    ),
                  ],
                ),
              ),
              data: (List<FollowedCaptain> list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _tab == 0 ? t.flFollowersEmpty : t.flFollowingEmpty,
                        key: const ValueKey<String>('fl-empty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (BuildContext context, int i) =>
                      _CaptainRow(f: list[i], t: t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekme düğmesi — etkinlik ekranındaki parça ailesiyle aynı dil.
class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.keyValue,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String keyValue;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey<String>(keyValue),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste satırı: avatar + ad + seviye; sağda hızlı takip düğmesi.
class _CaptainRow extends ConsumerStatefulWidget {
  const _CaptainRow({required this.f, required this.t});

  final FollowedCaptain f;
  final L10n t;

  @override
  ConsumerState<_CaptainRow> createState() => _CaptainRowState();
}

class _CaptainRowState extends ConsumerState<_CaptainRow> {
  bool _busy = false;

  Future<void> _toggle({required bool follow}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(followActionsProvider)
          .setFollowing(widget.f.id, follow: follow);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(widget.t.actionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = widget.t;
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool isSelf = auth is Authenticated &&
        !auth.isGuest &&
        auth.user.id == widget.f.id;
    final bool following =
        ref.watch(followedIdsProvider).contains(widget.f.id);
    return InkWell(
      key: ValueKey<String>('fl-row-${widget.f.id}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaptainProfileScreen(userId: widget.f.id),
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
            CaptainAvatar(
                name: widget.f.displayName, seed: widget.f.id, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.f.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    t.levelLabel(widget.f.levelCode),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: DocklyColors.accentTurquoise,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Kendi satırında düğme yok (kendini takip sunucuda da 422).
            if (!isSelf)
              following
                  ? OutlinedButton(
                      key: ValueKey<String>('fl-unfollow-${widget.f.id}'),
                      onPressed:
                          _busy ? null : () => _toggle(follow: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(t.followingBtn),
                    )
                  : FilledButton.tonal(
                      key: ValueKey<String>('fl-follow-${widget.f.id}'),
                      onPressed: _busy ? null : () => _toggle(follow: true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(t.followBtn),
                    ),
          ],
        ),
      ),
    );
  }
}
