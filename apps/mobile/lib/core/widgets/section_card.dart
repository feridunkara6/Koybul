import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';

/// Detay sayfası bölüm kartı (yeniden tasarım 2026-08, kullanıcı onaylı C):
/// ikonlu başlık + içerik, yumuşak zeminli yuvarlak kart. Tüm bölümler aynı
/// dili konuşsun diye ortak — detay ekranı, yorumlar ve yakın alternatifler
/// kullanır. Tema-duyarlı (karanlık modda koyu yüzey).
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.margin = const EdgeInsets.only(top: 12),
    super.key,
  });

  final DocklyIconData icon;
  final String title;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: DocklyIcon(icon, size: 15, color: DocklyColors.brandPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
