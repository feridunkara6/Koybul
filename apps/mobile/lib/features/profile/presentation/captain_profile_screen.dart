import 'package:dockly_api/dockly_api.dart'
    show CaptainContribution, PublicCaptain;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_gate.dart';
import '../../community/presentation/reputation_shell.dart' show formatCount;
import '../application/block_controller.dart';
import '../application/follow_controller.dart';
import '../application/profile_controller.dart';
import 'captain_avatar.dart';
import 'follow_list_screen.dart';

/// HERKESE AÇIK KAPTAN PROFİLİ (Sosyalleşme Hafta 1B, kurucu onayı
/// 2026-10-24) — "kimlik → keşif → geri çağırma" zincirinin keşif halkası.
///
/// İçerikteki (S-C sorusu/cevabı) yazar adına dokununca açılır. YALNIZ
/// kullanıcının topluluğa zaten imzaladığı kimlik + kendi beyan ettiği
/// tanıtım + sunucunun hesapladığı itibar görünür; e-posta, konum, marina
/// ve seyir verisi BU EKRANDA YOKTUR (gizlilik kuralı §9/§10).
class CaptainProfileScreen extends ConsumerWidget {
  const CaptainProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<PublicCaptain> async = ref.watch(publicCaptainProvider(userId));
    // ENGELLEME (ENG-1, kurucu onayı 2026-11-03): ⋯ menüsü yalnız ÜYEYE ve
    // başkasının profilinde görünür (misafir zaten etkileşemez; kendini
    // engellemek sunucuda da 422).
    final AuthState auth = ref.watch(authControllerProvider);
    final bool showMenu = auth is Authenticated &&
        !auth.isGuest &&
        auth.user.id != userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.cpTitle),
        actions: <Widget>[
          if (showMenu) _BlockMenu(userId: userId, t: t),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.peLoadFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(publicCaptainProvider(userId)),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (PublicCaptain c) => _Body(c: c, t: t),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.c, required this.t});

  final PublicCaptain c;
  final L10n t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    // Kendi kartımda takip düğmesi çizilmez (kendini takip sunucuda da 422).
    final AuthState auth = ref.watch(authControllerProvider);
    final bool isSelf = auth is Authenticated && auth.user.id == c.id;
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        // KİMLİK BAŞLIĞI (PR-1 profil düzeni, kurucu onayı 2026-11-03):
        // Instagram/Strava karışımı — solda büyük avatar, sağda üç sayaç.
        // Sayılar herkese açık; LİSTELER kurucu kuralıyla üyelik ister
        // (misafir sayaca dokununca hesaba davet edilir).
        Row(
          children: <Widget>[
            // SP-1 Kimlik (2026-10-29): kimlikten türeyen renkli avatar —
            // aynı kaptan her yüzeyde aynı renk (captain_avatar.dart).
            CaptainAvatar(name: c.displayName, seed: c.id, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: <Widget>[
                  _CountCell(
                    keyValue: 'cp-cnt-followers',
                    caption: t.cpFollowersCap,
                    value: formatCount(t, c.followerCount),
                    onTap: () => _openList(context, ref, 0),
                  ),
                  const SizedBox(width: 6),
                  _CountCell(
                    keyValue: 'cp-cnt-following',
                    caption: t.cpFollowingCap,
                    value: formatCount(t, c.followingCount),
                    onTap: () => _openList(context, ref, 1),
                  ),
                  const SizedBox(width: 6),
                  _CountCell(
                    keyValue: 'cp-cnt-contrib',
                    caption: t.cpContribCap,
                    value: formatCount(t, c.approvedCount),
                    onTap: null, // katkılar zaten aşağıda vitrinde
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // AD + SEVİYE ÇİPİ — ad anahtarı testlerle sözleşmelidir (cp-name).
        Row(
          children: <Widget>[
            Flexible(
              child: Text(c.displayName,
                  key: const ValueKey<String>('cp-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: DocklyColors.accentTurquoise.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                t.levelLabel(c.levelCode),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: DocklyColors.accentTurquoise,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Üyelik yılı + deneyim — yalnız yıl hassasiyeti (gizlilik tasarımı).
        Text(
          <String>[
            L10n.fmt(t.cpMemberFmt, '${c.memberSince.year}'),
            if (c.experienceYears != null)
              L10n.fmt(t.cpExpFmt, '${c.experienceYears}'),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: sub),
        ),
        // TAKİP DÜĞMESİ (SP-3a, 2026-10-31): içerik aboneliği — DM hakkı
        // vermez. Misafir dokununca hesap kapısı açılır (kurucu kuralı:
        // hesapsız kullanıcı etkileşime geçemez).
        if (!isSelf) ...<Widget>[
          const SizedBox(height: 12),
          _FollowButton(captainId: c.id, t: t),
        ],
        // TANITIM — kullanıcı yazdıysa; yoksa bölüm hiç çizilmez.
        if (c.bio != null && c.bio!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
            ),
            child: Text(c.bio!.trim(), style: theme.textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: 14),
        // SEZON ŞERİDİ (PR-1): puan + faydalı + paylaşılan seyir/rota —
        // hepsi sunucu hesabı; uydurma yok. (Takipçi/katkı yukarıda sayaçta.)
        Row(
          children: <Widget>[
            _Stat(caption: t.cpPointsCap, value: formatCount(t, c.points)),
            const SizedBox(width: 8),
            _Stat(
                caption: t.cpHelpfulShort,
                value: formatCount(t, c.helpfulReceived)),
            const SizedBox(width: 8),
            _Stat(caption: t.cpTripsCap, value: formatCount(t, c.sharedTrips)),
            const SizedBox(width: 8),
            _Stat(
                caption: t.cpRoutesCap, value: formatCount(t, c.sharedRoutes)),
          ],
        ),
        // ROZETLER — kod → yerel etiket; hiç yoksa bölüm çizilmez.
        if (c.badges.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(t.cpBadges.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: .8, color: sub)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String code in c.badges)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.badgeName(code),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
        // SON KATKILARI vitrini (SP-1 Kimlik, 2026-10-29): yalnız ONAYLI
        // içerik — sunucu hesaplar, istemci yalnız gösterir. Boşsa çizilmez.
        if (c.recentContributions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(t.cpRecent.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: .8, color: sub)),
          const SizedBox(height: 8),
          for (final CaptainContribution x in c.recentContributions)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: theme.dividerColor.withValues(alpha: .4)),
              ),
              child: Row(
                children: <Widget>[
                  DocklyIcon(
                    x.kind == 'route'
                        ? DocklyIcons.navigation
                        : DocklyIcons.eventNoteOutlined,
                    size: 16,
                    color: DocklyColors.accentTurquoise,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      x.kind == 'route'
                          ? '${t.cpRouteTag} · ${x.title ?? ''}'
                          : <String>[
                              if (x.noteKind != null)
                                t.noteKindLabel(x.noteKind!),
                              if (x.title != null && x.title!.isNotEmpty)
                                x.title!,
                            ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    // Yalnız gün hassasiyeti — vitrin satırı sade kalır.
                    x.createdAt.length >= 10 ? x.createdAt.substring(0, 10) : '',
                    style: theme.textTheme.labelSmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Sayaç dokunuşu (PR-1): üye → liste ekranı; hesapsız → hesaba davet.
  void _openList(BuildContext context, WidgetRef ref, int tab) {
    requireAccount(
      context,
      ref,
      message: ref.read(l10nProvider).gateFollowListMsg,
      onAllowed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FollowListScreen(
            userId: c.id,
            displayName: c.displayName,
            initialTab: tab,
          ),
        ),
      ),
    );
  }
}

/// ⋯ MENÜSÜ (ENG-1): "Bu kaptanı engelle" / "Engeli kaldır".
/// Engelleme SESSİZDİR — karşı tarafa hiçbir sinyal gitmez; onay sayfası
/// ne olacağını DÜRÜSTÇE sayar (geri alınabilirlik dahil).
class _BlockMenu extends ConsumerWidget {
  const _BlockMenu({required this.userId, required this.t});

  final String userId;
  final L10n t;

  Future<void> _setBlocked(
    BuildContext context,
    WidgetRef ref, {
    required bool blocked,
  }) async {
    try {
      await ref
          .read(blockActionsProvider)
          .setBlocked(userId, blocked: blocked);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(blocked ? t.blockDoneMsg : t.unblockMenuItem)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.actionFailed)));
    }
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(t.blockConfirmTitle),
        content: Text(t.blockConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancelLabel),
          ),
          FilledButton(
            key: const ValueKey<String>('cp-block-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.blockConfirmBtn),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _setBlocked(context, ref, blocked: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool blocked = ref.watch(blockedIdsProvider).contains(userId);
    return PopupMenuButton<String>(
      key: const ValueKey<String>('cp-more'),
      onSelected: (String v) {
        if (v == 'block') {
          _confirmBlock(context, ref);
        } else if (v == 'unblock') {
          _setBlocked(context, ref, blocked: false);
        }
      },
      itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
        if (blocked)
          PopupMenuItem<String>(
            key: const ValueKey<String>('cp-unblock'),
            value: 'unblock',
            child: Text(t.unblockMenuItem),
          )
        else
          PopupMenuItem<String>(
            key: const ValueKey<String>('cp-block'),
            value: 'block',
            child: Text(
              t.blockMenuItem,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

/// Başlık sayacı (PR-1): değer + küçük başlık; dokunulabilir olanlar hafif
/// zeminle ayrılır (dokunulabilirlik ipucu).
class _CountCell extends StatelessWidget {
  const _CountCell({
    required this.keyValue,
    required this.caption,
    required this.value,
    required this.onTap,
  });

  final String keyValue;
  final String caption;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: onTap == null
            ? Colors.transparent
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey<String>(keyValue),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              children: <Widget>[
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// TAKİP DÜĞMESİ (SP-3a, kurucu onayı 2026-10-31).
///
/// Durum `followedIdsProvider`'dan okunur (tek doğruluk kaynağı: sunucudaki
/// listem). Dokunuş hesap kapısından geçer; eylem sürerken düğme kilitlenir
/// (çift dokunuş koruması). Hata kullanıcıya SÖYLENİR (sessiz yutma yok).
class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.captainId, required this.t});

  final String captainId;
  final L10n t;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _busy = false;

  Future<void> _toggle({required bool follow}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(followActionsProvider)
          .setFollowing(widget.captainId, follow: follow);
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
    final bool following =
        ref.watch(followedIdsProvider).contains(widget.captainId);
    if (following) {
      // Takipteyim — ikinci dokunuş takibi bırakır (ayrı onay sormaz;
      // eylem idempotent ve anında geri alınabilir).
      return OutlinedButton.icon(
        key: const ValueKey<String>('cp-follow-btn'),
        onPressed: _busy ? null : () => _toggle(follow: false),
        icon: const DocklyIcon(DocklyIcons.checkCircle, size: 16),
        label: Text(t.followingBtn),
      );
    }
    return FilledButton.tonalIcon(
      key: const ValueKey<String>('cp-follow-btn'),
      onPressed: _busy
          ? null
          : () => requireAccount(
                context,
                ref,
                message: t.gateFollowMsg,
                onAllowed: () => _toggle(follow: true),
              ),
      icon: const DocklyIcon(DocklyIcons.personOutline, size: 16),
      label: Text(t.followBtn),
    );
  }
}

/// Sayı hücresi — denizci kartındaki _Stat ile aynı görsel dil.
class _Stat extends StatelessWidget {
  const _Stat({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4)),
          ],
        ),
      ),
    );
  }
}
