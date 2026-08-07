import 'dart:async' show unawaited;

import 'package:dockly_api/dockly_api.dart' show GeoPoint, LocationPin;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../map/application/map_controller.dart';
import '../../map/domain/map_state.dart';
import '../../map/domain/map_viewport.dart';
import '../../route/domain/sea_trip.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../application/onboarding_controller.dart';
import 'tour_targets.dart';

/// Karartma rengi — marka lacivertinin koyusu.
const Color _dimColor = Color(0xC7071626);

/// TANITIM TURU v4 — PREMIUM (kullanıcı isteği 2026-08): kaba çizgi-ok
/// yerine, kaliteli uygulama tanıtımlarındaki dil kullanılır —
///  • anlatılan bölge YUMUŞAK IŞIMALI vurgu halkasıyla aydınlık kalır ve
///    yerine "oturma" animasyonuyla gelir;
///  • kart, hedefe KONUŞMA BALONU UCUYLA bağlanır (havada uçan ok yok);
///  • kartta adım sayacı (3/10), akıcı geçiş animasyonu ve İleri/Başla
///    düğmesi vardır; ekranın herhangi bir yerine dokunmak da ilerletir;
///  • tur gerekirse SAYFA DEĞİŞTİRİR (Defter, Teknem) ve son kart
///    "Hazırsın" deyip Keşfet'e döner.
/// Hedef ölçülemezse kart ortada, vurgusuz gösterilir — tur asla kırılmaz.
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({required this.step, super.key});

  final int step;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

/// Adımın canlı örneği (örnekli tur v5, kullanıcı isteği 2026-08).
enum _TourDemo { none, pin, route }

/// Pencere vurguları: hedef bir widget değil HARİTANIN KENDİSİYKEN karartma
/// bu bölgeyi loş ışıkla aydınlık bırakır (kenarlar yumuşak — sert çerçeve
/// yok; kullanıcı isteği 2026-08).
///
/// İşaret adımı YAKIN PLANDIR: kamera işaretin üstüne uçar (işaret harita
/// gövdesinin merkezine gelir), loş ışık DAİRESİ tam onu aydınlatır.
Rect _pinWindow(Size s) {
  // Harita gövdesi = ekran - alt menü (64); işaret odak uçuşuyla merkezde.
  final Offset c = Offset(s.width / 2, (s.height - 64) / 2);
  return Rect.fromCircle(center: c, radius: 92);
}

// Rota adımlarında ŞEKİL YOK (kullanıcı isteği 2026-08: "dikdörtgen
// istemiyorum"): karartma kenarlardan koyulaşan doğal bir IŞIK HAVUZU olur
// (vinyet) — rota ve harita, ortadaki aydınlıkta serbestçe görünür.

/// Adım tanımı: sekme + (varsa) vurgulanacak hedef/pencere + canlı örnek.
class _TourStepDef {
  const _TourStepDef({
    required this.icon,
    this.tab = 0,
    this.target,
    this.window,
    this.circleSpot = false,
    this.vignette = false,
    this.demo = _TourDemo.none,
  });

  final DocklyIconData icon;
  final int tab;
  final GlobalKey? target;

  /// Hedef yoksa aydınlık bırakılacak ekran penceresi (harita örnekleri).
  final Rect Function(Size screen)? window;

  /// true → pencere DAİRE olarak aydınlatılır (yakın plan işaret adımı).
  final bool circleSpot;

  /// true → hedef ölçülemezse şekilsiz IŞIK HAVUZU (vinyet) kullanılır;
  /// kart ekranın altına iner (harita ortası serbest kalır).
  final bool vignette;

  final _TourDemo demo;
}

