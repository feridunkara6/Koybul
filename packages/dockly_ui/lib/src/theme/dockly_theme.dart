import 'package:flutter/material.dart';

import 'dockly_colors.dart';

/// Uygulama teması — tasarım sistemiyle birebir (docs/09,
/// design/dockly-design-system.html). Material 3 `fromSeed` yerine renkler
/// açıkça tasarım token'larına eşlenir; böylece marka mavisi, yumuşak arka plan
/// ve net metin renkleri aynen görünür (light + dark).
ThemeData buildDocklyTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;

  final Color primary = dark ? DocklyColors.brandPrimaryDark : DocklyColors.brandPrimary;
  final Color bgBase = dark ? DocklyColors.bgBaseDark : DocklyColors.bgBase;
  final Color surface = dark ? DocklyColors.bgSurfaceDark : DocklyColors.bgSurface;
  final Color text1 = dark ? DocklyColors.text1Dark : DocklyColors.text1;
  final Color text2 = dark ? DocklyColors.text2Dark : DocklyColors.text2;
  final Color hairline = dark ? DocklyColors.hairlineDark : DocklyColors.hairline;

  // Seed'den başlanır (container/ikincil roller için makul varsayılanlar),
  // sonra tasarım token'larıyla ezilir.
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    secondary: DocklyColors.accentTurquoise,
    onSecondary: DocklyColors.brandDeep,
    surface: surface,
    onSurface: text1,
    onSurfaceVariant: text2,
    error: DocklyColors.error,
    onError: Colors.white,
    outline: hairline,
    outlineVariant: hairline,
  );

  final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16), // --r-md
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bgBase,
    dividerColor: hairline,
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape.copyWith(
        side: BorderSide(color: hairline),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: hairline),
      backgroundColor: surface,
      showCheckmark: true,
    ),
    // Birincil buton (tasarım .btn-primary): mavi dolgu, beyaz metin, mavi gölge.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        // SONSUZ GENİŞLİK YASAK (üretim dersi 2026-08): Size.fromHeight →
        // sonsuz MIN genişlik. Satır (Row) içindeki her düğmeyi sessizce
        // GÖRÜNMEZ yapıyordu (kayıtlı rota kartı vakası). Tam genişlik
        // isteyen yerler bunu zaten SizedBox(width: double.infinity) /
        // stretch ile kendisi istiyor — temada yalnız YÜKSEKLİK sabitlenir.
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 6,
        shadowColor: primary,
      ),
    ),
    // İkincil buton (tasarım .btn-secondary): şeffaf zemin, 1.5px mavi kenar, mavi metin.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        // Sonsuz genişlik yasak — üstteki filledButtonTheme notuna bak.
        minimumSize: const Size(0, 52),
        side: BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
