import 'package:dockly_api/dockly_api.dart' show PublicCaptain;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../community/presentation/reputation_shell.dart' show formatCount;
import '../application/profile_controller.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(t.cpTitle)),
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

class _Body extends StatelessWidget {
  const _Body({required this.c, required this.t});

  final PublicCaptain c;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        // KİMLİK BAŞLIĞI — denizci kartıyla aynı dil: baş harfler + ad +
        // seviye. Ad yoksa harf uydurulmaz (0-uydurma).
        Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: DocklyColors.accentTurquoise.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: c.initials.isEmpty
                    ? const DocklyIcon(DocklyIcons.award,
                        size: 22, color: DocklyColors.accentTurquoise)
                    : Text(c.initials,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: DocklyColors.accentTurquoise,
                            fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(c.displayName,
                      key: const ValueKey<String>('cp-name'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    t.levelLabel(c.levelCode),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: DocklyColors.accentTurquoise,
                        fontWeight: FontWeight.w700),
                  ),
                ],
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
        // İTİBAR SAYILARI — sunucu hesabı; uydurma yok.
        Row(
          children: <Widget>[
            _Stat(caption: t.sailorPointsCap, value: formatCount(t, c.points)),
            const SizedBox(width: 8),
            _Stat(caption: t.cpApprovedCap, value: formatCount(t, c.approvedCount)),
            const SizedBox(width: 8),
            _Stat(caption: t.cpHelpfulCap, value: formatCount(t, c.helpfulReceived)),
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
      ],
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
