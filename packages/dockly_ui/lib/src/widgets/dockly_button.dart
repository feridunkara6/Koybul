import 'package:flutter/material.dart';

import 'dockly_icon.dart';

/// Buton varyantları (docs/10 component library).
enum DocklyButtonVariant { primary, secondary }

/// Dockly birincil/ikincil buton (docs/09 §buton, docs/10). Yükleme durumunda
/// genişliğini korur, metin yerine spinner gösterir ve dokunmayı engeller.
class DocklyButton extends StatelessWidget {
  const DocklyButton({
    required this.label,
    required this.onPressed,
    this.variant = DocklyButtonVariant.primary,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final DocklyButtonVariant variant;
  final bool loading;
  final DocklyIconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    final child = loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : _Label(label: label, icon: icon);

    switch (variant) {
      case DocklyButtonVariant.primary:
        return FilledButton(onPressed: effectiveOnPressed, child: child);
      case DocklyButtonVariant.secondary:
        return OutlinedButton(onPressed: effectiveOnPressed, child: child);
    }
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, this.icon});

  final String label;
  final DocklyIconData? icon;

  @override
  Widget build(BuildContext context) {
    final DocklyIconData? icon = this.icon;
    if (icon == null) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    // TAŞMA EMNİYETİ (CI dersi 2026-08): dar butonda (örn. alt kartta yan yana
    // iki buton) uzun etiket taşarsa Flutter bunu HATA sayar (RenderFlex
    // overflow — testleri kırar, gerçek cihazda sarı çizgili şerit çizer).
    // Etiket Flexible + ellipsis ile sığmadığında zarifçe kısalır; ikon sabit.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DocklyIcon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