/// v5 adımları — sırası l10n `tourTitles`/`tourBodies` ile birebir aynıdır.
/// Örnekli adımlar CANLI içerik gösterir: işaret seçimi, gerçek motorla
/// çizilen örnek rota, Defter'de örnek rota kartı, Teknem'de kimlik kartı.
final List<_TourStepDef> _tourSteps = <_TourStepDef>[
  const _TourStepDef(icon: DocklyIcons.sailing), // ① hoş geldin
  const _TourStepDef( // ② harita ve koylar — işarete YAKIN PLAN (daire)
      icon: DocklyIcons.place,
      window: _pinWindow,
      circleSpot: true,
      demo: _TourDemo.pin),
  _TourStepDef(icon: DocklyIcons.checkCircle, target: tourKeyChips), // ③
  _TourStepDef(icon: DocklyIcons.explore, target: tourKeyLocate), // ④
  _TourStepDef(icon: DocklyIcons.errorOutline, target: tourKeySos), // ⑤
  const _TourStepDef( // ⑥ deniz rotası — ışık havuzunda canlı çizilir
      icon: DocklyIcons.navigation,
      vignette: true,
      demo: _TourDemo.route),
  _TourStepDef( // ⑦ rota düzenle & kaydet — örnek rotanın bilgi kartı
      icon: DocklyIcons.edit,
      target: tourKeyRouteChip,
      vignette: true,
      demo: _TourDemo.route),
  _TourStepDef( // ⑧ Defter — örnek rota kartı (ekranın kendisi gösterir)
      icon: DocklyIcons.edit, tab: 2, target: tourKeySavedDemo),
  _TourStepDef( // ⑨ Teknem — tekne kimlik kartı vurgulanır
      icon: DocklyIcons.sailing, tab: 3, target: tourKeyBoatCard),
  const _TourStepDef(icon: DocklyIcons.sailing), // ⑩ hazırsın (Keşfet'te)
];

class _TourOverlayState extends ConsumerState<TourOverlay> {
  /// Ölçülen hedef dikdörtgeni (ekran koordinatı) — null ise kart ortada.
  Rect? _targetRect;

  /// Örnek rotayı BİZ çizdiysek true — kullanıcının kendi rotasına asla
  /// dokunulmaz (rotası varsa örnek hiç başlamaz, temizlik de yapılmaz).
  bool _demoRoute = false;

  /// Örnek olarak seçtiğimiz işaretin kimliği (temizlikte geri alınır).
  String? _demoPinId;

  /// Örnekler kamerayı gezdirdiyse true — tur biterken/atlanırken harita
  /// AÇILIŞ görünümüne döndürülür (kullanıcı isteği 2026-08: "Türkiye
  /// haritasının ortasında bırakmasın").
  bool _cameraTouched = false;

  /// Tur başlarken bakılan yer — kapanışta buraya dönülür (GPS varsa gerçek
  /// konum, yoksa haritanın o anki merkezi; ikisi de yoksa Göcek sahili).
  /// İLK AÇILIŞTA harita merkezi tur başladıktan BİR KARE SONRA oluşur —
  /// bu yüzden değer, kamera ilk kez oynatılana dek her adımda tazelenir.
  GeoPoint? _startCenter;

  /// Kapanış yakınlaştırması: GPS'li kullanıcı ~konum ölçeğinde (12),
  /// bölge seçen kullanıcı körfez ölçeğinde (9) başladı — aynı ölçeğe dönülür.
  double _startZoom = 9;

  @override
  void initState() {
    super.initState();
    _captureStart();
    // Hedef bir önceki karede zaten yerleşmiş — HEMEN ölçmek ilk kareyi de
    // doğru çizer (ortada kart + sıçrama yok). Sekme işi çerçeve sonrasına.
    _targetRect = _measure(_def);
    _sync();
  }

  void _captureStart() {
    final GeoPoint? gps = ref.read(devicePositionProvider);
    final GeoPoint? c = gps ?? ref.read(originProvider);
    if (c != null) {
      _startCenter = c;
      _startZoom = gps != null ? 12 : 9;
    }
  }

