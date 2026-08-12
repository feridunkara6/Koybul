import 'package:dockly_api/dockly_api.dart' show GeoPoint, LocationSummary;
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

/// AÇILIŞ KAPISI — Faz 1'de KISALTILDI (5 ekran → 3).
///
/// Eski akış: karşılama → tekne tipi → ölçüler → bölge → konum ön-izni.
/// Beş tam ekran, arkasından da 10 kartlık tanıtım turu; kullanıcı haritayı
/// görmeden önce iki dakikalık bir tören yaşıyordu. Denetimin bulgusu net:
/// en yüksek kayıp ilk iki dakikada.
///
/// Yeni akış: **karşılama → ölçüler → konum ön-izni → harita.**
/// - TEKNE TİPİ kaldırıldı: cevabı hiçbir yerde okunmuyordu (launch_answers).
/// - BÖLGE artık koşullu: konum izni verildiyse zaten gereksizdi (eski kodda
///   da veriliyorsa cevap ÇÖPE ATILIYORDU). Yalnız izin gelmediğinde sorulur,
///   çünkü orada gerçekten işe yarar: haritanın nereyi göstereceğini o belirler.
///
/// İzin veren kullanıcı 2 soru görür; vermeyen 3. Kurallar aynı kaldı:
/// - "Soruları atla" kalan soruları atlar; o ana dek verilen cevaplar YİNE
///   uygulanır (atlayan cezalandırılmaz).
/// - Adım cihaza işlenir (`onb.v2.step`): yarım kalan akış kaldığı yerden sürer.
/// - Tekne cevapları MEVCUT "Teknem" modeline yazılır (tek gerçek kaynak).
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

  /// 0 karşılama · 1 ölçüler · 2 konum ön-izni · 3 bölge (yalnız izin yoksa).
  int _step = 0;

  // Akış içinde toplanan cevaplar (hepsi isteğe bağlı).
  double? _lengthM;
  double? _draftM;
  int? _regionIndex;
  String? _boatName;
  LocationSummary? _marina;

  /// Kullanıcı "Soruları atla" dedi mi? Niyet TAŞINIR: bölge de bir sorudur,
  /// atlamak isteyene sonradan yeniden sorulmaz (inceleme bulgusu).
  bool _skippedAll = false;

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
        // 0..4. Eski numaralar hiç görünmez: depolama anahtarı Faz 1'de
        // sürümlendi (bkz. SharedPrefsLaunchStore). Kırpma yine de durur —
        // bozuk/ileri bir değer kullanıcıyı boş ekrana düşürmesin.
        //
        // 4 gerçek bir ekran DEĞİL, "konum ön-izni + kullanıcı soruları
        // atlamıştı" durumudur; niyetin uygulama kapansa bile yaşaması için
        // cihaza böyle yazılır (inceleme bulgusu).
        step = done ? 0 : (both[1] as int).clamp(0, 4);
      } catch (_) {
        done = true;
        step = 0;
      }
      // DÖNEN KULLANICI + BAĞLI MARİNA (kullanıcı isteği 2026-08): tekne
      // kaydında marina varsa harita her açılışta o çevrede açılır. Soğuk
      // açılışta GPS henüz yoktur (izin düğmeye bağlı); kullanıcı "Konumum"a
      // basınca odak zaten konuma taşınır. Tekne kaydının cihazdan yüklenmesi
      // BEKLENİR — beklenmezse odak, boş tekneye bakıp hiç kurulmazdı.
      if (done) {
        try {
          await ref.read(myBoatProvider.notifier).ensureRestored();
          final HomeMarina? hm = ref.read(myBoatProvider)?.homeMarina;
          if (hm != null &&
              ref.read(devicePositionProvider) == null &&
              ref.read(mapFocusProvider) == null) {
            ref.read(mapFocusProvider.notifier).state = MapFocusRequest(
              point: GeoPoint(lat: hm.lat, lon: hm.lon),
              seq: 1,
              zoom: kHomeMarinaFocusZoom,
            );
          }
        } catch (_) {/* en iyi çaba — odak süslemedir, kapıyı geciktirmez */}
      }
      if (!mounted) return;
      setState(() {
        _done = done;
        // 4 = "konum ön-izni, sorular atlanmış" → ekran 2, niyet geri yüklenir.
        _skippedAll = step == 4;
        _step = step == 4 ? 2 : step;
      });
      // AÇILIŞ EKRANINA HABER VER: gösterilecek doğru ekran artık belli.
      // Bundan sonra beklemenin karşılığı yok — marka yüzeyi çekilebilir.
      // (Kapı ağaçtan kalktıysa `ref` kullanılamaz; o durumda açılış kendi
      // tavan süresiyle zaten kapanır.)
      ref.read(appReadyProvider.notifier).state = true;
    });
  }

  /// [persistAs] verilirse cihaza YAZILAN değer ekrandan farklı olur; tek
  /// kullanımı "atlandı" niyetini de taşıyan 4 kodudur.
  void _goto(int step, {int? persistAs}) {
    ref.read(launchStoreProvider).setStep(persistAs ?? step); // en iyi çaba
    setState(() => _step = step);
  }

  /// E6: "Konumumu kullan" — tarayıcı izin penceresi BURADA açılır (locateMe).
  ///
  /// İzin GELİRSE akış biter: kamera konuma iner, bölge sorusu hiç sorulmaz —
  /// konum varken bölge cevabı zaten kullanılmıyordu.
  /// İzin GELMEZSE bölge sorusuna geçilir; harita bir yeri göstermek zorunda
  /// ve o yeri artık ancak kullanıcı söyleyebilir. Suçlama yok, hiçbir özellik
  /// kilitlenmez (onaylı E6 kuralı).
  Future<void> _useLocation() async {
    await ref.read(locationControllerProvider.notifier).locateMe();
    if (!mounted) return;
    if (ref.read(devicePositionProvider) != null) {
      _complete();
    } else {
      _afterPrimerWithoutLocation();
    }
  }

  /// Konum yok. Bölge sorulur — AMA:
  /// - kullanıcı "soruları atla" dediyse sorulmaz (söz sözdür);
  /// - BAĞLI MARİNA seçildiyse de sorulmaz (kullanıcı isteği 2026-08):
  ///   bölge sorusunun tek işi haritanın açılış odağıydı; marina o cevabı
  ///   zaten daha isabetli veriyor. Bir soru eksik = daha hızlı giriş.
  void _afterPrimerWithoutLocation() {
    if (_skippedAll || _marina != null) {
      _complete();
    } else {
      _goto(3);
    }
  }

  /// Akışı bitirir: karar cihaza, cevaplar sistemlere.
  /// [applyRegion] yalnız bölge ekranından çıkarken true olur; "seçilmemiş
  /// bölge" uydurulamaz — kullanıcı çip seçmediyse odak yine uygulanmaz.
  void _complete({bool applyRegion = false}) {
    ref.read(launchStoreProvider).markDone();
    // Tekne: boy verilmişse MEVCUT modele yazılır (marka VE tip korunur —
    // tek gerçek kaynak Profil → Teknem ile aynı depo; akış tip sormuyor
    // ama daha önce girilmiş bir tipi de silmiyor). Ad ve bağlı marina da
    // buradan akar (kullanıcı isteği 2026-08); boş bırakıldıysa eski değer
    // korunur — akışı yarım dolduran, önceki kaydını silmez.
    final double? len = _lengthM;
    if (len != null) {
      final MyBoat? current = ref.read(myBoatProvider);
      final LocationSummary? m = _marina;
      ref.read(myBoatProvider.notifier).set(MyBoat(
            lengthM: len,
            draftM: _draftM,
            brand: current?.brand,
            typeId: current?.typeId,
            name: _boatName ?? current?.name,
            homeMarina: m != null
                ? HomeMarina(
                    id: m.id,
                    name: m.name,
                    lat: m.position.lat,
                    lon: m.position.lon,
                  )
                : current?.homeMarina,
          ));
    }
    // Açılış odağı (yüzey onMapReady'de uygular). Öncelik: GPS varsa hiçbiri
    // (locateMe odağı zaten konuma verdi) → bölge (bölge ekranından çıkış)
    // → bağlı marina (kullanıcı isteği 2026-08: "marina çevresine odaklan").
    final int? region = applyRegion ? _regionIndex : null;
    final LocationSummary? marina = _marina;
    if (region != null) {
      final LaunchRegion r = kLaunchRegions[region];
      final MapFocusRequest? prev = ref.read(mapFocusProvider);
      ref.read(mapFocusProvider.notifier).state = MapFocusRequest(
        point: GeoPoint(lat: r.lat, lon: r.lon),
        seq: (prev?.seq ?? 0) + 1,
        zoom: kRegionFocusZoom,
      );
    } else if (marina != null && ref.read(devicePositionProvider) == null) {
      final MapFocusRequest? prev = ref.read(mapFocusProvider);
      ref.read(mapFocusProvider.notifier).state = MapFocusRequest(
        point: GeoPoint(lat: marina.position.lat, lon: marina.position.lon),
        seq: (prev?.seq ?? 0) + 1,
        zoom: kHomeMarinaFocusZoom,
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
      1 => BoatSizeScreen(
          key: const ValueKey<String>('launch-step-1'),
          initialLengthM: _lengthM ?? kDefaultLengthM,
          initialDraftM: _draftM ?? kDefaultDraftM,
          initialName: _boatName,
          initialMarina: _marina,
          onContinue: (double lengthM, double draftM, String? boatName,
              LocationSummary? marina) {
            _lengthM = lengthM;
            _draftM = draftM;
            _boatName = boatName;
            _marina = marina;
            _goto(2);
          },
          // Atla → konum ön-izni. Konum bir SORU değil, izin; atlanmaz.
          // Cihaza 4 yazılır: "primer + atlandı" (bkz. yükleme kodu).
          onSkipAll: () {
            _skippedAll = true;
            _goto(2, persistAs: 4);
          },
        ),
      2 => LocationPrimerScreen(
          key: const ValueKey<String>('launch-step-2'),
          onUseLocation: _useLocation,
          // "Şimdilik bölgemle devam" → bölgeyi SORMAK gerekir; harita bir
          // yeri göstermeli ve konum yokken onu ancak kullanıcı bilir.
          onContinueWithout: _afterPrimerWithoutLocation,
        ),
      _ => RegionScreen(
          key: const ValueKey<String>('launch-step-3'),
          selectedIndex: _regionIndex,
          onSelect: (int i) => setState(() => _regionIndex = i),
          onOpenMap: () => _complete(applyRegion: true),
          onSkipAll: () => _complete(applyRegion: true),
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
