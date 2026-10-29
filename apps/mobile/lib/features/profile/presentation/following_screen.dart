import 'package:dockly_api/dockly_api.dart' show FollowedCaptain;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/follow_controller.dart';
import 'captain_avatar.dart';
import 'captain_profile_screen.dart';

/// TAKİP ETTİKLERİM (SP-3a, kurucu onayı 2026-10-31).
///
/// Profil → Topluluk altından açılır. Satıra dokununca kaptanın herkese
/// açık kartı açılır; takibi bırakma O kartta yapılır (tek ev kuralı —
/// burada ikinci bir düğme çoğaltılmaz). Misafirde liste hep boştur
/// (controller sunucuya hiç gitmez); boş durum metni hesaba yönlendirir.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<FollowedCaptain>> async = ref.watch(followingProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.followingTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.actionFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(followingProvider),
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
                  t.followingEmpty,
                  key: const ValueKey<String>('following-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (BuildContext context, int i) {
              final FollowedCaptain f = list[i];
              return _CaptainRow(f: f, t: t);
            },
          );
        },
      ),
    );
  }
}

class _CaptainRow extends StatelessWidget {
  const _CaptainRow({required this.f, required this.t});

  final FollowedCaptain f;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      key: ValueKey<String>('following-row-${f.id}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaptainProfileScreen(userId: f.id),
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
            // Aynı kaptan her yüzeyde aynı renk (SP-1 avatar kuralı).
            CaptainAvatar(name: f.displayName, seed: f.id, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    f.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    t.levelLabel(f.levelCode),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: DocklyColors.accentTurquoise,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DocklyIcon(DocklyIcons.arrowForward,
                size: 15, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