  @override
  void didUpdateWidget(TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      // SENKRON ÖLÇÜM (inceleme dersi 2026-08): ölçümü çerçeve sonrasına
      // bırakmak, vurgulu adımlarda 1 karelik "ortada kart" titremesi yapardı.
      _targetRect = _measure(_def);
      _sync();
    }
  }

  _TourStepDef get _def =>
      _tourSteps[widget.step.clamp(0, _tourSteps.length - 1)];

  /// Hedefin ekran dikdörtgeni — ölçülemiyorsa null (kart ortada gösterilir).
  Rect? _measure(_TourStepDef d) {
    final RenderObject? ro = d.target?.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      return ro.localToGlobal(Offset.zero) & ro.size;
    }
    return null;
  }

  /// Adım kurulumu (çerçeve SONRASI — yerleşim bitmişken): gerekiyorsa sekme
  /// değiştirilir (tanıtım o sayfada açılır), sonra hedef ölçümü doğrulanır.
  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final _TourStepDef d = _def; // dokunuşlar hızlıysa GÜNCEL adım esastır
      if (ref.read(shellTabProvider) != d.tab) {
        ref.read(shellTabProvider.notifier).state = d.tab;
        // Hedefli adım sekme de değiştiriyorsa ölçüm YENİ sekme yerleştikten
        // sonra yapılmalı — bir sonraki çerçeveye ertelenir (Defter ve
        // Teknem adımları böyledir: sekme + hedef birlikte gelir).
        if (d.target != null) {
          _sync();
          return;
        }
      }
      // Açılış merkezi, kamera İLK oynatılana dek tazelenir (ilk açılışta
      // harita merkezi turdan bir kare sonra oluşur — inceleme dersi).
      if (!_cameraTouched) _captureStart();
      _applyDemos(d);
      // KAPANIŞ GÖRÜNÜMÜ (kullanıcı isteği 2026-08): örnekler kamerayı
      // gezdirdiyse son adımda AÇILIŞTAKİ görünüme dönülür — kullanıcı
      // turu nerede başlattıysa haritayı orada bulur.
      if (widget.step >= kTourStepCount - 1 && _cameraTouched) {
        _cameraTouched = false;
        _goHome();
      }
      final Rect? r = _measure(d);
      if (r != _targetRect) setState(() => _targetRect = r);
    });
  }

  /// Turdan çıkış görünümü: açılıştaki merkeze, açılış ölçeğinde
  /// (_startZoom: GPS'li kullanıcıda 12, bölge seçende 9). Başlangıç merkezi
  /// bilinmiyorsa Göcek sahili (deterministik, asla kara ortası değil).
  void _goHome() {
    final GeoPoint? home = _startCenter;
    if (home != null) {
      _focus(home, zoom: _startZoom);
    } else {
      _focus(kTourDemoOrigin, zoom: 11);
    }
  }

  /// Kamerayı bir noktaya uçurur ("Konumum" ile aynı mekanizma).
  void _focus(GeoPoint p, {double? zoom}) {
    final int nextSeq = (ref.read(mapFocusProvider)?.seq ?? 0) + 1;
    ref.read(mapFocusProvider.notifier).state =
        MapFocusRequest(point: p, seq: nextSeq, zoom: zoom);
  }

  /// CANLI ÖRNEKLER (kullanıcı isteği 2026-08): adım ne anlatıyorsa onu
  /// gerçekten YAPAR — çerçeve sonrası güvenli evrede çalışır; adım
  /// değişince örnekler geri alınır (kalıcı hiçbir şey yazılmaz).
  void _applyDemos(_TourStepDef d) {
    final MapController map = ref.read(mapControllerProvider.notifier);
    final MapState ms = ref.read(mapControllerProvider);
    // ÖRNEK ROTA: gerçek motorla, maskeye karşı doğrulanmış iki su noktası
    // arasında çizilir (kamera rotaya kendiliğinden uçar).
    if (d.demo == _TourDemo.route) {
      if (!_demoRoute && ms.route == null && !ms.isRouting) {
        _demoRoute = true;
        _cameraTouched = true; // rota-sığdırma uçuşu kamerayı taşır
        final L10n t = ref.read(l10nProvider);
        unawaited(map.openSavedRoute(
          // "Göcek" özel addır — çevrilmez (koy isimleri kuralı).
          const RouteOrigin(pos: kTourDemoOrigin, name: 'Göcek'),
          <RouteWaypoint>[
            RouteWaypoint(pos: kTourDemoDest, name: t.tourDemoStop),
          ],
          name: t.tourDemoRouteName,
        ));
      }
    } else {
      _clearDemoRoute();
    }
    // ÖRNEK İŞARET: koylar yüklüyse biri seçilir — işaret büyür, kullanıcı
    // bağlama noktası imlecinin SEÇİLİ halini gerçek örnek üstünde görür.
    if (d.demo == _TourDemo.pin) {
      if (_demoPinId == null &&
          ms.selectedPinId == null &&
          ms.pins.isNotEmpty) {
        // KIRMIZI İMLEÇ TERCİHİ (kullanıcı isteği 2026-08): klasik kırmızı
        // bağlama işareti varsa örnek odur; yoksa ilk işaret.
        final LocationPin demoPin = ms.pins.firstWhere(
          (LocationPin p) => p.type == 'mooring_point',
          orElse: () => ms.pins.first,
        );
        _demoPinId = demoPin.id;
        map.selectPin(_demoPinId!);
        // YAKIN PLAN (kullanıcı isteği 2026-08): kamera işaretin üstüne
        // uçar — imleç genel görünümde değil, yakından tanıtılır.
        _cameraTouched = true;
        _focus(demoPin.position, zoom: 15);
      }
    } else {
      _clearDemoPin();
    }
  }

  void _clearDemoRoute() {
    if (!_demoRoute) return;
    _demoRoute = false;
    ref.read(mapControllerProvider.notifier).clearRoute();
  }

  void _clearDemoPin() {
    final String? id = _demoPinId;
    if (id == null) return;
    _demoPinId = null;
    if (ref.read(mapControllerProvider).selectedPinId == id) {
      ref.read(mapControllerProvider.notifier).clearSelection();
    }
  }

  void _next() =>
      ref.read(onboardingControllerProvider.notifier).nextStep();

  /// "Atla" — tur kapanır; örnekler temizlenir, Keşfet'e dönülür ve harita
  /// (kamera gezdirildiyse) sahil görünümünde bırakılır.
  void _skip() {
    _clearDemoRoute();
    _clearDemoPin();
    if (_cameraTouched) {
      _cameraTouched = false;
      _goHome();
    }
    ref.read(shellTabProvider.notifier).state = 0;
    ref.read(onboardingControllerProvider.notifier).skipTour();
  }

  /// Adımlar arası akıcı geçiş: içerik yumuşakça kayarak belirir.
  Widget _stepSwitcher(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget c, Animation<double> a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(a),
          child: c,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<int>(widget.step), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(_tourSteps.length == kTourStepCount,
        'adım tanımları l10n listeleriyle aynı boyda olmalı');
    // Adım dizinleri sabitlerle SENKRON kalsın (ekranlar bu sabitleri okur).
    assert(_tourSteps[kTourStepMarkers].demo == _TourDemo.pin);
    assert(_tourSteps[kTourStepRoute].demo == _TourDemo.route);
    assert(_tourSteps[kTourStepRouteEdit].demo == _TourDemo.route);
    assert(_tourSteps[kTourStepSaved].tab == 2);
    assert(_tourSteps[kTourStepBoat].tab == 3);
    final L10n t = ref.watch(l10nProvider);
    final int s = widget.step.clamp(0, kTourStepCount - 1);
    final bool last = s == kTourStepCount - 1;
    final String title = s < t.tourTitles.length ? t.tourTitles[s] : '';
    final String body = s < t.tourBodies.length ? t.tourBodies[s] : '';
    final Size screen = MediaQuery.sizeOf(context);
    // CANLI ÖRNEK tetikleyicileri: koylar sonradan yüklenirse işaret seçilir;
    // örnek rota çizilince çip ölçülür — DÖNGÜSÜZ (yalnız değişimde uyanır).
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.pins.length),
      (int? prev, int next) => _sync(),
    );
    ref.listen<bool>(
      mapControllerProvider.select((MapState s) => s.route != null),
      (bool? prev, bool next) => _sync(),
    );
    // Hedef ölçülemediyse pencere vurgusu kullanılır (harita örnekleri).
    // Çentikli/jest çubuklu cihazlarda alt menü güvenli alan kadar büyür —
    // yakın-plan dairesi harita gövdesinin GERÇEK merkezine kaydırılır.
    // (spot FINAL kalır: closure içindeki null-yükseltme bozulmasın.)
    final Rect? rawSpot = _targetRect ?? _def.window?.call(screen);
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final Rect? spot = (rawSpot != null &&
            _targetRect == null &&
            _def.circleSpot &&
            bottomInset > 0)
        ? rawSpot.translate(0, -bottomInset / 2)
        : rawSpot;
    // IŞIK HAVUZU adımı: şekil çizilmez; kart ekranın altına iner.
    final bool pool = spot == null && _def.vignette;
    // Kart, hedefin BOŞ kalan yarısına konur; balon ucu hedefi işaret eder.
    final bool cardBelow = spot != null && spot.center.dy < screen.height / 2;
    // Kart genişliği/konumu — balon ucunun yatay hizası hedefe göre hesaplanır.
    final double cardW =
        (screen.width - 32) < 420 ? (screen.width - 32) : 420.0;
    // Kart hedefe YATAYDA da yaklaşır (tablet/geniş ekran cilası): balon ucu
    // hedefin tam altına/üstüne oturur; kart ekran kenarından taşmaz.
    final double cardLeft = spot == null
        ? (screen.width - cardW) / 2
        : (spot.center.dx - cardW / 2)
            .clamp(16.0, screen.width - 16.0 - cardW);
    final double tailLeft = spot == null
        ? 0
        : (spot.center.dx - cardLeft - 11).clamp(20.0, cardW - 42.0);
    final Widget card = _TourCard(
      step: s,
      last: last,
      title: title,
      body: body,
      icon: _def.icon,
      t: t,
      onNext: _next,
    );
    return GestureDetector(
      key: ValueKey<String>('onb-tour-step-$s'),
      behavior: HitTestBehavior.opaque,
      // EKRANA DOKUN → SONRAKİ ADIM (İleri düğmesi de aynı işi yapar).
      // Alttaki ekran bu sırada dokunuş almaz (karartma alt menüyü de kapsar).
      onTap: _next,
      child: Stack(
        children: <Widget>[
          // Karartma: hedef varsa yumuşak ışımalı VURGU (yerine oturma
          // animasyonuyla); rota adımında şekilsiz IŞIK HAVUZU (vinyet);
          // diğer durumlarda düz karartma.
          Positioned.fill(
            child: pool
                ? TweenAnimationBuilder<double>(
                    key: ValueKey<String>('pool-anim-$s'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double v, Widget? _) =>
                        CustomPaint(
                      key: const ValueKey<String>('onb-tour-spot'),
                      painter: _LightPoolPainter(
                        center: Offset(
                          screen.width / 2,
                          (screen.height - 64 - bottomInset) * 0.40,
                        ),
                        t: v,
                      ),
                    ),
                  )
                : spot == null
                ? const ColoredBox(color: _dimColor)
                : TweenAnimationBuilder<double>(
                    key: ValueKey<String>('spot-anim-$s'),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double v, Widget? _) =>
                        CustomPaint(
                      key: const ValueKey<String>('onb-tour-spot'),
                      painter: _SpotDimPainter(
                        hole: spot.inflate(9),
                        t: v,
                        circle: _targetRect == null && _def.circleSpot,
                      ),
                    ),
                  ),
          ),
          // ATLA — buzlu cam hap (premium dil); her an çıkış.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _skip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Text(
                        t.onbSkip,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (pool)
            // Işık havuzu: kart ALTTA durur — rota/harita yukarıda,
            // aydınlıkta serbestçe izlenir.
            Positioned(
              left: 16,
              right: 16,
              bottom: 80 + bottomInset,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardW),
                  child: _stepSwitcher(card),
                ),
              ),
            )
          else if (spot == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardW),
                  child: _stepSwitcher(card),
                ),
              ),
            )
          else
            // Kart + balon ucu: hedefin hemen yanında, ona bağlı görünür.
            Positioned(
              left: cardLeft,
              width: cardW,
              top: cardBelow ? spot.bottom + 18 : null,
              bottom: cardBelow ? null : screen.height - spot.top + 18,
              child: _stepSwitcher(
                // KISA EKRAN EMNİYETİ (inceleme dersi 2026-08): kart ekranın
                // altına sığmazsa içerik kaydırılabilir kalır — İleri düğmesi
                // asla ekran dışında kaybolmaz.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (cardBelow
                            ? screen.height - spot.bottom - 30
                            : spot.top - 30)
                        .clamp(180.0, screen.height),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (cardBelow)
                          Padding(
                            padding: EdgeInsets.only(left: tailLeft),
                            child: const _CardTail(pointsUp: true),
                          ),
                        card,
                        if (!cardBelow)
                          Padding(
                            padding: EdgeInsets.only(left: tailLeft),
                            child: const _CardTail(pointsUp: false),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tur kartı (premium): ikon + başlık + adım sayacı hapı + gövde +
/// animasyonlu ilerleme noktaları + İleri/Başla düğmesi.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.last,
    required this.title,
    required this.body,
    required this.icon,
    required this.t,
    required this.onNext,
  });

  final int step;
  final bool last;
  final String title;
  final String body;
  final DocklyIconData icon;
  final L10n t;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 16,
      shadowColor: const Color(0x59071626),
      borderRadius: BorderRadius.circular(22),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF0E3052),
                        DocklyColors.brandDeep,
                      ],
                    ),
                  ),
                  child: Center(
                    child: DocklyIcon(
                      icon,
                      size: 20,
                      color: const Color(0xFF7FE3D9),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                ),
                const SizedBox(width: 8),
                // ADIM SAYACI (3/10): kullanıcı turda nerede, bilir.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${step + 1}/$kTourStepCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: DocklyColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                for (int i = 0; i < kTourStepCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: i == step ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == step
                          ? DocklyColors.brandPrimary
                          : theme.dividerColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(last ? t.tourStartBtn : t.onbNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta bağlı balon ucu: hedefe bakan yumuşak (ucu kavisli) üçgen —
/// kart hedefe "bağlı" görünür; havada uçan ok yoktur.
class _CardTail extends StatelessWidget {
  const _CardTail({required this.pointsUp});

  /// true → uç yukarıyı (üstteki hedefi) gösterir; false → aşağıyı.
  final bool pointsUp;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 10),
      painter: _CardTailPainter(
        pointsUp: pointsUp,
        color: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

class _CardTailPainter extends CustomPainter {
  const _CardTailPainter({required this.pointsUp, required this.color});

  final bool pointsUp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double base = pointsUp ? size.height : 0;
    final double tip = pointsUp ? 0 : size.height;
    final double bulge = pointsUp ? 2.0 : -2.0;
    final Path p = Path()
      ..moveTo(0, base)
      ..lineTo(size.width * 0.5 - 3, tip + bulge)
      ..quadraticBezierTo(
          size.width * 0.5, tip - bulge * 0.5, size.width * 0.5 + 3, tip + bulge)
      ..lineTo(size.width, base)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CardTailPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp || oldDelegate.color != color;
}

/// Delikli karartma + LOŞ IŞIK (kullanıcı isteği 2026-08): ekran kararır,
/// anlatılan bölge yumuşak bir ışıkla aydınlık kalır. Sert çizgi/çerçeve
/// YOKTUR — kenar, karanlığa bulanık bir ışık halesiyle erir (fener ışığı
/// hissi). [t] 0→1 yerleşme animasyonudur: delik hafif geniş başlar,
/// yerine oturur; ışık belirir. [circle] yakın-plan işaret adımında delik
/// tam DAİRE olur.
class _SpotDimPainter extends CustomPainter {
  const _SpotDimPainter({
    required this.hole,
    required this.t,
    this.circle = false,
  });

  final Rect hole;
  final double t;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect h = hole.inflate((1 - t) * 10);
    // DİKDÖRTGEN YOK (kullanıcı isteği 2026-08): delik her zaman TAM
    // yuvarlak uçludur — küçük hedefte daire/hap, büyük hedefte yumuşak
    // kapsül. Köşe hissi veren hiçbir şekil çizilmez.
    final Radius rad = circle
        ? Radius.circular(h.shortestSide / 2)
        : Radius.circular(
            h.shortestSide / 2 < 34 ? h.shortestSide / 2 : 34,
          );
    final RRect r = RRect.fromRectAndRadius(h, rad);
    final Path dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(r),
    );
    canvas.drawPath(dim, Paint()..color = _dimColor);
    // İÇ IŞIK BANYOSU: deliğin içi hafif beyaz ışıkla YIKANIR — bölge
    // "karanlık değil" değil, gerçekten AYDINLATILMIŞ görünür.
    canvas.drawRRect(
      r,
      Paint()
        ..shader = RadialGradient(
          // Geniş kapsüllerde (çip şeridi) ışık TÜM deliği yıkasın diye
          // yarıçap en-boy oranıyla ölçeklenir (çizim delik şekliyle kırpılır).
          radius: (h.longestSide / h.shortestSide) * 0.5,
          colors: <Color>[
            const Color(0xFFFFFFFF).withValues(alpha: 0.14 * t),
            const Color(0xFFFFFFFF).withValues(alpha: 0.0),
          ],
        ).createShader(h),
    );
    // Kenar: karanlığa eriyen yumuşak ışık halesi (bulanık fırça) + çok
    // hafif bir iç parlaklık. Keskin çizgi bilinçli olarak yok.
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..color = const Color(0xFFCFF6EF).withValues(alpha: 0.22 * t),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.26 * t),
    );
  }

  @override
  bool shouldRepaint(_SpotDimPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.t != t ||
      oldDelegate.circle != circle;
}

