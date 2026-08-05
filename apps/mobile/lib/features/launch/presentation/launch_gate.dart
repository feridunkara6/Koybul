import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_launch_store.dart';
import '../domain/launch_store.dart';
import 'welcome_screen.dart';

/// Açılış akışı deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<LaunchStore> launchStoreProvider =
    Provider<LaunchStore>((ref) => const SharedPrefsLaunchStore());

/// AÇILIŞ KAPISI (onaylı tasarım 2026-08, Paket 1 iskeleti).
///
/// İLK açılışta karşılama ekranını (E2) gösterir; "Keşfe başla" ile karar
/// cihaza işlenir ve kabuk (harita) açılır. DÖNEN kullanıcı karşılamayı hiç
/// görmez — splash'tan doğrudan haritaya (onaylı E1 kuralı). "Giriş yap"
/// karşılamayı TAMAMLAMAZ: giriş sayfasından dönünce akış kaldığı yerden
/// sürer (onaylı E2 kuralı).
///
/// Paket 2 notu: sorular (E3–E5) bu kapının içine, karşılama ile kabuk
/// arasına eklenecek; depo anahtarı (`onb.v2.*`) buna hazır.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<LaunchGate> {
  /// null = depo okunuyor; true = kabuk; false = karşılama.
  bool? _done;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final bool done = await ref.read(launchStoreProvider).isDone();
      if (mounted) setState(() => _done = done);
    });
  }

  void _finish() {
    // Karar ANINDA cihaza işlenir (tur v2 dersi): yarıda kapansa bile
    // karşılama bir daha kendiliğinden açılmaz.
    ref.read(launchStoreProvider).markDone();
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool? done = _done;
    if (done == null) {
      // Kısacık depo okuması: boş zemin (splash görseli zaten üstte).
      return Scaffold(
        body: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
      );
    }
    if (done) return widget.child;
    return WelcomeScreen(onStart: _finish);
  }
}
