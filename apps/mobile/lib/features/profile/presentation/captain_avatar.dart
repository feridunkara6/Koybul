import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';

/// KAPTAN AVATARI (SP-1 Kimlik, kurucu onayı 2026-10-29).
///
/// Fotoğraf yükleme altyapısı olmadan tutarlı görsel kimlik: kimlikten
/// ([seed], yoksa [name]) türetilen SABİT bir renk çifti + görünen adın baş
/// harfleri. Aynı kaptan her yüzeyde (not, yorum, soru-cevap, kaptan kartı)
/// AYNI renkte görünür — "bu kim?" sorusunun ilk görsel cevabı.
///
/// Ad boşsa harf UYDURULMAZ (0-uydurma): düz çapa işareti çizilir.
class CaptainAvatar extends StatelessWidget {
  const CaptainAvatar({
    required this.name,
    this.seed,
    this.size = 40,
    super.key,
  });

  /// Görünen ad — baş harfler bundan türetilir.
  final String name;

  /// Renk tohumu (kullanıcı kimliği). Verilmezse ad kullanılır; kimlikle
  /// türetim daha kararlıdır (ad değişse de renk kalır).
  final String? seed;

  final double size;

  /// Denizci tonlarında sabit palet — tohum karmasıyla seçilir.
  static const List<(Color, Color)> _palette = <(Color, Color)>[
    (Color(0xFF0C7BDC), Color(0xFF2EC4B6)), // deniz mavisi → turkuaz
    (Color(0xFF0A2540), Color(0xFF10517E)), // lacivert → derin mavi
    (Color(0xFF0B7A6F), Color(0xFF2EC4B6)), // koyu turkuaz → turkuaz
    (Color(0xFFB7791F), Color(0xFFE2B007)), // kehribar → altın
    (Color(0xFF6B4FD8), Color(0xFF9B59D0)), // mor tonları
    (Color(0xFF8E44AD), Color(0xFFC0392B)), // mor → mercan
  ];

  /// Görünen adın ilk iki kelimesinden baş harfler — PublicCaptain.initials
  /// ile AYNI kural (tek kaynak dil: ad boşsa boş döner, harf uydurulmaz).
  static String initialsOf(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final String a = parts.first[0];
    final String b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String key = (seed == null || seed!.isEmpty) ? name : seed!;
    int hash = 0;
    for (final int c in key.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    final (Color, Color) colors = _palette[hash % _palette.length];
    final String initials = initialsOf(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.$1, colors.$2],
        ),
      ),
      child: Center(
        child: initials.isEmpty
            ? DocklyIcon(DocklyIcons.sailing,
                size: size * 0.5, color: const Color(0xFFFFFFFF))
            : Text(
                initials,
                style: TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.38,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