/// IŞIK HAVUZU (rota adımları, kullanıcı isteği 2026-08): hiçbir şekil
/// çizilmez — ekran kenarlardan koyulaşır, ortada fener ışığı gibi doğal
/// bir aydınlık kalır. Rota ve harita bu havuzun içinde serbestçe görünür.
class _LightPoolPainter extends CustomPainter {
  const _LightPoolPainter({required this.center, required this.t});

  /// Havuzun merkezi (harita gövdesinin üst-orta bölgesi).
  final Offset center;

  /// 0→1 belirme animasyonu.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius =
        (size.width > size.height ? size.width : size.height) * 0.72;
    final Rect full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (center.dx / size.width) * 2 - 1,
            (center.dy / size.height) * 2 - 1,
          ),
          // Flutter kuralı: radius birimi = KISA KENARIN TAMAMI (yarısı
          // değil) — /2 kullanmak havuzu iki kat büyütüp vinyeti siler.
          radius: radius / size.shortestSide,
          colors: <Color>[
            _dimColor.withValues(alpha: 0.10 * t),
            _dimColor.withValues(alpha: 0.42 * t),
            _dimColor.withValues(alpha: 0.80 * t),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(full),
    );
  }

  @override
  bool shouldRepaint(_LightPoolPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.t != t;
}

/// İLK-DOKUNUŞ İPUCU BALONU: özellik ilk kez kullanılırken tek seferlik küçük
/// açıklama; "Anladım" ile kapanır ve cihazda işlenir (bir daha görünmez).
class OnboardingHintBubble extends ConsumerWidget {
  const OnboardingHintBubble({
    required this.hintKey,
    required this.title,
    required this.body,
    super.key,
  });

  final String hintKey;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Material(
      key: ValueKey<String>('onb-hint-$hintKey'),
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: DocklyIcon(DocklyIcons.infoOutline,
                        size: 14, color: DocklyColors.brandPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref
                    .read(onboardingControllerProvider.notifier)
                    .markHintSeen(hintKey),
                child: Text(t.onbGotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
