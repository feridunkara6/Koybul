import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart';
import '../../deck/application/trip_log_controller.dart';
import '../../deck/domain/sea_trip_log.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../../emergency/presentation/emergency_screen.dart';
import '../../location/presentation/locate_button.dart';
import '../../nearby/presentation/nearby_sheet.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/presentation/onboarding_overlay.dart';
import '../../onboarding/presentation/tour_targets.dart';
import '../../route/application/saved_routes_controller.dart';
import '../../route/domain/route_wind.dart';
import '../../route/domain/saved_route.dart';
import '../../route/domain/sea_route.dart';
import '../../route/domain/sea_router.dart';
import '../../route/domain/sea_trip.dart';
import '../../search/presentation/search_screen.dart';
import '../../shell/application/shell_tab_provider.dart';
import '../../checklist/application/checklist_controller.dart';
import '../../checklist/presentation/checklist_sheet.dart';
import '../../logbook/domain/log_entry.dart';
import '../../logbook/presentation/logbook_screen.dart' show showLogEntryEditor;
import '../application/map_controller.dart';
import '../domain/map_state.dart';
import 'location_bottom_card.dart';
import 'map_surface.dart';
import 'route_origin_menu.dart';

/// Harita ekranı (S-06). Somut harita yüzeyi üstüne durum katmanları:
/// yükleme, boş, hata+retry, "çok fazla sonuç" ipucu (docs/26 §4, docs/23 §9.5).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapState state = ref.watch(mapControllerProvider);
    final MapController controller = ref.read(mapControllerProvider.notifier);
    // KARA YASAĞI uyarısı: rota hesaplanamadıysa (düz çizgi çizilmez) kullanıcı
    // dürüstçe bilgilendirilir — sinyal sayacı her başarısız denemede artar.
    // SEYİR ÖNCESİ KONTROL (kullanıcı onayı 2026-08, günde bir nazik şerit):
    // yeni rota çizildi → kontrol şeridi (düzenlemeler routeSeq artırmaz).
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.routeSeq),
      (int? prev, int next) {
        // TUR SIRASINDA SORULMAZ (örnekli tur dersi 2026-08): turun örnek
        // rotası günde-bir kontrol sorusunu tetiklememeli — soru kullanıcının
        // İLK GERÇEK rotasına saklanır (kalıcı hak yakılmaz).
        if (prev != null && next > prev) {
          // YENİ ROTA → ayrıntı kararı BİR KEZ burada verilir ve o rota
          // boyunca sabit kalır. (İnceleme dersi: karar her çizimde yeniden
          // hesaplansaydı, kaptan 2. durağı eklediği anda çip kapanır ve
          // "+ Nokta ekle" düğmesi elinden kaçardı.)
          final int stops = ref
              .read(mapControllerProvider)
              .routeWaypoints
              .where((RouteWaypoint w) => w.isStop)
              .length;
          ref.read(routeChipExpandedProvider.notifier).state =
              stops < kRouteChipAutoCollapseStops;
          if (!ref.read(onboardingControllerProvider).tourActive) {
            ref.read(checklistProvider.notifier).maybePrompt();
          }
        }
      },
    );
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.routeFailSeq),
      (int? prev, int next) {
        if (next > (prev ?? 0)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).routeDirectNote)),
            );
        }
      },
    );
    // ROTA DÜZENLEME uyarısı (2026-08): tutamaç/durak değişikliği rota
    // bulamadıysa ESKİ ROTA KORUNUR ve kısa bir açıklama gösterilir.
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.routeEditFailSeq),
      (int? prev, int next) {
        if (next > (prev ?? 0)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).routeEditFail)),
            );
        }
      },
    );
    // BAŞLANGIÇ SEÇİMİ başarısız (yakında deniz yok): kısa uyarı, mod açık kalır.
    ref.listen<int>(
      mapControllerProvider.select((MapState s) => s.originPickFailSeq),
      (int? prev, int next) {
        if (next > (prev ?? 0)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).originPickFail)),
            );
        }
      },
    );
    // İlk ara nokta eklenince tek seferlik ipucu: taşımak için sürükle,
    // kaldırmak için dokun (keşfedilebilirlik).
    ref.listen<int>(
      mapControllerProvider.select((MapState s) =>
          s.routeWaypoints.where((RouteWaypoint w) => !w.isStop).length),
      (int? prev, int next) {
        if ((prev ?? 0) == 0 && next > 0) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(ref.read(l10nProvider).routeViaHint)),
            );
        }
      },
    );
    final MapSurfaceBuilder surfaceBuilder = ref.watch(mapSurfaceBuilderProvider);
    // YENİ KULLANICI TANITIMI (2026-08): karşılama + tur + ilk-dokunuş ipuçları.
    final OnboardingState onb = ref.watch(onboardingControllerProvider);
    final bool isList = ref.watch(mapViewIsListProvider);
    final selectedPin = state.selectedPin;
    // ROTA ODAK MODU (kullanıcı isteği 2026-08): kayıtlı rota açıkken
    // yalnız rotanın DURAK imleçleri kalır — diğer imleçler ve kümeler
    // gizlenir; sahnede sadece rota ve durakları vardır. "+ Nokta ekle" ve
    // "başlangıç seç" modlarında süzgeç GEÇİCİ kalkar (inceleme dersi:
    // "koya dokunursan durak olur" sözü tutulmalı — koylar görünmeli).
    final bool focusOn =
        state.routeFocus && !state.addingPoint && !state.pickingOrigin;
    final Set<String> focusStopIds = focusOn
        ? <String>{
            for (final RouteWaypoint w in state.routeWaypoints)
              if (w.id != null) w.id!,
          }
        : const <String>{};
    final List<LocationPin> basePins = focusOn
        ? state.pins
            .where((LocationPin p) => focusStopIds.contains(p.id))
            .toList(growable: false)
        : state.pins;
    // "Teknem sığar" filtresi: SIĞMAYANLAR gizlenir; bilinmeyenler kalır.
    final bool fitOn = ref.watch(mapFitFilterProvider);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final List<LocationPin> visiblePins = (fitOn && boat != null)
        ? basePins
            .where((LocationPin p) =>
                computeBoatFit(
                  boat: boat,
                  maxBoatLengthM: p.maxBoatLengthM,
                  maxDraftM: p.maxDraftM,
                ) !=
                BoatFit.tooBig)
            .toList(growable: false)
        : basePins;

    return Scaffold(
      // fit: expand (saha dersi 2026-08) — YAPISAL KORUMA: ileride biri
      // Stack'e konumlandırılmamış bir çocuk eklerse yığın O ÇOCUĞA göre
      // küçülüp haritayı yok edemez; her çocuk ekranı kaplar.
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: isList
                ? _MapListView(pins: visiblePins)
                : surfaceBuilder(
                    context,
                    MapSurfaceData(
                      pins: visiblePins,
                      // Odak modunda kümeler de gizlenir (yalnız rota kalır).
                      clusters:
                          focusOn ? const <Cluster>[] : state.clusters,
                      selectedPinId: state.selectedPinId,
                      // Kullanıcının GPS konumu → haritada yelkenli imleç;
                      // "Konumum" isteği → kamera odaklanır (kullanıcı isteği).
                      devicePosition: ref.watch(devicePositionProvider),
                      focus: ref.watch(mapFocusProvider),
                      routePoints: state.route?.points,
                      routeSeq: state.routeSeq,
                      // ROTA DÜZENLEME (2026-08): bacaklar → tutamaçlar,
                      // ara noktalar → taşınabilir tutamaçlar, duraklar →
                      // numaralı rozetler.
                      routeLegPoints: state.routeLegs.isEmpty
                          ? null
                          : <List<GeoPoint>>[
                              for (final SeaRoutePlan l in state.routeLegs) l.points,
                            ],
                      routeVias: <MapRouteVia>[
                        for (int i = 0; i < state.routeWaypoints.length; i++)
                          if (!state.routeWaypoints[i].isStop)
                            MapRouteVia(index: i, pos: state.routeWaypoints[i].pos),
                      ],
                      routeStops: _stopMarkers(state.routeWaypoints),
                      // A NOKTASI rozeti: başlangıç GPS değilse çizilir.
                      routeOriginBadge: state.routeOrigin != null &&
                              !state.routeOrigin!.isDevice
                          ? state.routeOrigin!.pos
                          : null,
                    ),
                    MapSurfaceCallbacks(
                      onViewportChanged: controller.onViewportChanged,
                      onPinTap: controller.selectPin,
                      onClusterTap: (_) => controller.clearSelection(),
                      onRouteInsertVia: controller.insertVia,
                      onRouteMoveVia: controller.moveVia,
                      onRouteRemoveVia: controller.removeWaypoint,
                      onMapTap: controller.onMapTapped,
                    ),
                  ),
          ),
          // ÜST KATMAN — UX DENETİMİ P0-2 (kullanıcı onayı 2026-08): en üstte
          // TAM GENİŞLİK ARAMA HAPI. Google/Apple Maps alışkanlığı: "ne
          // yapacağım?" sorusunun evrensel cevabı ekranın tepesindeki arama
          // kutusudur. Eski sağ-kolon arama düğmesinin işlevi buraya taşındı.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              child: KeyedSubtree(
                key: tourKeySearch,
                child: const _MapSearchPill(),
              ),
            ),
          ),
          // Tip filtre çipleri arama hapının HEMEN ALTINA indi (P0-2):
          // önce "ara", sonra "süz" — okuma sırası doğal hiyerarşiyi izler.
          Positioned(
            top: 66, // 12 (hap üstü) + 46 (hap) + 8 (ara)
            left: 0,
            right: 0,
            child: SafeArea(
              // Tur hedefi (v3): "Filtreler" adımı bu şeridi okla gösterir.
              child: KeyedSubtree(
                key: tourKeyChips,
                child: _TypeFilterRow(selected: state.types),
              ),
            ),
          ),
          // SAĞ KOLON SADELEŞTİ (P0-2): eskiden dört eş yuvarlak düğme üst
          // üsteydi (SOS→Konumum→Arama→Rota) ve panik butonu en işlek
          // noktadaydı. Artık yalnız İKİNCİL araçlar burada: Konumum +
          // harita↔liste. Arama üstteki hapa, rota sağ alttaki etiketli
          // FAB'a, SOS sol alt köşeye taşındı — işlev birebir aynı.
          Positioned(
            top: 114, // 66 (çip üstü) + 40 (çip şeridi) + 8 (ara)
            right: 12,
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  KeyedSubtree(key: tourKeyLocate, child: const LocateButton()),
                  if (state.pins.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _ViewToggle(
                      isList: isList,
                      onToggle: () =>
                          ref.read(mapViewIsListProvider.notifier).state = !isList,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (state.isLoading && state.hasData)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          // Üst-orta bilgi katmanı: çevrimdışı şeridi + deniz rotası çipi.
          if (state.isOffline || state.route != null)
            Positioned(
              // P0-2: üst katman artık hap (46) + çipler (40) — bilgi çipi
              // onların altından başlar.
              top: 114,
              // ROTA BİLGİ EKRANI 2.0 (kullanıcı isteği 2026-08): çip artık
              // ekranın genişliğini kullanır — "küçük kalıyor" düzeltmesi.
              // Sağda 64: Konumum/liste düğme sütunuyla çakışmaz.
              left: 12,
              right: 64,
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    if (state.isOffline) const Center(child: _OfflineBanner()),
                    if (state.isOffline && state.route != null)
                      const SizedBox(height: 8),
                    if (state.route != null)
                      Center(
                        // Tur hedefi (örnekli tur v5): "rotanı düzenle" adımı
                        // bu bilgi kartını vurgular.
                        child: KeyedSubtree(
                          key: tourKeyRouteChip,
                          child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _RouteChip(
                            route: state.route!,
                            wind: state.routeWind,
                            waypoints: state.routeWaypoints,
                            origin: state.routeOrigin,
                            onClear: controller.clearRoute,
                            onRemoveStop: controller.removeWaypoint,
                            onSave: () =>
                                _saveRouteDialog(context, ref, state),
                            label: state.routeLabel,
                            onChangeOrigin: () =>
                                showRouteOriginMenu(context, ref),
                            onAddPoint: controller.beginAddPoint,
                          ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (state.truncated) const _TruncatedHint(),
          if (state.isLoading && !state.hasData)
            const Positioned.fill(child: _CenterProgress()),
          if (state.isEmpty) const Positioned.fill(child: _EmptyView()),
          if (state.failure != null)
            Positioned.fill(
              child: _ErrorView(
                message: state.failure!.message,
                onRetry: () => controller.retry(),
              ),
            ),
          // "Yakınındaki Limanlar" alt-sayfası (tasarım §07 peek durumu):
          // harita modunda, seçili pin yokken. Pin seçilince yerini karta bırakır.
          if (!isList && selectedPin == null)
            const Positioned(left: 0, right: 0, bottom: 0, child: NearbySheet()),
          // SOS SOL ALTTA, YALNIZ (P0-2, kullanıcı onayı 2026-08): panik
          // butonunun değeri ayrıksılığındadır — onu bulunur kılan boyutu
          // değil, YALNIZLIĞIDIR. En işlek kolonun tepesinden (en çok
          // yanlışlıkla dokunulan nokta) kimsenin kazara basmayacağı sol alt
          // köşeye taşındı; kas hafızasıyla bulunur. Davranış AYNEN: tek
          // dokunuş, üyelik kapısı yok, çevrimdışı çalışır. Pin kartı
          // açılınca kart üstte çizilir (Stack sırası); kart kapanınca SOS
          // aynı yerdedir.
          Positioned(
            left: 12,
            bottom: 78, // yakın rayının (katlı ~62) üstünde
            child: SafeArea(
              top: false,
              child: KeyedSubtree(key: tourKeySos, child: const _SosButton()),
            ),
          ),
          // "ROTA PLANLA" FAB'I (P0-2): uygulamanın imza özelliği artık
          // ADIYLA ve başparmağın tam altında. Rota çizilince kaybolur
          // (bilgi çipi devralır — mevcut davranış), pin kartı açıkken
          // karta yol verir (kartta zaten Rota düğmesi var), yakın rayı
          // açıkken rayın kartlarını örtmez.
          if (state.route == null &&
              selectedPin == null &&
              // Hata/boş ekranların üstüne rota daveti ÇIKMAZ (davet
              // kartıyla aynı kural). SOS ise bilerek HER durumda kalır —
              // acil buton hata ekranında da çalışmalı.
              state.failure == null &&
              !state.isEmpty &&
              (isList || ref.watch(nearbySheetCollapsedProvider)))
            const Positioned(
              right: 12,
              bottom: 78,
              child: SafeArea(
                top: false,
                child: _RouteStartButton(),
              ),
            ),
          // "BUGÜN NEREYE?" DAVET KARTI (onaylı E1: haritanın tek eklemesi).
          // Rota/seçim yokken ve tur kapalıyken görünür; kapatılabilir ve
          // Bugün'e bir kez gidilince bir daha çıkmaz. YAKIN RAYININ ÜSTÜNDE
          // durur (inceleme dersi: Stack'te sonra gelen üstte çizilir ve
          // dokunuşu alır — kart rayın altında kalmamalı).
          // NOT (CI/saha dersi 2026-08): bu Stack'in TÜM çocukları
          // Positioned olmalıdır. Konumlandırılmamış tek bir çocuk (boş
          // SizedBox dahil) Stack'in boyutunu O ÇOCUĞA göre küçültür ve
          // harita komple KAYBOLUR (beyaz ekran). Bu yüzden kartın
          // "gösterilmesin" kararı burada verilir, kartın içinde DEĞİL.
          if (state.route == null &&
              selectedPin == null &&
              !isList &&
              onb.tourStep < 0 &&
              // Tur daveti de aynı bantta duruyor (kabuk katmanında); iki
              // davet üst üste binmesin — tur daveti bir kerelik, o geçsin.
              !onb.tourInvite &&
              // Hata/boş/yükleme ekranlarının üstüne davet ÇIKMAZ ve yakın
              // rayı AÇIKKEN kartların dokunuşunu çalmaz (inceleme dersi).
              state.failure == null &&
              !state.isEmpty &&
              ref.watch(nearbySheetCollapsedProvider) &&
              !ref.watch(todayInviteDismissedProvider))
            const _TodayInviteCard(),
          if (!isList && selectedPin != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // İLK-DOKUNUŞ İPUCU (tanıtım 2026-08): ilk pin seçiminde
                  // kartın üstünde tek seferlik açıklama balonu.
                  if (onb.showHint(kHintBottomCard))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: OnboardingHintBubble(
                            hintKey: kHintBottomCard,
                            title: ref.watch(l10nProvider).onbHintCardTitle,
                            body: ref.watch(l10nProvider).onbHintCardBody,
                          ),
                        ),
                      ),
                    ),
                  LocationBottomCard(
                pin: selectedPin,
                // Tekne tanımlıysa kartta uyum rozeti (harita pinleriyle tutarlı).
                fit: computeBoatFit(
                  boat: ref.watch(myBoatProvider),
                  maxBoatLengthM: selectedPin.maxBoatLengthM,
                  maxDraftM: selectedPin.maxDraftM,
                ),
                onClose: controller.clearSelection,
                onOpenDetail: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LocationDetailScreen(idOrSlug: selectedPin.id),
                  ),
                ),
                routing: state.isRouting,
                // ROTA DÜZENLEME (2026-08): rota ÇİZİLİYKEN başka koya
                // dokununca "Durak ekle" gösterilir (rota baştan kurulmaz);
                // koy zaten rotadaysa yalnız Detay kalır.
                onAddStop: state.route != null &&
                        !state.routeWaypoints
                            .any((RouteWaypoint w) => w.id == selectedPin.id)
                    ? () => controller.addStop(
                          selectedPin.position,
                          selectedPin.id,
                          selectedPin.name,
                        )
                    : null,
                // AKILLI ROTA (kullanıcı isteği 2026-08): konum yoksa izin
                // OTOMATİK istenir; onay gelince rota kendiliğinden çizilir.
                onRoute: state.route != null
                    ? null
                    : () => startSeaRoute(
                          context,
                          ref,
                          destPos: selectedPin.position,
                          destId: selectedPin.id,
                          destName: selectedPin.name,
                        ),
                  ),
                ],
              ),
            ),
          // MOD ŞERİTLERİ: başlangıç seçimi / rotaya nokta ekleme (üstte).
          if (state.pickingOrigin)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ModeBanner(
                text: ref.watch(l10nProvider).routePickBanner,
                onCancel: controller.cancelOriginPick,
              ),
            ),
          if (state.addingPoint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ModeBanner(
                text: ref.watch(l10nProvider).routeAddPointBanner,
                onCancel: controller.cancelAddPoint,
              ),
            ),
          // SEYİR ÖNCESİ KONTROL ŞERİDİ (günde bir; onaylı doz): nazik soru,
          // iki saygın çıkış — "Listeyi aç" / "Hazırım".
          if (ref.watch(checklistProvider).promptVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ChecklistBanner(
                onOpen: () {
                  ref.read(checklistProvider.notifier).dismissPrompt();
                  showChecklistSheet(context);
                },
                onReady: () =>
                    ref.read(checklistProvider.notifier).dismissPrompt(),
              ),
            ),
          // TANITIM TURU v3 (2026-08): kaplama artık KABUKTA (DocklyShell) —
          // tur sekme değiştirebilir ve karartma alt menüyü de kapsar.
        ],
      ),
    );
  }
}

