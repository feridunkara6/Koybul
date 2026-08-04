import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aktif alt sekme dizini (0 = Keşfet … 4 = Profil). Kabuk bunu izler;
/// başka ekranlar da sekme değiştirebilir (ör. Profil → "Tanıtım turunu
/// tekrar izle" Keşfet'e döner, tanıtım 2026-08).
final StateProvider<int> shellTabProvider = StateProvider<int>((ref) => 0);
