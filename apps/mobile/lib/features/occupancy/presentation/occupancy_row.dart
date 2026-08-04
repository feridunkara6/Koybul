import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart' show AppFailure;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../auth/presentation/account_gate.dart';
import '../../route/domain/sea_route.dart';
import '../application/occupancy_controller.dart';

/// KONUM KURALI (kullanıcı kararı 2026-07): doluluk yalnız BULUNDUĞUN yerin
/// en yakın koyu ve çevresindeki koylar için bildirilebilir — yanlış bilgi
/// trafiğine karşı. İstemci eşiği 5 NM; sunucu aynı kuralı 6 NM ile
/// (GPS payı) ayrıca doğrular. Bildirim için konum paylaşımı ŞARTTIR.
const double occupancyMaxReportNm = 5.0;

/// Doluluk bildirimi yapılabilen türler (kullanıcı kararı 2026-07): yalnız
/// BAĞLANMA YERLERİ ve RESTORAN İSKELELERİ. Marina/limanda doluluğu işletme
/// bilir — kullanıcı bildirimi oralarda kapalıdır (sunucu da aynı kuralı
/// ayrıca denetler; iki katman).
const Set<String> occupancySupportedTypes = <String>{
  'mooring_point',
  'buoy',
  'guest_mooring',
  'restaurant_pier',
};

bool occupancySupported(String typeCode) =>
    occupancySupportedTypes.contains(typeCode);

/// Doluluk düzeyi renkleri: durum renkleriyle aynı dil (yeşil/turuncu/kırmızı).
Color occupancyColor(String level) {
  switch (level) {
    case 'empty':
      return DocklyColors.success;
    case 'moderate':
      return DocklyColors.warning;
    default:
      return DocklyColors.error;
  }
}

/// "x dk/sa önce" etiketi — dakika altı "az önce" olur; 6 saatlik pencere
/// aşımı zaten sunucuda elendiği için gün birimi gerekmez.
String occupancyAgo(L10n t, DateTime reportedAt, DateTime now) {
  final Duration d = now.difference(reportedAt);
  if (d.inMinutes < 1) return t.agoJustNow;
  if (d.inMinutes < 60) return L10n.fmt(t.agoMinFmt, d.inMinutes.toString());
  return L10n.fmt(t.agoHourFmt, d.inHours.toString());
}

/// Doluluk çipi — BAĞLAMA NOKTASI İŞARETİNİN yanında durur (kullanıcı kararı
/// 2026-07): detay sayfasında tip satırında, haritanın alt kartında tip
/// etiketinin yanında. Özet yoksa hiçbir şey çizmez (tahmin yok).
/// [compact] alt kart içindir: yalnız renkli nokta + düzey etiketi.
/// Bildirim sonrası yerel geçersiz kılma (occupancyOverridesProvider) HTTP
/// önbelleğini beklemeden çipi tazeler.
class OccupancyChip extends ConsumerWidget {
  const OccupancyChip({
    required this.idOrSlug,
    required this.initial,
    this.compact = false,
    this.onDark = false,
    this.now,
    super.key,
  });

  final String idOrSlug;
  final OccupancySummary? initial;
  final bool compact;

  /// Koyu zeminde (detay kimlik kartı, 2026-08) metin beyaz çizilir.
  final bool onDark;

  /// Saat kaynağı — testte sabitlenir; null → [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OccupancySummary? summary =
        ref.watch(occupancyOverridesProvider)[idOrSlug] ?? initial;
    if (summary == null) return const SizedBox.shrink();
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final Color color = occupancyColor(summary.level);
    final String label = compact
        ? t.occupancyLabel(summary.level)
        : L10n.fmt2(
            t.occChipFmt,
            t.occupancyLabel(summary.level),
            occupancyAgo(t, summary.reportedAt, (now ?? DateTime.now)()),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                ?.copyWith(
              fontWeight: FontWeight.w600,
              color: onDark ? Colors.white : null,
            ),
          ),
        ),
        if (!compact && summary.reportCount > 1) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            '(${L10n.fmt(t.occCountFmt, summary.reportCount.toString())})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Detay sayfasındaki "Doluluk bildir" eylemi — ana eylem bloğunun (Demirleme
/// Notları / Rezervasyon Talebi) hemen altında TAM GENİŞLİK ikincil düğme:
/// göz akışında, başparmak erişiminde ve ana eylemi gölgelemeyen profesyonel
/// bir konum. Bildirim YALNIZ buradan yapılır (alt kart salt gösterim).
/// Sıra: 1) konum paylaşılmış mı, 2) koy 5 NM içinde mi, 3) üyelik kapısı,
/// 4) düzey seçimi.
class OccupancyRow extends ConsumerWidget {
  const OccupancyRow({
    required this.idOrSlug,
    required this.position,
    super.key,
  });

  final String idOrSlug;

  /// Koyun konumu — bildirenin GPS'ine uzaklığı istemcide de denetlenir.
  final GeoPoint position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey<String>('occupancy-report-button'),
          icon: const DocklyIcon(DocklyIcons.social, size: 18),
          label: Text(t.occReportCta),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () =>
              startOccupancyReport(context, ref, idOrSlug: idOrSlug, position: position),
        ),
      ),
    );
  }
}

/// Doluluk bildirimi akışını başlatır — hem eski satır düğmesi hem yeni
/// yapışkan eylem çubuğu (detay yeniden tasarımı 2026-08) aynı akışı kullanır.
/// Sıra: 1) konum şartı, 2) 5 NM yakınlık, 3) üyelik kapısı, 4) düzey seçimi.
void startOccupancyReport(
  BuildContext context,
  WidgetRef ref, {
  required String idOrSlug,
  required GeoPoint position,
}) {
  final L10n t = ref.read(l10nProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  // 1) Konum şart: GPS paylaşılmamışsa yönlendir (harita merkezi SAYILMAZ —
  //    yanlış bilgi trafiğine karşı gerçek konum gerekir).
  final GeoPoint? gps = ref.read(devicePositionProvider);
  if (gps == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.occNeedLocation)));
    return;
  }
  // 2) Yakınlık: yalnız en yakın koy ve çevresi (5 NM).
  if (haversineNm(gps, position) > occupancyMaxReportNm) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.occTooFar)));
    return;
  }
  // 3) Üyelik kapısı → 4) düzey seçimi.
  requireAccount(
    context,
    ref,
    message: t.gateOccupancyMsg,
    onAllowed: () => _showReportSheet(context, ref, idOrSlug, gps),
  );
}

Future<void> _showReportSheet(
    BuildContext context, WidgetRef ref, String idOrSlug, GeoPoint gps) async {
  final String? level = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (_) => const OccupancySheetBody(),
  );
  if (level == null || !context.mounted) return;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final L10n t = ref.read(l10nProvider);
  try {
    await ref
        .read(occupancyOverridesProvider.notifier)
        .report(idOrSlug, level, gps);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.occReported)));
  } on AppFailure catch (f) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(f.message)));
  }
}

/// Doluluk bildirme alt sayfası — üç düzey, tek dokunuş. Testlerde doğrudan
/// bulunabilsin diye public.
class OccupancySheetBody extends ConsumerWidget {
  const OccupancySheetBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(t.occSheetTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final String level in <String>['empty', 'moderate', 'full'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(level),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: occupancyColor(level),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(t.occupancyLabel(level)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            t.occSheetNote,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
