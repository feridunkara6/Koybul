import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../data/academy_content.dart';
import '../domain/guide.dart';

/// AKADEMİ kimlik rengi (onaylı tema evrimi 2026-08): öğrenme moru.
/// Uyarı/tehlike renkleriyle ASLA karışmaz — uyarılar her ekranda kendi
/// rengini korur.
const Color kAcademyPurple = Color(0xFF7C5CD6);

/// DENİZCİLİK AKADEMİSİ (v2.0 "Akademi lite", kurucu onayı 2026-08):
/// 10 kısa rehber. Profil'den ve bağlam kancalarından açılır; içerik
/// çevrimdışı çalışır (ağ gerekmez), dört dilde yazılmıştır.
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<Guide> guides = academyGuides(ref.watch(appLocaleProvider));
    return Scaffold(
      appBar: AppBar(title: Text(t.academyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          // MOR KİMLİK başlığı — Akademi'nin kendi rengi.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[kAcademyPurple, Color(0xFF3B2E7E)],
              ),
            ),
            child: Row(
              children: <Widget>[
                const DocklyIcon(DocklyIcons.helpOutline,
                    size: 22, color: Color(0xFFE9E2FF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.academyLead,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFFFFFFF),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final Guide g in guides) _GuideRow(guide: g),
          const SizedBox(height: 14),
          // DÜRÜSTLÜK NOTU: rehberler resmî eğitimin yerine geçmez.
          Text(
            t.academyDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste satırı: mor ikon kutusu + başlık + tek cümlelik özet.
class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        key: ValueKey<String>('academy-${guide.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => AcademyGuideScreen(guide: guide),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kAcademyPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: DocklyIcon(guide.icon,
                      size: 19, color: kAcademyPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      guide.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guide.summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek rehber sayfası: özet + numaralı adımlar + kaptan notu + dürüstlük notu.
class AcademyGuideScreen extends ConsumerWidget {
  const AcademyGuideScreen({required this.guide, super.key});

  final Guide guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kAcademyPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child:
                      DocklyIcon(guide.icon, size: 21, color: kAcademyPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  guide.summary,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            t.academyPointsTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: kAcademyPurple,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < guide.points.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: kAcademyPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: kAcademyPurple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      guide.points[i],
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          if (guide.note != null) ...<Widget>[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: kAcademyPurple.withValues(alpha: 0.08),
                border: Border.all(
                    color: kAcademyPurple.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.academyNoteTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: kAcademyPurple,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guide.note!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            t.academyDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
