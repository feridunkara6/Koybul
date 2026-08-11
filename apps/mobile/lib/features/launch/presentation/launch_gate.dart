import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/origin_provider.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../location/application/location_controller.dart';
import '../../map/application/map_controller.dart';
import '../../map/domain/map_viewport.dart';
import '../../splash/presentation/splash_screen.dart' show appReadyProvider;
import '../data/shared_prefs_launch_store.dart';
import '../domain/launch_answers.dart';
import '../domain/launch_store.dart';
import 'location_primer_screen.dart';
import 'question_screens.dart';
import 'welcome_screen.dart';

/// Açılış akışı deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<LaunchStore> launchStoreProvider =
    Provider<LaunchStore>((ref) => const SharedPrefsLaunchStore());

/// AÇILIŞ KAPISI (onaylı tasarım 2026-08, Paket 2: E2 + E3–E5).
///
/// İLK açılış: karşılama (E2) → tekne tipi (E3) → ölçüler (E4) → bölge (E5)
/// → konum ön-izni (E6) → harita. DÖNEN kullanıcı hiçbirini görmez. Kurallar:
/// - "Soruları atla" kalan soruları atlar ve E6'ya gider (onaylı akış); o ana
///   dek verilen cevaplar YİNE uygulanır (atlayan cezalandırılmaz).
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

  /// 0 karşılama · 1 tekne tipi · 2 ölçüler · 3 bölge · 4 konum ön-izni.
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
      // İKİ okuma AYNI ANDA (Faz 1 — hız). Eskiden biri bitmeden diğeri
      // başlamıyordu; ikisi de aynı cihaz deposundan okuduğu için sıraya
      // girmelerinin hiçbir karşılığı yoktu.
      // Yarım kalan akış kaldığı adımdan sürer (onaylı iyileştirme).
      //
      // HATA KALKANI: paralelleştirme yan etki getirir — eskiden `step()`
      // yalnız ilk açılışta çağrılıyordu, artık her açılışta çağrılıyor.
      // Depo bir gün fırlatırsa DÖNEN kullanıcı da etkilenirdi ve `_done`
      // sonsuza dek null kalıp uygulamayı BOŞ EKRANDA kilitlerdi. Bozuk
      // depoda doğru davranış "akışı tamamlanmış say"dır: kullanıcı
      // karşılamaya hapsedilmez, doğrudan haritaya girer.
      bool done = true;
      int step = 0;
      try {
        final List<Object> both = await Future.wait<Object>(
            <Future<Object>>[store.isDone(), store.step()]);
        done = both[0] as bool;
        step = done ? 0 : (both[1] as int).clamp(0, 4);
      } catch (_) {
        done = true;
        step = 0;
      }
      if (!mounted) return;
      setState(() {
        _done = done;
        _step = step;
      });
      // AÇILIŞ EKRANINA HABER VER: gösterilecek doğru ekran artık belli.
      // Bundan sonra beklemenin karşılığı yok — marka yüzeyi çekilebilir.
      // (Kapı ağaçtan kalktıysa `ref` kullanılamaz; o durumda açılış kendi
      // tavan süresiyle zaten kapanır.)
      ref.read(appReadyProvider.notifier).state = true;
    });
  }

  void _goto(int step) {
    ref.read(launchStoreProvider).setStep(step); // en iyi çaba, beklenmez
    setState(() => _step = step);
  }

  /// E6: "Konumumu kullan" — tarayıcı izin penceresi BURADA açılır (locateMe).
  /// İzin gelirse kamera konuma iner (locateMe odak isteğini kendisi üretir,
  /// bölge odağı uygulanmaz); gelmezse SESSİZCE bölgeyle devam edilir —
  /// suçlama yok, hiçbir özellik kilitlenmez (onaylı E6 kuralı).
  Future<void> _useLocation() async {
    await ref.read(locationControllerProvider.notifier).locateMe();
    if (!mounted) return;
    final bool granted = ref.read(devicePositionProvider) != null;
    _complete(applyRegion: !granted);
  }

  /// Akışı bitirir: karar cihaza, cevaplar sistemlere.
  /// [applyRegion] E6 çıkışlarında true olur; "seçilmemiş bölge" uydurulamaz —
  /// kullanıcı E5'te bölge seçmediyse odak yine uygulanmaz.
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
          onSkipAll: () => _goto(4), // onaylı akış: Atla → E6 (konum)
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
          onSkipAll: () => _goto(4),
        ),
      3 => RegionScreen(
          key: const ValueKey<String>('launch-step-3'),
          selectedIndex: _regionIndex,
          onSelect: (int i) => setState(() => _regionIndex = i),
          onOpenMap: () => _goto(4), // "Haritayı aç" → önce konum ön-izni
          onSkipAll: () => _goto(4),
        ),
      _ => LocationPrimerScreen(
          key: const ValueKey<String>('launch-step-4'),
          onUseLocation: _useLocation,
          onContinueWithout: () => _complete(applyRegion: true),
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
