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
import '../../auth/presentation/account_gate.dart';
import '../../boat/presentation/boat_fit.dart';
import '../../favorites/domain/favorite_location.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../location/application/location_controller.dart';
import '../../map/application/map_controller.dart';
import '../../nearby/presentation/nearby_alternatives.dart';
import '../../reservation/presentation/reservation_sheet.dart';
import '../../reviews/presentation/reviews_section.dart';
import '../../route/domain/sea_route.dart';
import '../../occupancy/presentation/occupancy_row.dart';
import '../application/location_detail_controller.dart';
import '../domain/anchorage_notes.dart';
import 'cover_photo.dart';
import 'maritime_info_panel.dart';
import '../../weather/presentation/weather_card.dart';
import '../../weather/presentation/wind_warning_badge.dart';
import 'operating_info.dart';

/// Lokasyon detay ekranı (S-09, docs/01-prd §6.6). Türe özel bölümleri,
/// olanakları, iletişimi ve boyut/kapasite verisini gösterir. Yazma eylemleri
/// (yorum, favori, talep) misafir modda kilitli — sonraki fazda bağlanacak.
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

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final LocationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    // Denizci bilgileri: boyut + türe özel veriden yalnız DOLU alanlar stat'a
    // çevrilir (uydurma veri yok). Tekne boyu/su çekimi zaten BoatFitRow'da
    // gösterildiği için burada tekrar edilmez.
    final List<MaritimeStat> stats = <MaritimeStat>[
      ..._dimensionStats(t, detail.dimensions),
      ..._typeStats(t, detail.typeDetails),
    ];

    // Demirleme tiplerinde açıklama cümle cümle ayrıştırılır: zemin/DİKKAT
    // cümleleri "Demirleme Notları" kartına taşınır, koyu anlatan metin
    // aşağıda açıklama olarak kalır (ürün kararı 2026-07, 0-uydurma).
    final AnchorageDescriptionSplit? split =
        _isAnchoringType(detail.type) ? splitAnchorageDescription(detail.description) : null;
    final String? descriptionBelow =
        split != null ? split.general : detail.description;

    final Widget content = ListView(
      key: LocationDetailScreen.contentKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        // Kapak: fotoğraf varsa onu, yoksa tasarımlı tip-renkli yer tutucu
        // göster (misafirin ilk gördüğü şey — sayfa hiç boş görünmesin, P0).
        if (detail.media.cover != null) ...<Widget>[
          CoverPhoto(cover: detail.media.cover!),
          const SizedBox(height: 14),
        ] else ...<Widget>[
          // Etiket YOK: tip zaten hemen altta gösteriliyor (tekrar olmasın).
          DocklyCoverPlaceholder(type: detail.type, title: detail.name),
          const SizedBox(height: 14),
        ],
        // Başlık bloğu
        Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: DocklyMapColors.forType(detail.type),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(t.typeLabel(detail.type), style: theme.textTheme.labelLarge),
            if (detail.verifiedAt != null) ...<Widget>[
              const SizedBox(width: 8),
              const DocklyIcon(DocklyIcons.verified, size: 16, color: DocklyColors.success),
            ],
            // DOLULUK ÇİPİ (kullanıcı kararı 2026-07): bağlama noktası
            // işaretinin hemen yanında; veri yoksa görünmez.
            const SizedBox(width: 10),
            Flexible(
              child: OccupancyChip(idOrSlug: detail.id, initial: detail.occupancy),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Fotoğraf varsa isim burada (H1); yer tutucu "hero" kullanılıyorsa isim
        // zaten kapağın üstünde, tekrar etmemek için gizlenir.
        if (detail.media.cover != null)
          Text(detail.name, style: theme.textTheme.headlineSmall),
        if (_locationLine(detail.geo) != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(_locationLine(detail.geo)!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            const DocklyIcon(DocklyIcons.star, size: 18, color: DocklyColors.warning),
            const SizedBox(width: 4),
            Text(
              detail.rating.avg != null
                  ? '${detail.rating.avg!.toStringAsFixed(1)} (${detail.rating.count})'
                  : t.noRatingYet,
            ),
            const SizedBox(width: 12),
            if (detail.priceTier == 'free' || detail.priceTier == 'paid')
              _Pill(label: detail.priceTier == 'free' ? t.freeChip : t.pricePaid),
            if (detail.is24h) ...<Widget>[
              const SizedBox(width: 8),
              const _Pill(label: '7/24'),
            ],
          ],
        ),

        // RÜZGÂR UYARI ROZETİ (2026-07 ②): koyun açık yönünden bugün eşik
        // üstü rüzgâr bekleniyorsa görünür; veri/tahmin yoksa hiç çizilmez.
        WindWarningBadge(
          exposedDirs: detail.windExposedDirs,
          position: detail.position,
        ),

        const SizedBox(height: 12),
        BoatFitRow(
          maxBoatLengthM: detail.dimensions.maxBoatLengthM,
          maxDraftM: detail.dimensions.maxDraftM,
        ),
        _SeaRouteRow(destination: detail.position, idOrSlug: detail.id),

        const SizedBox(height: 14),
        // ÜRÜN KARARI: demirleme yerlerinde (koy/şamandıra/tonoz) rezervasyon
        // OLMAZ — ilk gelen demirler. Bu tiplerde talep düğmesi yerine
        // "Demirleme Notları" gösterilir; diğer tiplerde düğme kalır.
        if (split != null)
          _AnchoringNotes(detail: detail, split: split)
        else
          SizedBox(
            width: double.infinity,
            child: DocklyButton(
              label: t.rezTitle,
              icon: DocklyIcons.eventNote,
              // ÜYELİK KAPISI (kullanıcı kararı 2026-07): talep göndermek
              // hesap ister; hesabı olmayana kayıt yolu gösterilir.
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
        // DOLULUK BİLDİR (kullanıcı kararı 2026-07): yalnız bağlanma yerleri
        // ve restoran iskelelerinde, ana eylemin hemen altında tam genişlik
        // ikincil düğme. Marina/limanda bu özellik KAPALI.
        if (occupancySupported(detail.type))
          OccupancyRow(idOrSlug: detail.id, position: detail.position),

        if (descriptionBelow != null && descriptionBelow.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(descriptionBelow, style: theme.textTheme.bodyLarge),
        ],

        MaritimeInfoPanel(stats: stats, title: t.maritimeTitle),

        if (detail.amenities.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(t.sectionAmenities),
          const SizedBox(height: 8),
          _IconChips(
            items: <(DocklyIconData, String)>[
              for (final AmenityLabeled a in detail.amenities)
                (DocklyIcons.forAmenity(a.code), a.label),
            ],
          ),
        ],

        if (detail.services.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(t.sectionServices),
          const SizedBox(height: 8),
          _IconChips(
            items: <(DocklyIconData, String)>[
              for (final ServiceLabeled s in detail.services)
                (DocklyIcons.forAmenity(s.code), s.label),
            ],
          ),
        ],

        OperatingInfo(
          hours: detail.hours,
          seasons: detail.seasons,
          is24h: detail.is24h,
        ),

        // Rüzgâr & Hava — noktanın 48 saatlik tahmini (MET Norway, atıflı).
        WeatherCard(position: detail.position),

        if (detail.contacts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(t.sectionContact),
          const SizedBox(height: 6),
          for (final Contact c in detail.contacts) _ContactRow(contact: c),
        ],

        ReviewsSection(idOrSlug: detail.id),
        NearbyAlternatives(locationId: detail.id, position: detail.position),
      ],
    );
    // GENİŞ EKRAN (kullanıcı isteği 2026-08): bilgisayar/yatay iPad'de içerik
    // sütunu 760px'te sabitlenip ortalanır — kapak görsel alanı ekranı
    // kaplamaz (16:9 × 760 = ~427px), satırlar okunur genişlikte kalır.
    // Telefonda (≤840px) davranış değişmez.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth <= 840) {
          return content;
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: content,
          ),
        );
      },
    );
  }

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

  /// Boyut verisi → stat kartları. Tekne boyu & su çekimi bilerek DIŞARIDA:
  /// onları BoatFitRow zaten üstte gösteriyor (tekrar olmasın).
  static List<MaritimeStat> _dimensionStats(L10n t, Dimensions d) {
    return <MaritimeStat>[
      if (d.depthMinM != null || d.depthMaxM != null)
        MaritimeStat(
          icon: DocklyIcons.straighten,
          value: _range(d.depthMinM, d.depthMaxM),
          label: t.statDepth,
        ),
      if (d.capacity != null)
        MaritimeStat(icon: DocklyIcons.amMooring, value: '${d.capacity}', label: t.statCapacity),
    ];
  }

  /// Türe özel detay → stat kartları (yalnız dolu alanlar; switch EXPRESSION ile
  /// enum'lar üzerinde tam kapsama).
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
          if (a.holdingType != null)
            MaritimeStat(
              icon: DocklyIcons.amMooring,
              value: t.holdingLabel(a.holdingType!),
              label: t.statHolding,
            ),
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

  static String _range(double? min, double? max) {
    if (min != null && max != null) return '${_num(min)}–${_num(max)} m';
    return '${_num((min ?? max)!)} m';
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Deniz-rota önizlemesi (P2, docs vizyon — denizcilik-odaklı rota, karayolu YOK).
/// Başlangıç noktası (harita merkezi) biliniyorsa: yön (pusula + ok) + kuşuçuşu
/// deniz mili + kaba süre. Başlangıç yoksa gizlenir.
class _SeaRouteRow extends ConsumerWidget {
  const _SeaRouteRow({required this.destination, required this.idOrSlug});

  final GeoPoint destination;
  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final GeoPoint? origin = ref.watch(originProvider);
    if (origin == null) return const SizedBox.shrink();
    final SeaRoutePreview route = computeSeaRoute(origin, destination);
    if (route.distanceNm < 0.05) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: DocklyColors.brandPrimary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Transform.rotate(
              angle: route.bearingDeg * math.pi / 180.0,
              child: const DocklyIcon(DocklyIcons.navigation, color: DocklyColors.brandPrimary),
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
                  const SizedBox(height: 10),
                  // ROTA ÇİZ (UX 2026-08): aramadan gelen kullanıcı haritaya
                  // dönüp işareti yeniden bulmak zorunda kalmasın — rota
                  // BURADAN istenir, harita rota çizili olarak açılır.
                  // Konum şartı haritayla aynıdır (kaptan kuralı).
                  SizedBox(
                    width: double.infinity,
                    child: DocklyButton(
                      label: t.routeBtn,
                      icon: DocklyIcons.navigation,
                      variant: DocklyButtonVariant.secondary,
                      onPressed: () {
                        if (ref.read(devicePositionProvider) == null) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: Text(t.routeNeedOrigin),
                              duration: const Duration(seconds: 6),
                              action: SnackBarAction(
                                label: t.locateTooltip,
                                onPressed: () => ref
                                    .read(locationControllerProvider.notifier)
                                    .locateMe(),
                              ),
                            ));
                          return;
                        }
                        // Hesap arka planda başlar; kullanıcı haritaya döner,
                        // rota + mesafe/süre çipi orada belirir.
                        ref
                            .read(mapControllerProvider.notifier)
                            .routeTo(destination, idOrSlug);
                        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// Olanak/hizmet çipleri — her biri tasarım sistemi denizcilik ikonuyla (docs/09,
/// design §03). İkon marka mavisi; çip kenarlığı temadan gelir.
class _IconChips extends StatelessWidget {
  const _IconChips({required this.items});
  final List<(DocklyIconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final (DocklyIconData icon, String label) in items)
          Chip(
            avatar: DocklyIcon(icon, size: 18, color: DocklyColors.brandPrimary),
            label: Text(label),
          ),
      ],
    );
  }
}

