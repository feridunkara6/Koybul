import 'dart:math' as math;

import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart' show AppFailure;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/external_links.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/presentation/account_gate.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart';
import '../../favorites/domain/favorite_location.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../map/application/map_controller.dart';
import '../../map/domain/map_state.dart';
import '../../map/presentation/route_origin_menu.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../route/domain/sea_trip.dart';
import '../../nearby/presentation/nearby_alternatives.dart';
import '../../reservation/presentation/reservation_sheet.dart';
import '../../reviews/presentation/reviews_section.dart';
import '../../route/domain/sea_route.dart';
import '../../occupancy/application/occupancy_controller.dart';
import '../../occupancy/presentation/occupancy_row.dart';
import '../application/location_detail_controller.dart';
import '../domain/anchorage_notes.dart';
import '../domain/approach_note.dart';
import 'cover_photo.dart';
import 'maritime_info_panel.dart';
import '../../weather/presentation/weather_card.dart';
import '../../weather/presentation/wind_warning_badge.dart';
import 'operating_info.dart';

/// Lokasyon detay ekranı (S-09, docs/01-prd §6.6) — YENİDEN TASARIM 2026-08
/// (kullanıcı onaylı A+B+C+D):
///  A) Lacivert KİMLİK KARTI (tip + doğrulanmış + ad + konum/koordinat +
///     rozetler) ve "BİR BAKIŞTA" şeridi (derinlik/zemin/açık yön/teknem).
///  B) UYARI KARTLARI: yaklaşma notu turuncu kart, rüzgâr bandı kırmızı/turuncu.
///  C) İkonlu BÖLÜM KARTLARI + tek dokunuş iletişim kutucukları.
///  D) YAPIŞKAN EYLEM ÇUBUĞU: Deniz Rotası + Doluluk Bildir/Rezervasyon.
/// 0-uydurma ilkesi sürer: verisi olmayan kutu/bölüm hiç çizilmez.
class LocationDetailScreen extends ConsumerWidget {
  const LocationDetailScreen({required this.idOrSlug, super.key});

  final String idOrSlug;

  static const ValueKey<String> contentKey = ValueKey<String>('location-detail-content');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LocationDetail> async = ref.watch(locationDetailProvider(idOrSlug));
    final LocationDetail? loaded = async.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? ref.watch(l10nProvider).detailFallbackTitle),
        actions: <Widget>[
          // PAYLAŞ (UX analizi 2026-08): ad + koordinat + site bağlantısını
          // panoya kopyalar — ek bağımlılık yok, her platformda çalışır.
          if (loaded != null) _ShareButton(detail: loaded),
          if (loaded != null) FavoriteButton(favorite: _favoriteFrom(loaded)),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => _DetailError(
          message: err is AppFailure
              ? err.message
              : ref.watch(l10nProvider).detailLoadFailed,
          onRetry: () => ref.invalidate(locationDetailProvider(idOrSlug)),
        ),
        data: (LocationDetail d) => _DetailContent(detail: d),
      ),
    );
  }
}

/// Detaydan favori anlık görüntüsü üretir (ad/tip/şehir) — Favoriler sekmesinde
/// gösterim için gereken az veri.
FavoriteLocation _favoriteFrom(LocationDetail d) {
  final AdminAreaRef? area = d.geo.adminArea;
  final String? city = area?.name ?? d.geo.waterBody?.name;
  return FavoriteLocation(id: d.id, name: d.name, type: d.type, city: city);
}

/// TİP KİMLİK RENGİ (kullanıcı onayı 2026-08): detay sayfası, HARİTADAKİ
/// İŞARETLE aynı rengi kuşanır — kullanıcı haritada gördüğü rengi sayfada
/// bulur. docs/09 §1.4'ün "pin renkleri yalnız haritada" rezervi bu ürün
/// kararıyla bilinçli olarak genişletildi: pin rengi = tip kimliği.
Color _identOf(String type) => DocklyMapColors.forType(type);

/// KOYU zemin mürekkebi: kimlik renginin ton koruyarak koyulaştırılmışı —
/// kapak degradesi ve renkli düğme zemini gibi "renk zeminin kendisi" olan
/// yerlerde kullanılır (üstündeki metin beyazdır).
Color _identInkOf(Color c) {
  final HSLColor h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness * 0.62).clamp(0.18, 0.42)).toColor();
}