/// Harita ↔ liste geçiş düğmesi (sağ üst).
class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.isList, required this.onToggle});

  final bool isList;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: IconButton(
        icon: DocklyIcon(isList ? DocklyIcons.mapOutlined : DocklyIcons.viewList),
        tooltip: isList ? t.mapViewTooltip : t.listViewTooltip,
        onPressed: onToggle,
      ),
    );
  }
}

/// Keşfet sekmesinin liste görünümü: görünen limanlar, haritada baktığın
/// noktaya (başlangıç) göre en yakından uzağa sıralı. Dokununca detay açılır.
class _MapListView extends ConsumerWidget {
  const _MapListView({required this.pins});

  final List<LocationPin> pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final GeoPoint? origin = ref.watch(originProvider);
    final List<LocationPin> items = List<LocationPin>.of(pins);
    if (origin != null) {
      items.sort((LocationPin a, LocationPin b) =>
          haversineNm(origin, a.position).compareTo(haversineNm(origin, b.position)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (BuildContext _, int __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final LocationPin pin = items[i];
        final double? distNm = origin != null ? haversineNm(origin, pin.position) : null;
        final String subtitle = pin.ratingAvg != null
            ? '${t.typeLabel(pin.type)} · ★ ${pin.ratingAvg!.toStringAsFixed(1)}'
            : t.typeLabel(pin.type);
        return ListTile(
          leading: DocklyTypeAvatar(type: pin.type),
          title: Text(pin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: distNm != null ? Text('${_fmtNm(distNm)} ${t.nmUnit}') : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => LocationDetailScreen(idOrSlug: pin.id),
            ),
          ),
        );
      },
    );
  }
}