class _ContactRow extends ConsumerWidget {
  const _ContactRow({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String? label = contact.label;
    final Uri? uri = contactUri(contact.type, contact.value);
    final Widget valueWidget = label == null
        ? Text(contact.value)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(contact.value),
            ],
          );
    final Widget inner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          DocklyIcon(_iconFor(contact.type), size: 18, color: DocklyColors.brandPrimary),
          const SizedBox(width: 10),
          Expanded(child: valueWidget),
          if (uri != null)
            DocklyIcon(DocklyIcons.openInNew,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
    // Açılabilen türler (telefon/WhatsApp/web/e-posta) tek dokunuşla çalışır;
    // VHF gibi açılamayanlar düz metin kalır. ÜYELİK KAPISI (kullanıcı kararı
    // 2026-07): marina/limanı DOĞRUDAN ARAMAK (telefon/WhatsApp) hesap ister;
    // numara görünür kalır, web/e-posta serbesttir. Acil Durum sayfası kapı
    // dışıdır (güvenlik).
    if (uri == null) return inner;
    final bool needsAccount =
        contact.type == 'phone' || contact.type == 'whatsapp';
    return InkWell(
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: DocklyColors.brandPrimary),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: DocklyColors.brandPrimary),
      ),
    );
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

/// "Demirleme Notları" — rezervasyon düğmesinin yerini alan bilgi kutusu.
/// Sabit metin yerine KOYA ÖZEL veri gösterir (ürün kararı 2026-07):
/// zemin (dip tutunması) + derinlik satırları ve açıklamadan ayrıştırılan
/// demirleme/DİKKAT cümleleri. UYDURMA VERİ YOK ilkesi: yalnız kayıtlı alanlar
/// ve açıklamada zaten var olan cümleler; koya özel veri hiç yoksa bunu
/// dürüstçe söyleyen tek satır kalır.
class _AnchoringNotes extends ConsumerWidget {
  const _AnchoringNotes({required this.detail, required this.split});

  final LocationDetail detail;
  final AnchorageDescriptionSplit split;

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
              DocklyIcon(DocklyIcons.amMooring, size: 18, color: theme.colorScheme.primary),
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