/// YÜZEY mürekkebi (inceleme dersi 2026-08): ikon/etiket gibi zemin ÜSTÜNDE
/// duran ögeler için tema-duyarlı ton — açık temada koyulaştırılır (beyaz
/// zeminde okunur), koyu temada AÇILIR (koyu zeminde okunur). Tek kaynaktan:
/// karanlık modda koyu-üstüne-koyu görünmezlik yaşanmaz.
Color _identOnSurfaceOf(BuildContext context, Color ident) {
  final HSLColor h = HSLColor.fromColor(ident);
  return Theme.of(context).brightness == Brightness.dark
      ? h.withLightness((h.lightness * 1.30).clamp(0.60, 0.82)).toColor()
      : h.withLightness((h.lightness * 0.62).clamp(0.18, 0.42)).toColor();
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final LocationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    // Denizci bilgileri: yalnız DOLU alanlar stat'a çevrilir (uydurma veri
    // yok). Derinlik ve zemin artık "Bir Bakışta" şeridinde — burada tekrar
    // edilmez (tasarım 2026-08).
    final List<MaritimeStat> stats = <MaritimeStat>[
      ..._dimensionStats(t, detail.dimensions),
      ..._typeStats(t, detail.typeDetails),
    ];

    // 1) YAKLAŞMA NOTU açıklamadan ayrılır (turuncu uyarı kartı, onaylı B).
    final ApproachNoteSplit ap = splitApproachNote(detail.description);
    // 2) Demirleme tiplerinde kalan metin cümle cümle ayrıştırılır: zemin ve
    //    DİKKAT cümleleri "Demirleme Notları" kartına, koyu anlatan metin
    //    "Hakkında" kartına (ürün kararı 2026-07, 0-uydurma).
    final AnchorageDescriptionSplit? split =
        _isAnchoringType(detail.type) ? splitAnchorageDescription(ap.rest) : null;
    final String? about = split != null ? split.general : ap.rest;

    // TİP KİMLİĞİ (kullanıcı onayı 2026-08): haritadaki işaret rengi sayfanın
    // kimliği olur; ikon/etiketlerde temaya göre okunur tonu kullanılır.
    final Color ident = _identOf(detail.type);
    final Color ink = _identOnSurfaceOf(context, ident);

    // ÖNEM SIRASI (kullanıcı onayı 2026-08): kimlik → bir bakışta → güvenlik
    // uyarıları → demirleme notları → rota → DOLULUK → İLETİŞİM (yukarı
    // alındı: kaptan yer ayırtmak için önce arar) → denizci verileri →
    // olanak/hizmet → çalışma → hava → tanıtım metni → yorumlar → çevre.
    // İçerik birebir korunur; yalnız sıra ve giydirme değişti (taslak sözü).
    final Widget list = ListView(
      key: LocationDetailScreen.contentKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        // Fotoğraf varsa kapak kalır; kimlik kartı her durumda çizilir —
        // fotoğrafsız koylarda boş gri alan yerine dolu, profesyonel bir giriş.
        if (detail.media.cover != null) ...<Widget>[
          CoverPhoto(cover: detail.media.cover!),
          const SizedBox(height: 12),
        ],
        _HeroCard(detail: detail),
        _GlanceStrip(detail: detail),

        // RÜZGÂR UYARI BANDI (onaylı B): koyun açık yönünden eşik üstü rüzgâr
        // bekleniyorsa görünür; veri/tahmin yoksa hiç çizilmez. Uyarılar tip
        // rengine BOYANMAZ — güvenlik dili evrenseldir (taslak sözü).
        WindWarningBadge(
          exposedDirs: detail.windExposedDirs,
          position: detail.position,
        ),

        // YAKLAŞMA NOTU (onaylı B): açıklama içinde kaybolmaz, uyarı kartı olur.
        if (ap.note != null) _ApproachNoteCard(note: ap.note!),

        // Demirleme tiplerinde koya özel notlar kartı (zemin/derinlik/DİKKAT)
        // — güvenlik uyarılarının hemen ardından (önem sırası).
        if (split != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _AnchoringNotes(detail: detail, split: split, accent: ink),
          ),

        _SeaRouteRow(destination: detail.position, accent: ink),

        // DOLULUK yukarıda (kullanıcı isteği 2026-08): "yer var mı?" sorusu
        // sayfanın dibinde beklemez; DOLULUK BİLDİR düğmesi buradadır.
        // (Demirleme tiplerinde aynı düğme alttaki yapışkan çubukta.)
        if (occupancySupported(detail.type) && !_isAnchoringType(detail.type))
          OccupancyRow(idOrSlug: detail.id, position: detail.position),

        // İLETİŞİM yukarıda (kullanıcı isteği 2026-08): kaptan yer ayırtmak
        // için önce arar — tek dokunuş kutucukları rotadan hemen sonra.
        if (detail.contacts.isNotEmpty)
          SectionCard(
            icon: DocklyIcons.phone,
            title: t.sectionContact,
            accent: ink,
            child: _ContactTiles(contacts: detail.contacts, accent: ink),
          ),

        MaritimeInfoPanel(stats: stats, title: t.maritimeTitle, accent: ink),

        if (detail.amenities.isNotEmpty)
          SectionCard(
            icon: DocklyIcons.checkCircle,
            title: t.sectionAmenities,
            accent: ink,
            child: _IconChips(
              accent: ink,
              items: <(DocklyIconData, String)>[
                for (final AmenityLabeled a in detail.amenities)
                  (DocklyIcons.forAmenity(a.code), a.label),
              ],
            ),
          ),

        if (detail.services.isNotEmpty)
          SectionCard(
            icon: DocklyIcons.amTool,
            title: t.sectionServices,
            accent: ink,
            child: _IconChips(
              accent: ink,
              items: <(DocklyIconData, String)>[
                for (final ServiceLabeled s in detail.services)
                  (DocklyIcons.forAmenity(s.code), s.label),
              ],
            ),
          ),

        OperatingInfo(
          hours: detail.hours,
          seasons: detail.seasons,
          is24h: detail.is24h,
          accent: ink,
        ),

        // Rüzgâr & Hava — noktanın 48 saatlik tahmini (MET Norway, atıflı).
        WeatherCard(position: detail.position, accent: ink),

        // HAKKINDA aşağıda (önem sırası 2026-08): tanıtım metni, karar verdiren
        // verilerden sonra gelir — içerik aynen korunur.
        if (about != null && about.trim().isNotEmpty)
          SectionCard(
            icon: DocklyIcons.infoOutline,
            title: t.aboutTitle,
            accent: ink,
            child: Text(about, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          ),

        ReviewsSection(idOrSlug: detail.id, accent: ink),
        NearbyAlternatives(
          locationId: detail.id,
          position: detail.position,
          accent: ink,
        ),
      ],
    );

    // GENİŞ EKRAN (kullanıcı isteği 2026-08): bilgisayar/yatay iPad'de içerik
    // sütunu 760px'te sabitlenip ortalanır. Telefonda (≤840px) davranış aynı.
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth <= 840) {
          return list;
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: list,
          ),
        );
      },
    );

    // YAPIŞKAN EYLEM ÇUBUĞU (onaylı D): sayfanın neresinde olursa olsun ana
    // eylemler tek dokunuş uzağında.
    return Column(
      children: <Widget>[
        Expanded(child: content),
        _ActionBar(detail: detail),
      ],
    );
  }

  /// Boyut verisi → stat kartları. Derinlik BİLEREK dışarıda: "Bir Bakışta"
  /// şeridi gösteriyor (tekrar olmasın). Tekne boyu/su çekimi de tekne
  /// uygunluğu kutusunda.
  static List<MaritimeStat> _dimensionStats(L10n t, Dimensions d) {
    return <MaritimeStat>[
      if (d.capacity != null)
        MaritimeStat(icon: DocklyIcons.amMooring, value: '${d.capacity}', label: t.statCapacity),
    ];
  }

  /// Türe özel detay → stat kartları (yalnız dolu alanlar; switch EXPRESSION ile
  /// enum'lar üzerinde tam kapsama). Zemin (holdingType) "Bir Bakışta"da.
  static List<MaritimeStat> _typeStats(L10n t, TypeDetails? td) {
    if (td == null) return const <MaritimeStat>[];
    return switch (td) {
      MarinaTypeDetails m => <MaritimeStat>[
          if (m.berthCount != null)
            MaritimeStat(icon: DocklyIcons.amMooring, value: '${m.berthCount}', label: t.statBerths),
          if (m.vhfChannel != null)
            MaritimeStat(icon: DocklyIcons.radio, value: m.vhfChannel!, label: t.statVhf),
          if (m.hasBlueFlag == true)
            MaritimeStat(icon: DocklyIcons.verified, value: t.yesLabel, label: t.statBlueFlag),
          if (m.travelLiftCapacityTons != null)
            MaritimeStat(
              icon: DocklyIcons.amCrane,
              value: '${_num(m.travelLiftCapacityTons!)} ${t.tonUnit}',
              label: t.statTravelLift,
            ),
          if (m.winterStorage == true)
            MaritimeStat(icon: DocklyIcons.amTool, value: t.yesLabel, label: t.statWinter),
        ],
      FuelDockTypeDetails f => <MaritimeStat>[
          if (f.hasDiesel == true)
            MaritimeStat(icon: DocklyIcons.amFuel, value: t.yesLabel, label: t.statDiesel),
          if (f.hasGasoline == true)
            MaritimeStat(icon: DocklyIcons.amFuel, value: t.yesLabel, label: t.statGasoline),
          if (f.hasAdblue == true)
            MaritimeStat(icon: DocklyIcons.amFuel, value: t.yesLabel, label: t.statAdblue),
          if (f.minDepthM != null)
            MaritimeStat(
              icon: DocklyIcons.straighten,
              value: '${_num(f.minDepthM!)} m',
              label: t.statApproachDepth,
            ),
          if (f.paymentNote != null)
            MaritimeStat(icon: DocklyIcons.infoOutline, value: f.paymentNote!, label: t.statPayment),
        ],
      RestaurantDockTypeDetails r => <MaritimeStat>[
          if (r.cuisine != null)
            MaritimeStat(icon: DocklyIcons.amRestaurant, value: r.cuisine!, label: t.statCuisine),
          if (r.berthCountFree != null)
            MaritimeStat(
              icon: DocklyIcons.amMooring,
              value: '${r.berthCountFree}',
              label: t.statFreeBerths,
            ),
          if (r.minSpendPolicy != null)
            MaritimeStat(icon: DocklyIcons.infoOutline, value: r.minSpendPolicy!, label: t.statPolicy),
          if (r.reservationRecommended == true)
            MaritimeStat(
              icon: DocklyIcons.eventNote,
              value: t.recommendedLbl,
              label: t.statReservationLbl,
            ),
        ],
      AnchorageTypeDetails a => <MaritimeStat>[
          if (a.swellExposure != null)
            MaritimeStat(
              icon: DocklyIcons.sailing,
              value: a.swellExposure!,
              label: t.statSwell,
            ),
          MaritimeStat(
            icon: DocklyIcons.infoOutline,
            value: a.isFree ? t.freeChip : t.pricePaid,
            label: t.statPrice,
          ),
        ],
      UnknownTypeDetails() => const <MaritimeStat>[],
    };
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// A) KİMLİK KARTI — boş fotoğraf alanı yerine lacivert marka kartı: tip çipi
/// (+ doğrulanmış), ad, konum + KOPYALANABİLİR koordinat, rozetler (puan,
/// ücret, doluluk). Veri yoksa ilgili rozet hiç çizilmez.
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.detail});

  final LocationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    // TİP KİMLİĞİ (2026-08): kapak degradesi tipin rengini taşır — koyu
    // uçtan renge doğru sakin bir akış; beyaz metin her tipte okunur kalır
    // (açık renkler koyulaştırılmış tondan başlar).
    final Color ident = _identOf(detail.type);
    final Color ink = _identInkOf(ident);
    final Color heroEnd = Color.lerp(ink, ident, 0.45)!;
    final String coords =
        '${detail.position.lat.toStringAsFixed(4)}, ${detail.position.lon.toStringAsFixed(4)}';
    final String? locLine = _locationLine(detail.geo);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[ink, heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _TypeChip(
                icon: DocklyIcons.forLocationType(detail.type),
                label: t.typeLabel(detail.type),
              ),
              if (detail.verifiedAt != null)
                _TypeChip(icon: DocklyIcons.verified, label: t.verifiedLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          // Konum satırı + koordinat: koordinata dokunmak panoya kopyalar
          // (kaptan onu GPS cihazına/telsize geçirebilsin).
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (locLine != null)
                Text(
                  '$locLine ·',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () async {
                  // Kopyalama ipucu görevini tamamladı (tanıtım 2026-08).
                  ref
                      .read(onboardingControllerProvider.notifier)
                      .markHintSeen(kHintCoords);
                  await Clipboard.setData(ClipboardData(text: coords));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(t.coordsCopied)));
                },
                child: Text(
                  coords,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          // İLK-DOKUNUŞ İPUCU (tanıtım 2026-08): koordinat kopyalama tek
          // seferlik anlatılır; "Anladım" ya da ilk kopyalama kapatır.
          if (ref.watch(onboardingControllerProvider
              .select((OnboardingState s) => s.showHint(kHintCoords))))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        t.onbHintCoords,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => ref
                          .read(onboardingControllerProvider.notifier)
                          .markHintSeen(kHintCoords),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        child: Text(
                          t.onbGotIt,
                          style: const TextStyle(
                            // Koyu zeminde nötr vurgu (kimlikten bağımsız).
                            color: Color(0xFF7FE3D9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _HeroBadge(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const DocklyIcon(DocklyIcons.star, size: 14, color: DocklyColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      detail.rating.avg != null
                          ? '${detail.rating.avg!.toStringAsFixed(1)} (${detail.rating.count})'
                          : t.noRatingYet,
                      style: _badgeText,
                    ),
                  ],
                ),
              ),
              if (detail.priceTier == 'free' || detail.priceTier == 'paid')
                _HeroBadge(
                  child: Text(
                    detail.priceTier == 'free' ? t.freeChip : t.pricePaid,
                    style: _badgeText,
                  ),
                ),
              if (detail.is24h)
                const _HeroBadge(child: Text('7/24', style: _badgeText)),
              // DOLULUK (kullanıcı kararı 2026-07): veri yoksa rozet (boş hap
              // dahil) hiç çizilmez — tahmin yok.
              if ((ref.watch(occupancyOverridesProvider)[detail.id] ??
                      detail.occupancy) !=
                  null)
                _HeroBadge(
                  child: OccupancyChip(
                    idOrSlug: detail.id,
                    initial: detail.occupancy,
                    onDark: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _badgeText = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static String? _locationLine(GeoInfo geo) {
    final List<String> parts = <String>[];
    final AdminAreaRef? area = geo.adminArea;
    if (area != null) {
      parts.add(area.name);
      if (area.province != null && area.province != area.name) parts.add(area.province!);
    }
    if (geo.waterBody != null) parts.add(geo.waterBody!.name);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Kimlik kartındaki tip/doğrulanmış çipi — beyaz saydam hap: HER tip
/// renginin üstünde aynı kalitede okunur (tip kimliği 2026-08).
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.icon, required this.label});

  final DocklyIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DocklyIcon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kimlik kartı rozeti — yarı saydam beyaz hap.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

/// A) "BİR BAKIŞTA" ŞERİDİ — kaptanın demir atmadan önce ilk baktığı bilgiler:
/// derinlik, zemin, rüzgâra açık yönler, tekne uygunluğu. Yalnız verisi olan
/// kutular çizilir; tekne kutusuna dokunmak tekne tanımını açar.
class _GlanceStrip extends ConsumerWidget {
  const _GlanceStrip({required this.detail});

  final LocationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    // Tip kimlik mürekkebi (2026-08): kutular tipin temaya göre okunur tonu.
    final Color ink = _identOnSurfaceOf(context, _identOf(detail.type));
    final List<Widget> tiles = <Widget>[];

    final Dimensions d = detail.dimensions;
    if (d.depthMinM != null || d.depthMaxM != null) {
      tiles.add(_GlanceTile(
          label: t.statDepth,
          value: _range(d.depthMinM, d.depthMaxM),
          accent: ink));
    }

    final AnchorageTypeDetails? a = switch (detail.typeDetails) {
      final AnchorageTypeDetails x => x,
      _ => null,
    };
    if (a?.holdingType != null) {
      tiles.add(_GlanceTile(
          label: t.glanceSeabed,
          value: _capTr(t.holdingLabel(a!.holdingType!)),
          accent: ink));
    }

    final String? dirs = detail.windExposedDirs;
    if (dirs != null && dirs.trim().isNotEmpty) {
      final String value =
          dirs.split(',').map((String s) => s.trim()).where((String s) => s.isNotEmpty).join(', ');
      tiles.add(_GlanceTile(label: t.glanceOpenDir, value: value, accent: ink));
    }

    // Tekne uygunluğu: tekne tanımlıysa otomatik karşılaştırma; değilse
    // dokun-tanımla daveti. Limit verisi hiç yoksa kutu iddiada bulunmaz (—).
    final MyBoat? boat = ref.watch(myBoatProvider);
    final BoatFit fit = computeBoatFit(
      boat: boat,
      maxBoatLengthM: d.maxBoatLengthM,
      maxDraftM: d.maxDraftM,
    );
    final (String fitValue, Color? fitColor) = switch (fit) {
      BoatFit.fits => (t.fitShortYes, DocklyColors.success),
      BoatFit.tooBig => (t.fitShortNo, DocklyColors.error),
      BoatFit.unknown => ('—', null),
    };
    tiles.add(_GlanceTile(
      label: t.glanceBoat,
      value: fitValue,
      accent: ink,
      valueColor: fitColor,
      sub: boat == null
          ? t.boatDefineCta
          : '${_num(boat.lengthM)} m${boat.draftM != null ? ' · ${_num(boat.draftM!)} m' : ''}',
      onTap: () => showBoatSheet(context),
    ));

    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  static String _range(double? min, double? max) {
    if (min != null && max != null && min != max) return '${_num(min)}–${_num(max)} m';
    return '${_num((min ?? max)!)} m';
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Türkçe baş harf büyütme ("çamur" → "Çamur"; i→İ, ı→I kuralına saygılı).
  static String _capTr(String s) {
    if (s.isEmpty) return s;
    final String first = switch (s[0]) {
      'i' => 'İ',
      'ı' => 'I',
      final String c => c.toUpperCase(),
    };
    return first + s.substring(1);
  }
}

class _GlanceTile extends StatelessWidget {
  const _GlanceTile({
    required this.label,
    required this.value,
    this.accent,
    this.valueColor,
    this.sub,
    this.onTap,
  });

  final String label;
  final String value;

  /// Tip kimlik mürekkebi (2026-08): kutu zemini/etiketi bu tonu taşır.
  final Color? accent;

  final Color? valueColor;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    // Maritime stat kutularıyla aynı sabit boy (84) — 3 metin satırı + dolgu
    // gerçek tema metrikleriyle de rahat sığar (taşma payı geniş tutuldu).
    final double height = MediaQuery.textScalerOf(context).scale(84);
    final Widget inner = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        // Tip kimliği: yumuşak renkli zemin (%7 açık / %15 koyu tema).
        color: accent == null
            ? theme.colorScheme.surface
            : accent!.withValues(alpha: dark ? 0.15 : 0.07),
        border: Border.all(
          color: accent?.withValues(alpha: 0.32) ?? theme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (sub != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return inner;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: inner);
  }
}

/// B) YAKLAŞMA NOTU KARTI — güvenlik-kritik bilgi açıklama paragrafı içinde
/// kaybolmasın diye turuncu uyarı kartında (metin, doğrulanmış kaynaklardan
/// gelen notun kendisidir — 0-uydurma).
class _ApproachNoteCard extends ConsumerWidget {
  const _ApproachNoteCard({required this.note});

  final String note;

  /// Turuncu mürekkep: DocklyColors.warning zemin üstünde okunur koyu ton.
  static const Color _ink = Color(0xFFB45309);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DocklyColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: DocklyColors.warning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DocklyIcon(DocklyIcons.errorOutline, size: 18, color: _ink),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  t.approachTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(note, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deniz-rota önizleme bölümü (P2 → bölüm kartı, 2026-08). Yön (pusula + ok) +
/// kuşuçuşu deniz mili + kaba süre. Başlangıç (harita konumu) yoksa gizlenir.
/// ROTA ÇİZ eylemi artık yapışkan çubukta — her an erişilebilir.
class _SeaRouteRow extends ConsumerWidget {
  const _SeaRouteRow({required this.destination, this.accent});

  final GeoPoint destination;

  /// Tip kimlik mürekkebi (2026-08) — başlık madalyonu + pusula rozeti.
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final GeoPoint? origin = ref.watch(originProvider);
    if (origin == null) return const SizedBox.shrink();
    final SeaRoutePreview route = computeSeaRoute(origin, destination);
    if (route.distanceNm < 0.05) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final Color a = accent ?? DocklyColors.brandPrimary;
    return SectionCard(
      icon: DocklyIcons.navigation,
      title: t.routeSectionTitle,
      accent: accent,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: a.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Transform.rotate(
                angle: route.bearingDeg * math.pi / 180.0,
                child: DocklyIcon(DocklyIcons.navigation, size: 20, color: a),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(L10n.fmt(t.seaRouteFmt, route.compass), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  L10n.fmt2(t.seaRouteLineFmt, _fmtNm(route.distanceNm),
                      _fmtEta(t, route.etaHoursAtCruise)),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  t.seaRouteFrom,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtNm(double nm) => nm >= 10 ? nm.round().toString() : nm.toStringAsFixed(1);

String _fmtEta(L10n t, double hours) {
  if (!hours.isFinite) return '—';
  if (hours < 1) return '${(hours * 60).round()} ${t.minUnit}';
  int h = hours.floor();
  int m = ((hours - h) * 60).round();
  if (m == 60) {
    h += 1;
    m = 0;
  }
  return m == 0 ? '$h ${t.hourUnit}' : '$h ${t.hourUnit} $m ${t.minUnit}';
}

/// D) YAPIŞKAN EYLEM ÇUBUĞU — Deniz Rotası (birincil) + türe göre ikinci eylem:
/// demirleme tiplerinde Doluluk Bildir, diğerlerinde Rezervasyon Talebi.
/// Konum şartı haritayla aynıdır (kaptan kuralı): GPS yoksa rota başlamaz.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.detail});

  final LocationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final bool anchoring = _isAnchoringType(detail.type);
    // ROTA DÜZENLEME (2026-08): haritada rota ÇİZİLİYKEN bu sayfadan aynı
    // eylem "Durak ekle" olur — koy, rotaya en mantıklı sırayla eklenir.
    // Koy zaten rotadaysa düğme normal "Deniz rotası"na döner (yeniden kurar).
    final (bool hasRoute, bool inRoute) = ref.watch(
      mapControllerProvider.select(
        (MapState s) => (
          s.route != null,
          s.routeWaypoints.any((RouteWaypoint w) => w.id == detail.id),
        ),
      ),
    );
    final bool addStopMode = hasRoute && !inRoute;
    // Tip kimliği (2026-08): ana eylem düğmesi tipin rengini taşır. Beyaz
    // etiketin kontrastı 4.5:1'in altında kalacaksa (turkuaz/turuncu gibi
    // açık renkler) zemin koyulaştırılır — okunurluk her tipte garanti.
    final Color ident = _identOf(detail.type);
    final Color btnColor =
        (1.05 / (ident.computeLuminance() + 0.05)) < 4.5
            ? _identInkOf(ident)
            : ident;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: DocklyButton(
                      label: addStopMode ? t.routeAddStop : t.routeBtn,
                      icon: addStopMode ? DocklyIcons.place : DocklyIcons.navigation,
                      color: btnColor,
                      onPressed: addStopMode
                          ? () => _addStop(context, ref)
                          : () => _startRoute(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: anchoring
                        ? DocklyButton(
                            key: const ValueKey<String>('occupancy-report-button'),
                            label: t.occReportCta,
                            variant: DocklyButtonVariant.secondary,
                            onPressed: () => startOccupancyReport(
                              context,
                              ref,
                              idOrSlug: detail.id,
                              position: detail.position,
                            ),
                          )
                        : DocklyButton(
                            label: t.rezTitle,
                            variant: DocklyButtonVariant.secondary,
                            // ÜYELİK KAPISI (kullanıcı kararı 2026-07): talep
                            // göndermek hesap ister.
                            onPressed: () => requireAccount(
                              context,
                              ref,
                              message: t.gateReservationMsg,
                              onAllowed: () => showReservationSheet(
                                context,
                                locationName: detail.name,
                                contacts: detail.contacts,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Rota: aramadan/detaydan gelen kullanıcı haritaya dönüp işareti yeniden
  /// bulmak zorunda kalmasın — rota BURADAN istenir, harita rota çizili açılır.
  /// AKILLI ROTA (kullanıcı isteği 2026-08): konum paylaşılmamışsa izin
  /// OTOMATİK istenir; onay gelince rota kendiliğinden çizilir ve haritaya
  /// dönülür. İzin gelmezse başlangıç menüsü açılır.
  void _startRoute(BuildContext context, WidgetRef ref) {
    void backToMap() {
      if (context.mounted) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      }
    }

    startSeaRoute(
      context,
      ref,
      destPos: detail.position,
      destId: detail.id,
      destName: detail.name,
      afterPick: backToMap,
      onRouted: backToMap,
    );
  }

  /// Rota çiziliyken: bu koyu DURAK olarak ekler ve haritaya döner.
  void _addStop(BuildContext context, WidgetRef ref) {
    ref
        .read(mapControllerProvider.notifier)
        .addStop(detail.position, detail.id, detail.name);
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
  }
}

/// Olanak/hizmet çipleri — her biri tasarım sistemi denizcilik ikonuyla (docs/09,
/// design §03). İkon marka mavisi; çip kenarlığı temadan gelir.
class _IconChips extends StatelessWidget {
  const _IconChips({required this.items, this.accent});
  final List<(DocklyIconData, String)> items;

  /// Tip kimlik mürekkebi (2026-08): çip ikonları ve kenarları bu tonda.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color a = accent ?? DocklyColors.brandPrimary;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final (DocklyIconData icon, String label) in items)
          Chip(
            avatar: DocklyIcon(icon, size: 18, color: a),
            side: accent == null ? null : BorderSide(color: a.withValues(alpha: 0.35)),
            label: Text(label),
          ),
      ],
    );
  }
}

/// C) İLETİŞİM KUTUCUKLARI — satır listesi yerine tek dokunuş kutucukları:
/// Ara / WhatsApp / VHF / Web… Açılabilen türler dokununca çalışır (telefon ve
/// WhatsApp üyelik kapılı, kullanıcı kararı 2026-07); VHF gibi açılamayanlar
/// bilgi kutusu olarak durur. Numara/değer her zaman görünür (bilgi herkese açık).
class _ContactTiles extends StatelessWidget {
  const _ContactTiles({required this.contacts, this.accent});

  final List<Contact> contacts;

  /// Tip kimlik mürekkebi (2026-08) — kutucuk ikon madalyonları.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double gap = 8;
        final int perRow = contacts.length >= 3 ? 3 : contacts.length;
        final double width = perRow <= 1
            ? c.maxWidth
            : (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Contact contact in contacts)
              SizedBox(
                width: width,
                child: _ContactTile(contact: contact, accent: accent),
              ),
          ],
        );
      },
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.contact, this.accent});

  final Contact contact;

  /// Tip kimlik mürekkebi (2026-08).
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final Uri? uri = contactUri(contact.type, contact.value);
    final Widget inner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: (accent ?? DocklyColors.brandPrimary)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: DocklyIcon(_iconFor(contact.type),
                  size: 15, color: accent ?? DocklyColors.brandPrimary),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  contact.label ?? t.contactTypeLabel(contact.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (uri != null) ...<Widget>[
                const SizedBox(width: 3),
                DocklyIcon(DocklyIcons.openInNew,
                    size: 11, color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
          const SizedBox(height: 1),
          Text(
            contact.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    // Açılabilen türler tek dokunuşla çalışır. ÜYELİK KAPISI (kullanıcı kararı
    // 2026-07): marina/limanı DOĞRUDAN ARAMAK (telefon/WhatsApp) hesap ister;
    // değer görünür kalır, web/e-posta serbesttir.
    if (uri == null) return inner;
    final bool needsAccount =
        contact.type == 'phone' || contact.type == 'whatsapp';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (!needsAccount) {
          launchContact(context, contact.type, contact.value);
          return;
        }
        requireAccount(
          context,
          ref,
          message: ref.read(l10nProvider).gateCallMsg,
          onAllowed: () => launchContact(context, contact.type, contact.value),
        );
      },
      child: inner,
    );
  }

  static DocklyIconData _iconFor(String type) {
    switch (type) {
      case 'phone':
      case 'emergency':
        return DocklyIcons.phone;
      case 'whatsapp':
        return DocklyIcons.chat;
      case 'email':
        return DocklyIcons.email;
      case 'website':
        return DocklyIcons.language;
      case 'reservation_link':
        return DocklyIcons.openInNew;
      case 'vhf':
        return DocklyIcons.radio;
      case 'instagram':
      case 'facebook':
        return DocklyIcons.social;
      default:
        return DocklyIcons.infoOutline;
    }
  }
}

class _DetailError extends ConsumerWidget {
  const _DetailError({required this.message, required this.onRetry});

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
            // l10n (2026-08): sabit 'Tekrar dene' yerine ortak retryLabel.
            DocklyButton(
              label: ref.watch(l10nProvider).retryLabel,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paylaş düğmesi: '{ad} ({lat, lon}) — Koybul: https://koybul.com' metnini
/// panoya kopyalar ve kısa onay gösterir. (Gerçek paylaşım sayfası ve koy
/// bağlantıları, URL desteğiyle — Paket C — gelecek.)
class _ShareButton extends ConsumerWidget {
  const _ShareButton({required this.detail});

  final LocationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return IconButton(
      icon: const DocklyIcon(DocklyIcons.share),
      tooltip: t.shareTooltip,
      onPressed: () async {
        final String coords =
            '${detail.position.lat.toStringAsFixed(4)}, ${detail.position.lon.toStringAsFixed(4)}';
        await Clipboard.setData(
          ClipboardData(text: L10n.fmt2(t.shareLineFmt, detail.name, coords)),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.shareCopied)));
      },
    );
  }
}


/// Rezervasyonun ANLAMSIZ olduğu tipler: demirleme koyu, şamandıra, misafir
/// tonozu — buralarda ilk gelen demirler (ürün kararı, 2026-07).
bool _isAnchoringType(String type) =>
    type == 'mooring_point' || type == 'buoy' || type == 'guest_mooring';

/// "Demirleme Notları" — koya özel bilgi kutusu (ürün kararı 2026-07):
/// zemin (dip tutunması) + derinlik satırları ve açıklamadan ayrıştırılan
/// demirleme/DİKKAT cümleleri. UYDURMA VERİ YOK ilkesi: yalnız kayıtlı alanlar
/// ve açıklamada zaten var olan cümleler; koya özel veri hiç yoksa bunu
/// dürüstçe söyleyen tek satır kalır.
class _AnchoringNotes extends ConsumerWidget {
  const _AnchoringNotes({
    required this.detail,
    required this.split,
    this.accent,
  });

  final LocationDetail detail;
  final AnchorageDescriptionSplit split;

  /// Tip kimlik mürekkebi (2026-08) — başlık ikonu.
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final AnchorageTypeDetails? a = switch (detail.typeDetails) {
      final AnchorageTypeDetails t => t,
      _ => null,
    };
    final String? zemin =
        a?.holdingType == null ? null : _capTr(t.holdingLabel(a!.holdingType!));
    final String? depth = _depthText(detail.dimensions);
    final bool hasSpecific = zemin != null ||
        depth != null ||
        split.anchoring.isNotEmpty ||
        split.warnings.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DocklyIcon(DocklyIcons.amMooring,
                  size: 18, color: accent ?? theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(t.anchorTitle,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail.priceTier == 'free' ? t.anchorBaselineFree : t.anchorBaseline,
            style: theme.textTheme.bodyMedium,
          ),
          // Koya özel yapısal satırlar (yalnız kayıtlı alanlar).
          if (zemin != null)
            _NoteRow(icon: DocklyIcons.amMooring, text: L10n.fmt(t.anchorZeminFmt, zemin)),
          if (depth != null)
            _NoteRow(icon: DocklyIcons.straighten, text: L10n.fmt(t.anchorDepthFmt, depth)),
          // Açıklamadan taşınan demirleme/zemin cümleleri.
          for (final String s in split.anchoring)
            _NoteRow(icon: DocklyIcons.infoOutline, text: s),
          // DİKKAT cümleleri — uyarı renginde, vurgulu.
          for (final String s in split.warnings)
            _NoteRow(
              icon: DocklyIcons.errorOutline,
              text: s,
              color: DocklyColors.warning,
              emphasize: true,
            ),
          if (!hasSpecific) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              t.anchorFallback,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// Derinlik metni: "7–8 m" / "7 m" / null (veri yoksa satır çıkmaz).
  static String? _depthText(Dimensions d) {
    final double? min = d.depthMinM;
    final double? max = d.depthMaxM;
    if (min == null && max == null) return null;
    String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    if (min != null && max != null && min != max) return '${n(min)}–${n(max)} m';
    return '${n((min ?? max)!)} m';
  }

  /// Türkçe baş harf büyütme ("çamur" → "Çamur"; i→İ, ı→I kuralına saygılı).
  static String _capTr(String s) {
    if (s.isEmpty) return s;
    final String first = switch (s[0]) {
      'i' => 'İ',
      'ı' => 'I',
      final String c => c.toUpperCase(),
    };
    return first + s.substring(1);
  }
}

/// Demirleme Notları içindeki tek satır: küçük ikon + metin.
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    required this.text,
    this.color,
    this.emphasize = false,
  });

  final DocklyIconData icon;
  final String text;
  final Color? color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DocklyIcon(icon, size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