String _fmtNm(double nm) => nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);

/// MOD ŞERİDİ (rota planlama/nokta ekleme): lacivert, tek satır yönerge +
/// Vazgeç. Mod açıkken haritaya/koya dokunuşun anlamını açıklar.
/// Seyir öncesi kontrol şeridi (kullanıcı onayı 2026-08): lacivert zemin,
/// soru + iki eylem. Günde bir kez görünür; "Hazırım" ya da liste açılınca
/// aynı gün bir daha çıkmaz.
class _ChecklistBanner extends ConsumerWidget {
  const _ChecklistBanner({required this.onOpen, required this.onReady});

  final VoidCallback onOpen;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      color: DocklyColors.brandDeep,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: <Widget>[
              const DocklyIcon(DocklyIcons.checkCircle,
                  size: 18, color: Color(0xFF7FE7DC)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.checklistAsk,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('checklist-open'),
                onPressed: onOpen,
                child: Text(
                  t.checklistOpenBtn,
                  style: const TextStyle(
                    color: Color(0xFF7FE7DC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('checklist-ready'),
                onPressed: onReady,
                child: Text(
                  t.checklistReadyBtn,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBanner extends ConsumerWidget {
  const _ModeBanner({required this.text, required this.onCancel});

  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      color: DocklyColors.brandDeep,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: DocklyColors.accentTurquoise.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: DocklyIcon(DocklyIcons.place,
                      size: 14, color: Color(0xFF7FE3D9)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text(
                  t.cancelLabel,
                  style: TextStyle(
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ROTAYI KAYDET diyaloğu (rota planlama 2026-08): ad önerilir, Kaydet cihaza
/// yazar (başlangıç + duraklar — açılışta aynı motorla yeniden hesaplanır).
Future<void> _saveRouteDialog(
    BuildContext context, WidgetRef ref, MapState state) async {
  final L10n t = ref.read(l10nProvider);
  final RouteOrigin? origin = state.routeOrigin;
  final SeaRoutePlan? route = state.route;
  if (origin == null || route == null || state.routeWaypoints.isEmpty) return;
  final String originLabel =
      origin.name ?? (origin.isDevice ? t.routeOriginDevice : t.routeOriginPicked);
  final TextEditingController nameCtrl = TextEditingController(
    text: suggestRouteName(originLabel, state.routeWaypoints),
  );
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(t.routeAddToSaved),
      content: TextField(
        controller: nameCtrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: t.routeSaveNameHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.saveLabel),
        ),
      ],
    ),
  );
  final String name = nameCtrl.text.trim();
  nameCtrl.dispose(); // diyalog kapandı — denetleyici sızdırılmaz
  if (ok != true || !context.mounted) return;
  final String finalName = name.isEmpty ? originLabel : name;
  final int now = DateTime.now().millisecondsSinceEpoch;
  await ref.read(savedRoutesProvider.notifier).add(SavedRoute(
        id: 'r$now',
        name: finalName,
        origin: origin,
        waypoints: state.routeWaypoints,
        distanceNm: route.distanceNm,
        savedAtMs: now,
      ));
  if (!context.mounted) return;
  // İSİM ÇİPE YAZILIR (kullanıcı isteği 2026-08): verilen ad kayıttan hemen
  // sonra ekrandaki rotanın başlığında görünür — "isimler gözükmüyor" düzeltmesi.
  ref.read(mapControllerProvider.notifier).setRouteLabel(finalName);
  // GÜNLÜK KISAYOLU (kullanıcı onayı 2026-08): rota kaydedildi → tek
  // dokunuşla günlüğe not düşülür; rota bağlamı kendiliğinden eklenir.
  final LogContext logCtx = LogContext(
    routeName: finalName,
    distanceNm: route.distanceNm,
    stops: state.routeWaypoints.where((RouteWaypoint w) => w.isStop).length,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(t.routeSaved),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: t.logbookSnackAction,
        onPressed: () {
          if (context.mounted) {
            showLogEntryEditor(context, ref, logContext: logCtx);
          }
        },
      ),
    ));
}

/// Duraklardan numaralı harita rozetleri (1, 2, …). Tek duraklı rotada (yalnız
/// hedef) rozet çizilmez — hedefin pini zaten oradadır.
List<MapRouteStop> _stopMarkers(List<RouteWaypoint> wps) {
  final List<MapRouteStop> out = <MapRouteStop>[];
  int n = 0;
  for (final RouteWaypoint w in wps) {
    if (w.isStop) out.add(MapRouteStop(number: ++n, pos: w.pos));
  }
  return out.length <= 1 ? const <MapRouteStop>[] : out;
}

class _CenterProgress extends ConsumerWidget {
  const _CenterProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // İlk yükleme dost mesajı: sunucu ısınırken kullanıcı "uygulama bozuk"
    // sanmasın (P0 algı). Veri geldikten sonra görünmez.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              ref.watch(l10nProvider).loadingHarbors,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Çevrimdışı bilgi şeridi: bağlantı yokken cihazdaki son görülen limanların
/// gösterildiğini söyler. Haritayı gezdirmek yeniden denemeyi tetikler.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DocklyIcon(
              DocklyIcons.infoOutline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              ref.watch(l10nProvider).offlineBanner,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Harita üstü tip filtre çipleri: her çipte tipin harita rengi nokta olarak
/// bulunur — filtre + lejant tek bileşende. Boş seçim = tüm tipler.
class _TypeFilterRow extends ConsumerWidget {
  const _TypeFilterRow({required this.selected});

  final Set<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<String> types = DocklyMapColors.knownTypes.toList();
    final bool fitOn = ref.watch(mapFitFilterProvider);
    final bool hasBoat = ref.watch(myBoatProvider) != null;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: types.length + 1,
        separatorBuilder: (BuildContext _, int __) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int i) {
          // İlk çip: "Teknem sığar" — tekne yoksa dokununca tekne sayfası açılır.
          if (i == 0) {
            return Center(
              child: FilterChip(
                label: Text(t.fitChip),
                avatar: const DocklyIcon(
                  DocklyIcons.checkCircle,
                  size: 14,
                  color: DocklyColors.success,
                ),
                selected: fitOn,
                onSelected: (bool _) {
                  if (!hasBoat) {
                    showBoatSheet(context);
                    return;
                  }
                  ref.read(mapFitFilterProvider.notifier).state = !fitOn;
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          }
          final String type = types[i - 1];
          return Center(
            child: FilterChip(
              label: Text(t.typeLabel(type)),
              avatar: DocklyIcon(
                DocklyIcons.circle,
                size: 12,
                color: DocklyMapColors.forType(type),
              ),
              selected: selected.contains(type),
              onSelected: (bool _) =>
                  ref.read(mapControllerProvider.notifier).toggleType(type),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          ref.watch(l10nProvider).emptyArea,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Bu oturumda davet kartı kapatıldı mı? (Onaylı E1: "kapatılabilir".)
/// Bugün sekmesine gidilince de kapanır — davet işini görmüştür.
final StateProvider<bool> todayInviteDismissedProvider =
    StateProvider<bool>((ref) => false);

/// "BUGÜN NEREYE?" DAVET KARTI (onaylı E1 tasarımı): haritanın altında,
/// alt menünün üstünde duran küçük gün-ışığı kartı. Kaptanı yıldız
/// özelliğe çağırır; kapatılabilir ve ısrar etmez.
class _TodayInviteCard extends ConsumerWidget {
  const _TodayInviteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    // GÖRÜNÜRLÜK KARARI ÇAĞIRANDA (yukarıdaki nota bakınız): bu widget her
    // zaman Positioned döner — Stack'in boyutunu asla bozmaz.
    return Positioned(
      left: 12,
      right: 12,
      // Yakın rayının (kapalı hâlde ~62 px) ve SOS + "Rota planla" FAB
      // bandının (P0-2: bottom 78, ~56 boy) ÜSTÜNDE durur — ne rayı
      // ne köşe düğmelerini örter.
      bottom: 142,
      child: SafeArea(
        top: false,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
          child: InkWell(
            key: const ValueKey<String>('today-invite'),
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              ref.read(todayInviteDismissedProvider.notifier).state = true;
              ref.read(shellTabProvider.notifier).state = 1; // Bugün
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Center(
                      child: DocklyIcon(DocklyIcons.star,
                          size: 18, color: Color(0xFFB45309)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          t.todayInviteTitle,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          t.todayInviteBody,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    t.todayInviteCta,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: const ValueKey<String>('today-invite-close'),
                    tooltip: t.todayInviteDismiss,
                    visualDensity: VisualDensity.compact,
                    icon: DocklyIcon(DocklyIcons.close,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => ref
                        .read(todayInviteDismissedProvider.notifier)
                        .state = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TruncatedHint extends ConsumerWidget {
  const _TruncatedHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            ref.watch(l10nProvider).tooManyHint,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Acil Durum kısayolu (2026-08): kırmızı SOS — panikte tek dokunuş.
/// Bilinçli olarak üyelik kapısız; Acil Durum sayfası tamamen çevrimdışıdır.
/// P0-2 (2026-08): sol alt köşede yalnız durur; boyut 48→44 (ayrıksılık
/// bulunurluğu sağlar, boyut değil). Davranış değişmedi.
class _SosButton extends ConsumerWidget {
  const _SosButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Material(
      elevation: 3,
      color: DocklyColors.error,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()),
        ),
        child: Tooltip(
          message: t.emergencyTitle,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Rota planla" — haritanın ilk ekranındaki rota girişi (Faz 1 →
/// P0-2, 2026-08: sağ altta ETİKETLİ FAB). Uygulamanın imza özelliği artık
/// adıyla kendini anlatıyor ve tek elle kullanımda başparmağın tam altında.
///
/// Akış AYNEN: hedefi ADIYLA arat → seç → mevcut `startSeaRoute` akışı
/// devralır (konum izni, gerekirse başlangıç menüsü). Yeni bir rota mantığı
/// YAZILMADI; yalnız var olan yeteneğin kapısı görünür kılındı.
class _RouteStartButton extends ConsumerWidget {
  const _RouteStartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return FloatingActionButton.extended(
      key: const ValueKey<String>('map-route-start'),
      // Kabuk IndexedStack'inde başka FAB'lar da yaşıyor (günlük FAB'ı) —
      // varsayılan heroTag çakışması çökme yaratır; her FAB kendi etiketini
      // taşır (logbook-fab dersi).
      heroTag: 'map-route-fab',
      backgroundColor: DocklyColors.brandPrimary,
      foregroundColor: Colors.white,
      // Pusula: "Konumum" düğmesi `navigation` kullanıyor; aynı glifi iki
      // düğmede kullanmak ikisini de okunmaz yapardı.
      icon: const DocklyIcon(DocklyIcons.compass, size: 20, color: Colors.white),
      label: Text(t.routePlanFab),
      onPressed: () async {
        final LocationSummary? picked =
            await Navigator.of(context).push<LocationSummary>(
          MaterialPageRoute<LocationSummary>(
            builder: (BuildContext _) =>
                const SearchScreen(pickDestination: true),
          ),
        );
        if (picked == null || !context.mounted) return;
        await startSeaRoute(
          context,
          ref,
          destPos: picked.position,
          destId: picked.id,
          destName: picked.name,
        );
      },
    );
  }
}

/// ARAMA HAPI (P0-2, 2026-08): haritanın tepesinde tam genişlik arama girişi
/// — eski sağ-kolon arama düğmesinin yerine. Dokununca arama sayfası açılır;
/// sonuçtan detay açılır, harita durumu korunur (işlev birebir aynı).
class _MapSearchPill extends ConsumerWidget {
  const _MapSearchPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(23),
      color: theme.colorScheme.surface,
      child: InkWell(
        key: const ValueKey<String>('map-search-pill'),
        borderRadius: BorderRadius.circular(23),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
        ),
        child: SizedBox(
          height: 46,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 16),
              DocklyIcon(
                DocklyIcons.search,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// ROTA ÇİPİ AYRINTI DURUMU (kullanıcı isteği 2026-08: "çok nokta ekleyince
/// ekranı kaplıyor"). null = OTOMATİK: kısa rotada açık, çok duraklı rotada
/// kapalı. Kaptan bir kez dokunursa tercihi (true/false) o rota boyunca
/// korunur; yeni rota çizilince otomatiğe döner.
final StateProvider<bool?> routeChipExpandedProvider =
    StateProvider<bool?>((ref) => null);

/// Bu sayıya ULAŞAN durak sayısında (2 ve üzeri) çip kendini toplar.
const int kRouteChipAutoCollapseStops = 2;

/// Deniz rotası bilgi ekranı 2.0 (kullanıcı isteği 2026-08): başlıkta rota
/// adı; altında MESAFE / SÜRE / DURAK istatistik satırı (üç eşit sütun —
/// çok duraklı rotada da süre HER ZAMAN görünür); sonra başlangıç satırı,
/// durak listesi, dürüst uyarı notu ve (analiz gelince) rüzgâr satırları.
/// Kapat düğmesi rotayı haritadan kaldırır.
class _RouteChip extends ConsumerWidget {
  const _RouteChip({
    required this.route,
    required this.onClear,
    this.wind,
    this.waypoints = const <RouteWaypoint>[],
    this.origin,
    this.onRemoveStop,
    this.onSave,
    this.onChangeOrigin,
    this.onAddPoint,
    this.label,
  });

  /// KAYITLI ROTA adı (kullanıcı isteği 2026-08): kayıttan açılan rotanın
  /// kullanıcı verdiği ismi başlıkta görünür.
  final String? label;

  final SeaRoutePlan route;
  final RouteWindReport? wind;
  final VoidCallback onClear;

  /// Rotanın sıralı ara noktaları (duraklar + tutamaç noktaları).
  final List<RouteWaypoint> waypoints;

  /// Rotanın başlangıcı — çipte "A:" satırı (rota planlama 2026-08).
  final RouteOrigin? origin;

  /// Çipteki ✕ ile durak çıkarma (dizin, durum listesine göredir).
  final void Function(int wpIndex)? onRemoveStop;

  /// Rotayı kaydet (yer imi simgesi).
  final VoidCallback? onSave;

  /// Başlangıcı değiştir ("A:" satırındaki bağlantı).
  final VoidCallback? onChangeOrigin;

  /// NOKTA EKLE modunu açar (kullanıcı isteği 2026-08): dokunarak ara nokta /
  /// durak ekleme — mobilde sürüklemeye alternatif en kolay yol.
  final VoidCallback? onAddPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final double hours = route.etaHoursAtCruise;
    final int h = hours.floor();
    final int min = ((hours - h) * 60).round();
    final String eta = h > 0
        ? L10n.fmt2(t.etaHmFmt, '$h', '$min')
        : L10n.fmt(t.etaMFmt, '$min');
    // Dürüstlük notu: rota tahminîdir; koya ulaşmadıysa ya da motor
    // çalışmadıysa (kuş uçuşu) bunu AÇIKÇA söyleriz.
    final String note = !route.viaSea
        ? t.routeDirectNote
        : (route.reachedGoal ? t.routeApproxNote : t.routeCoastNote);
    final RouteWindReport? w = wind;
    final int stopCount =
        waypoints.where((RouteWaypoint x) => x.isStop).length;
    // AYRINTI KATLAMA (kullanıcı isteği 2026-08: "çok nokta ekleyince ekranı
    // kaplıyor"). Otomatik kural: 2+ duraklı rotada çip kendini toplar;
    // kaptan ok düğmesiyle her an açıp kapatabilir. KAPALIYKEN DE görünenler:
    // rota adı, mesafe/süre/durak ve (varsa) RÜZGÂR UYARISI — güvenlik
    // bilgisi asla gizlenmez.
    final bool? override = ref.watch(routeChipExpandedProvider);
    // null yalnız ilk karede olur (rota kurulurken); o an açık gösterilir.
    final bool expanded = override ?? true;
    // Yükseklik tavanı: AYRINTI bölümü ekranın %34'ünü aşamaz (çipin tamamı
    // başlık+istatistik+seyir satırıyla birlikte ~%52'de kalır); içerik
    // uzarsa kaydırılır — harita her zaman görünür kalır.
    final double maxDetail = MediaQuery.sizeOf(context).height * 0.34;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // BAŞLIK (bilgi ekranı 2.0, 2026-08): kayıtlı rota adı — yoksa
            // genel başlık. Sayılar artık başlıkta sıkışmaz; alttaki
            // istatistik satırında HER ZAMAN okunur.
            Row(
              children: <Widget>[
                const DocklyIcon(
                  DocklyIcons.navigation,
                  size: 16,
                  color: DocklyColors.brandPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label ?? t.routeChipTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // SEYİR ÖNCESİ KONTROL: liste çipten her an açılabilir.
                IconButton(
                  tooltip: t.checklistTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: const DocklyIcon(DocklyIcons.checkCircle, size: 17),
                  onPressed: () => showChecklistSheet(context),
                ),
                // ROTA BİRLEŞTİRME (kurucu onayı 2026-08, revizyon): kaydet
                // eylemi başlıktaki yer imi ikonundan çıktı; "Seyri planla"nın
                // YANINDA eş boy, turkuaz "Rotalarım'a ekle" düğmesi oldu —
                // bkz. _PlanTripRow (kurucu isteği: iki eylem yan yana,
                // aynı tasarım, farklı renk).
                // AYRINTI AÇ/KAPA — ok yönü durumu anlatır.
                IconButton(
                  key: const ValueKey<String>('route-chip-toggle'),
                  icon: Transform.rotate(
                    angle: expanded ? -1.5708 : 1.5708,
                    child: const DocklyIcon(DocklyIcons.arrowForward, size: 17),
                  ),
                  tooltip: expanded ? t.routeChipCollapse : t.routeChipExpand,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref
                      .read(routeChipExpandedProvider.notifier)
                      .state = !expanded,
                ),
                IconButton(
                  icon: const DocklyIcon(DocklyIcons.close, size: 18),
                  tooltip: t.routeClearTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                ),
              ],
            ),
            // İSTATİSTİK SATIRI: mesafe / süre / durak — üç eşit sütun.
            // Uzun değer sütununa sığmazsa yazı KÜÇÜLÜR, asla kesilmez
            // ("toplam süre ekrana sığmıyor" düzeltmesi).
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4, right: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _RouteStat(
                      caption: t.routeStatDistance,
                      value: '≈ ${_fmtNm(route.distanceNm)} ${t.nmUnit}',
                    ),
                  ),
                  Expanded(
                    child: _RouteStat(
                      caption: t.routeStatDuration,
                      value: '~$eta',
                    ),
                  ),
                  Expanded(
                    child: _RouteStat(
                      caption: t.routeStatStops,
                      value: '$stopCount',
                    ),
                  ),
                ],
              ),
            ),
            // DÜRÜSTLÜK NOTU — KATLANMAZ (inceleme dersi 2026-08): mesafe ve
            // süre görünürken "bu rota tahminîdir / kıyıda biter" uyarısı
            // gizlenemez. Kapalıyken iki satırla sınırlanır.
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                note,
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            // AYRINTILAR (katlanabilir): başlangıç, duraklar ve rüzgâr
            // satırları. Tavanı aşarsa içerik kaydırılır.
            if (expanded)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxDetail),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                // BAŞLANGIÇ satırı (rota planlama 2026-08): A noktası + değiştir.
                if (origin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            L10n.fmt(
                              t.routeOriginFmt,
                              origin!.name ??
                                  (origin!.isDevice
                                      ? t.routeOriginDevice
                                      : t.routeOriginPicked),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (onChangeOrigin != null) ...<Widget>[
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onChangeOrigin,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              child: Text(
                                t.routeOriginChange,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: DocklyColors.brandPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // + NOKTA EKLE (kullanıcı isteği 2026-08): dokunarak
                        // ara nokta/durak ekleme modu — mobilde en kolay yol.
                        if (onAddPoint != null) ...<Widget>[
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onAddPoint,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const DocklyIcon(DocklyIcons.place,
                                      size: 12, color: DocklyColors.brandPrimary),
                                  const SizedBox(width: 3),
                                  Text(
                                    t.routeAddPointBtn,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: DocklyColors.brandPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // DURAK LİSTESİ: 2+ durakta sıralı hap listesi; hedef dışındakiler
                // ✕ ile çıkarılabilir (mesafe/süre tüm bacakların toplamıdır).
                if (stopCount >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final (int wpIndex, int number, RouteWaypoint wp)
                            in _numberedStops())
                          _StopPill(
                            number: number,
                            name: wp.name ?? '',
                            isLast: wpIndex == waypoints.length - 1,
                            removeTooltip: t.routeStopRemoveTooltip,
                            onRemove: onRemoveStop == null ||
                                    wpIndex == waypoints.length - 1
                                ? null
                                : () => onRemoveStop!(wpIndex),
                          ),
                      ],
                    ),
                  ),
                // RÜZGÂR SATIRI (Rota v2): rapor geldiyse — eşik renkleri rüzgâr
                // rozetiyle aynı (16 kn turuncu, 25 kn kırmızı).
                if (w != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      L10n.fmt2(
                            t.routeWindFmt,
                            w.worst.windKn.toStringAsFixed(0),
                            t.windExposedLabel(dir8Tr(w.worst.windDirDeg)),
                          ) +
                          (w.anyHeadwind ? ' · ${t.routeWindHeadwind}' : ''),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: w.warn ? FontWeight.w700 : FontWeight.w500,
                        color: w.strong
                            ? DocklyColors.error
                            : (w.warn
                                ? DocklyColors.warning
                                : theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                if (w != null && w.arrival != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      L10n.fmt2(
                        t.routeArrivalExposedFmt,
                        t.windExposedLabel(w.arrival!.dirTr),
                        w.arrival!.windKn.toStringAsFixed(0),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: w.arrival!.windKn >= kRouteWindStrongKn
                            ? DocklyColors.error
                            : DocklyColors.warning,
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              )
            // KAPALIYKEN: güvenlik bilgisi gizlenmez — rüzgâr uyarısı varsa
            // tek satır olarak durur, gerisi "aç" düğmesinin arkasındadır.
            else if (w != null && w.warn)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Row(
                  children: <Widget>[
                    DocklyIcon(
                      DocklyIcons.errorOutline,
                      size: 13,
                      color: w.strong
                          ? DocklyColors.error
                          : DocklyColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        L10n.fmt2(
                              t.routeWindFmt,
                              w.worst.windKn.toStringAsFixed(0),
                              t.windExposedLabel(dir8Tr(w.worst.windDirDeg)),
                            ) +
                            // Varışta koy rüzgâra açıksa bu, gecenin en
                            // önemli bilgisidir — kapalıyken de söylenir.
                            (w.arrival != null
                                ? ' · ${L10n.fmt2(t.routeArrivalExposedFmt, t.windExposedLabel(w.arrival!.dirTr), w.arrival!.windKn.toStringAsFixed(0))}'
                                : ''),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: w.strong
                              ? DocklyColors.error
                              : DocklyColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // SEYİR PLANI (v2.1 "Planla → Gerçekleşti", kurucu onayı
            // 2026-08): eski "Seyri başlat/bitir" çifti KALDIRILDI — canlı
            // navigasyon beklentisi yaratıyor ve teknede açık tutulmayan
            // uygulamada çöp süre üretiyordu (tasarım raporu §1/§9). Tek
            // dürüst eylem: "Seyri planla" → sefer Defter'e PLANLANDI
            // düşer; kaptan yaptığında Defter'den "Gerçekleşti"yi işaretler.
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: _PlanTripRow(
                t: t,
                name: label ??
                    suggestRouteName(
                      origin?.name ??
                          (origin?.isDevice == true
                              ? t.routeOriginDevice
                              : t.routeOriginPicked),
                      waypoints,
                    ),
                distanceNm: route.distanceNm,
                stops: stopCount,
                // ROTA BİRLEŞTİRME (v2.2): plan rotayı da taşır — Defter'deki
                // PLANLANDI kartından "Haritada aç" ile geri çağrılır.
                origin: origin,
                waypoints: waypoints,
                // "Rotalarım'a ekle" — planla düğmesinin yanındaki turkuaz
                // kardeş (kurucu isteği 2026-08).
                onAddToSaved: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Duraklar (isimli ara noktalar), rota sırasına göre numaralanmış:
  /// (durum dizini, sıra numarası, ara nokta).
  List<(int, int, RouteWaypoint)> _numberedStops() {
    final List<(int, int, RouteWaypoint)> out = <(int, int, RouteWaypoint)>[];
    int n = 0;
    for (int i = 0; i < waypoints.length; i++) {
      final RouteWaypoint w = waypoints[i];
      if (w.isStop) out.add((i, ++n, w));
    }
    return out;
  }
}

/// Bu rota bu oturumda deftere planlandı mı? (routeSeq ile eşleştirilir —
/// çift dokunuş çift plan üretmesin; yeni rota çizilince düğme geri gelir.)
final StateProvider<int?> plannedRouteSeqProvider =
    StateProvider<int?>((ref) => null);

/// SEYİR PLANI SATIRI (rota çipinin altı, v2.2): iki eş boy kardeş düğme —
/// MAVİ "Seyri planla" (sefer niyeti: Defter'e PLANLANDI düşer, rota plana
/// gömülür) ve TURKUAZ "Rotalarım'a ekle" (tarihsiz şablon rota). Renk
/// ayrımı işlevi anlatır, tasarım/boy birdir (kurucu isteği 2026-08).
/// Navigasyon başlatma/GPS iması taşıyan hiçbir söz kullanılmaz.
class _PlanTripRow extends ConsumerWidget {
  const _PlanTripRow({
    required this.t,
    required this.name,
    required this.distanceNm,
    required this.stops,
    this.origin,
    this.waypoints = const <RouteWaypoint>[],
    this.onAddToSaved,
  });

  final L10n t;
  final String name;
  final double distanceNm;
  final int stops;

  /// Rota verisi (v2.2): plana gömülür — "Haritada aç" bununla çalışır.
  final RouteOrigin? origin;
  final List<RouteWaypoint> waypoints;

  /// "Rotalarım'a ekle" (kurucu isteği 2026-08): planla düğmesinin yanında
  /// AYNI boy/tasarımda, TURKUAZ kardeş düğme — şablon rotalar için.
  final VoidCallback? onAddToSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int routeSeq =
        ref.watch(mapControllerProvider.select((MapState s) => s.routeSeq));
    final bool alreadyPlanned =
        ref.watch(plannedRouteSeqProvider) == routeSeq;
    // İkincil eylem: turkuaz "Rotalarım'a ekle" — planla ile eş boy/biçim,
    // renk ayrıştırır (mavi = sefer niyeti, turkuaz = şablon rota). Rota
    // planlandıktan SONRA da görünür kalır: kaptan önce planlayıp sonra
    // şablon olarak da saklayabilir.
    final Widget? saveBtn = onAddToSaved == null
        ? null
        : FilledButton.icon(
            key: const ValueKey<String>('route-add-saved'),
            style: FilledButton.styleFrom(
              backgroundColor: DocklyColors.accentTurquoise,
              foregroundColor: DocklyColors.brandDeep,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onAddToSaved,
            icon: const DocklyIcon(DocklyIcons.bookmark,
                size: 15, color: DocklyColors.brandDeep),
            label: Text(t.routeAddToSaved),
          );
    if (alreadyPlanned) {
      // Bu rota deftere eklendi — planla düğmesi yerini sakin bir onay
      // satırına bırakır; "Rotalarım'a ekle" yanında durmaya devam eder.
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const DocklyIcon(DocklyIcons.checkCircle,
                  size: 14, color: DocklyColors.success),
              const SizedBox(width: 5),
              Text(
                t.tripPlannedShort,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (saveBtn != null) saveBtn,
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.icon(
          key: const ValueKey<String>('trip-plan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () async {
            final int now = DateTime.now().millisecondsSinceEpoch;
            await ref.read(tripLogProvider.notifier).add(SeaTripLog(
                  id: 't$now',
                  name: name,
                  status: TripStatus.planned,
                  dateMs: now,
                  distanceNm: distanceNm,
                  stops: stops,
                  // Rota plana gömülür (v2.2) — başlangıç yoksa (olmamalı)
                  // rota verisi dürüstçe boş kalır.
                  routeOrigin: origin,
                  routeWaypoints:
                      origin == null || waypoints.isEmpty ? null : waypoints,
                ));
            ref.read(plannedRouteSeqProvider.notifier).state = routeSeq;
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(t.tripPlannedSnack)));
          },
          icon: const DocklyIcon(DocklyIcons.sailing,
              size: 15, color: Colors.white),
          label: Text(t.tripPlanBtn),
        ),
        if (saveBtn != null) saveBtn,
      ],
    );
  }
}

/// Rota istatistik hücresi (bilgi ekranı 2.0): küçük başlık + belirgin değer.
/// Değer sütuna sığmazsa FittedBox ile küçülür — kesilme/taşma olmaz.
class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            caption,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Çipteki durak hapı: sıra numarası + koy adı (+ hedef değilse ✕).
class _StopPill extends StatelessWidget {
  const _StopPill({
    required this.number,
    required this.name,
    required this.isLast,
    required this.removeTooltip,
    this.onRemove,
  });

  final int number;
  final String name;
  final bool isLast;
  final String removeTooltip;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color badge =
        isLast ? DocklyColors.accentTurquoise : DocklyColors.brandPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onRemove != null) ...<Widget>[
            const SizedBox(width: 3),
            Tooltip(
              message: removeTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: DocklyIcon(
                    DocklyIcons.close,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            DocklyButton(label: ref.watch(l10nProvider).retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
