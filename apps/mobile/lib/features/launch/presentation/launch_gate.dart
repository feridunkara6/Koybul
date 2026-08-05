import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../map/application/map_controller.dart';
import '../../map/domain/map_viewport.dart';
import '../data/shared_prefs_launch_store.dart';
import '../domain/launch_answers.dart';
import '../domain/launch_store.dart';
import 'question_screens.dart';
import 'welcome_screen.dart';

/// Açılış akışı deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<LaunchStore> launchStoreProvider =
    Provider<LaunchStore>((ref) => const SharedPrefsLaunchStore());

/// AÇILIŞ KAPISI (onaylı tasarım 2026-08, Paket 2: E2 + E3–E5).
///
/// İLK açılış: karşılama (E2) → tekne tipi (E3) → ölçüler (E4) → bölge (E5)
/// → harita. DÖNEN kullanıcı hiçbirini görmez. Kurallar:
/// - "Soruları atla" kalan TÜM soruları atlar; o ana dek verilen cevaplar
///   YİNE uygulanır (atlayan cezalandırılmaz).
/// - Adım cihaza işlenir (`onb.v2.step`): sekmeyi E4'te kapatan, E4'te açar.
/// - Tekne cevapları MEVCUT "Teknem" modeline yazılır (tek gerçek kaynak;
///   çift tekne kaydı oluşmaz). Bölge, haritanın açılış odağı olur.
/// - "Giriş yap" akışı TAMAMLAMAZ (dönünce kaldığı yerden).
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<LaunchGate> {
  /// null = depo okunuyor; true = kabuk; false = akış.
  bool? _done;

  /// 0 karşılama · 1 tekne tipi · 2 ölçüler · 3 bölge.
  int _step = 0;

  // Akış içinde toplanan cevaplar (hepsi isteğe bağlı).
  BoatTypeChoice? _type;
  double? _lengthM;
  double? _draftM;
  int? _regionIndex;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final LaunchStore store = ref.read(launchStoreProvider);
      final bool done = await store.isDone();
      // Yarım kalan akış kaldığı adımdan sürer (onaylı iyileştirme).
      final int step = done ? 0 : (await store.step()).clamp(0, 3);
      if (mounted) {
        setState(() {
          _done = done;
          _step = step;
        });
      }
    });
  }

  void _goto(int step) {
    ref.read(launchStoreProvider).setStep(step); // en iyi çaba, beklenmez
    setState(() => _step = step);
  }

  /// Akışı bitirir: karar cihaza, cevaplar sistemlere.
  /// [applyRegion] yalnız E5 CTA'sında true — "Soruları atla" bölge odağı
  /// uygulamaz (seçilmemiş bölge uydurulamaz).
  void _complete({bool applyRegion = false}) {
    ref.read(launchStoreProvider).markDone();
    // Tekne: boy verilmişse MEVCUT modele yazılır (marka korunur — tek
    // gerçek kaynak Profil → Teknem ile aynı depo).
    final double? len = _lengthM;
    if (len != null) {
      final MyBoat? current = ref.read(myBoatProvider);
      ref.read(myBoatProvider.notifier).set(MyBoat(
            lengthM: len,
            draftM: _draftM,
            brand: current?.brand,
            typeId: _type?.id,
          ));
    }
    // Bölge: haritanın açılış odağı (yüzey onMapReady'de uygular).
    final int? region = applyRegion ? _regionIndex : null;
    if (region != null) {
      final LaunchRegion r = kLaunchRegions[region];
      final MapFocusRequest? prev = ref.read(mapFocusProvider);
      ref.read(mapFocusProvider.notifier).state = MapFocusRequest(
        point: GeoPoint(lat: r.lat, lon: r.lon),
        seq: (prev?.seq ?? 0) + 1,
        zoom: kRegionFocusZoom,
      );
    }
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

    final Widget current = switch (_step) {
      0 => WelcomeScreen(
          key: const ValueKey<String>('launch-step-0'),
          onStart: () => _goto(1),
        ),
      1 => BoatTypeScreen(
          key: const ValueKey<String>('launch-step-1'),
          selected: _type,
          onSelect: (BoatTypeChoice c) => setState(() => _type = c),
          onContinue: () => _goto(2),
          onSkipAll: _complete,
        ),
      2 => BoatSizeScreen(
          key: const ValueKey<String>('launch-step-2'),
          initialLengthM: _lengthM ?? (_type ?? BoatTypeChoice.sail).defaultLengthM,
          initialDraftM: _draftM ?? (_type ?? BoatTypeChoice.sail).defaultDraftM,
          onContinue: (double lengthM, double draftM) {
            _lengthM = lengthM;
            _draftM = draftM;
            _goto(3);
          },
          onSkipAll: _complete,
        ),
      _ => RegionScreen(
          key: const ValueKey<String>('launch-step-3'),
          selectedIndex: _regionIndex,
          onSelect: (int i) => setState(() => _regionIndex = i),
          onOpenMap: () => _complete(applyRegion: true),
          onSkipAll: _complete,
        ),
    };

    // Adımlar arası yumuşak geçiş: sağdan süzülme + solma (onaylı animasyon
    // dili). Tek yönlü ilerleme olduğundan yön hep aynıdır.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (Widget child, Animation<double> anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: current,
    );
  }
}
