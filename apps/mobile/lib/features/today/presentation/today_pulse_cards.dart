import 'package:dockly_api/dockly_api.dart'
    show EventView, MarinaCommunity, QaFeed, QaQuestionSummary, SharedRouteSummary;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../boat/application/maintenance_controller.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/data/maintenance_catalog.dart';
import '../../boat/domain/maintenance.dart';
import '../../boat/domain/my_boat.dart';
import '../../events/application/events_controller.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../marina/application/marina_controller.dart';
import '../../community/presentation/reputation_shell.dart' show formatNm;
import '../../qa/application/qa_controller.dart';
import '../../qa/presentation/qa_list_screen.dart';
import '../../route/application/shared_routes_controller.dart';
import '../../route/presentation/shared_route_detail_screen.dart';
import '../../route/presentation/shared_routes_screen.dart';
import '../../shell/application/shell_tab_provider.dart';

/// BUGÜN — GÜNÜN NABZI kartları (K2 DENGELİ, kurucu onayı 2026-10-23).
///
/// Ana sayfa kararı: Keşfet açılış olarak kalır; Bugün sekmesi "günün nabzı"
/// olur — hava bloğunun ALTINA, öneri bölümünün ÜSTÜNE dört kompakt kart
/// gelir: MARİNAM, bakım uyarısı, Soru-Cevap, yaklaşan etkinlik.
///
/// DÜRÜSTLÜK KURALLARI:
/// - Hepsi MEVCUT sağlayıcılardan beslenir — bu dosya yeni uç açmaz.
/// - Verisi olmayan kart kendini HİÇ çizmez (boş iskelet/uydurma yok);
///   yüklenme ve hata durumları da sessizdir — Bugün ekranı dönen
///   çemberlerle dolmaz, içerik geldiğinde kart belirir.
/// - Kartlar birer KÖPRÜDÜR: veri ve kurallar kendi evlerinde yaşar
///   (Teknem/Marinam kartı, Soru-Cevap listesi, etkinlik detayı).

/// Teknem sekmesinin kabuk içindeki sırası (dockly_shell ile aynı sözlük).
const int _kBoatTabIndex = 3;

/// MARİNAM köprüsü — üç dürüst durum:
/// 1) hesap yok → ücretsiz hesap daveti (giriş sayfası açılır);
/// 2) marina seçilmemiş → Teknem'e davet (marina orada seçilir);
/// 3) marina bağlı → marina adı + sunucudaki KAYITLI TEKNE sayısı
///    (sayı herkese açık uçtan gelir; gelmediyse nötr alt başlık yazılır,
///    sayı UYDURULMAZ).
class TodayMarinamCard extends ConsumerWidget {
  const TodayMarinamCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool member = auth is Authenticated && !auth.isGuest;
    final MyBoat? boat = ref.watch(myBoatProvider);
    final HomeMarina? marina = boat?.homeMarina;

    if (!member) {
      return _PulseCard(
        keyValue: 'today-marinam-signin',
        emoji: '🏠',
        caption: t.marinamTitle,
        title: t.tdMarinamGuest,
        onTap: () => showSignInSheet(context),
      );
    }
    if (marina == null) {
      return _PulseCard(
        keyValue: 'today-marinam-pick',
        emoji: '🏠',
        caption: t.marinamTitle,
        title: t.tdMarinamPick,
        onTap: () => ref.read(shellTabProvider.notifier).state = _kBoatTabIndex,
      );
    }
    final AsyncValue<MarinaCommunity> community =
        ref.watch(marinaCommunityProvider(marina.id));
    final int? total = community.valueOrNull?.total;
    return _PulseCard(
      keyValue: 'today-marinam',
      emoji: '🏠',
      caption: t.marinamTitle,
      title: marina.name,
      subtitle: total != null
          ? L10n.fmt(t.tdMarinamCountFmt, '$total')
          : t.marinamSub,
      onTap: () => ref.read(shellTabProvider.notifier).state = _kBoatTabIndex,
    );
  }
}

/// BAKIM UYARI ŞERİDİ — yalnız ilgi bekleyen kalem VARKEN çizilir
/// (Teknem'deki özetle AYNI sayım kuralı: "kayıt yok" ilgi beklemez —
/// kaptan girmediyse uygulama bir şey iddia etmez). Dokunuş Teknem'e götürür.
class TodayMaintStrip extends ConsumerWidget {
  const TodayMaintStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<MaintenanceTask> tasks =
        maintenanceCatalog(ref.watch(appLocaleProvider));
    ref.watch(maintenanceProvider);
    final MaintenanceController ctrl = ref.read(maintenanceProvider.notifier);
    final DateTime now = DateTime.now();
    int needsAttention = 0;
    for (final MaintenanceTask task in tasks) {
      final MaintenanceStatus s =
          maintenanceStatus(task, ctrl.recordFor(task.id), now: now);
      if (s == MaintenanceStatus.overdue || s == MaintenanceStatus.dueSoon) {
        needsAttention++;
      }
    }
    if (needsAttention == 0) return const SizedBox.shrink();
    return _PulseCard(
      keyValue: 'today-maint',
      emoji: '🔧',
      caption: t.maintTitle,
      title: L10n.fmt(t.maintSummaryFmt, '$needsAttention'),
      warning: true,
      onTap: () => ref.read(shellTabProvider.notifier).state = _kBoatTabIndex,
    );
  }
}

/// "ÇEVRENDE OLANLAR" başlığı (Sosyalleşme Hafta 4, Konsept 2 — kurucu
/// onayı 2026-10-24): topluluk köprülerini (rota + soru + etkinlik) tek
/// başlık altında toplar; sağdaki "tümü" Rota Keşfi'ni açar.
class TodayCommunityHeader extends ConsumerWidget {
  const TodayCommunityHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              t.tdCommunityCap.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey<String>('today-community-all'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const SharedRoutesScreen()),
            ),
            child: Text('${t.tdCommunityAll} ›'),
          ),
        ],
      ),
    );
  }
}

/// ROTA köprüsü (Hafta 4) — topluluğun EN YENİ onaylı rotası. Akış boş ya da
/// ulaşılamazsa kart kendini çizmez (0-uydurma; dönen çember yok).
class TodayRouteCard extends ConsumerWidget {
  const TodayRouteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<SharedRouteSummary>? routes =
        ref.watch(sharedRoutesFeedProvider('new')).valueOrNull;
    if (routes == null || routes.isEmpty) return const SizedBox.shrink();
    final SharedRouteSummary r = routes.first;
    return _PulseCard(
      keyValue: 'today-route',
      emoji: '🧭',
      caption: t.rtDiscoverTitle,
      title: r.name,
      subtitle:
          '${r.startName} → ${r.endName} · ${formatNm(t, r.distanceNm)} nm',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => SharedRouteDetailScreen(routeId: r.id)),
      ),
    );
  }
}

/// SORU-CEVAP köprüsü — akıştan TEK soru: öne çıkan varsa o, yoksa en yenisi.
/// Akış boş/yüklenmemiş/hatalıysa kart çizilmez. Dokunuş listeyi açar.
class TodayQaCard extends ConsumerWidget {
  const TodayQaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final QaFeed? feed = ref.watch(qaFeedProvider(null)).valueOrNull;
    if (feed == null) return const SizedBox.shrink();
    final List<QaQuestionSummary> all =
        <QaQuestionSummary>[...feed.featured, ...feed.items];
    if (all.isEmpty) return const SizedBox.shrink();
    final QaQuestionSummary q = all.first;
    return _PulseCard(
      keyValue: 'today-qa',
      emoji: '💬',
      caption: t.qaRowTitle,
      title: q.title,
      subtitle: L10n.fmt(t.qaAnswersFmt, '${q.answersCount}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QaListScreen()),
      ),
    );
  }
}

/// YAKLAŞAN ETKİNLİK köprüsü — iptal edilmemiş, başlamamış en yakın etkinlik.
/// Böylesi yoksa kart çizilmez (geçmiş/iptal etkinlik ana sayfaya taşınmaz;
/// dürüst tam liste Etkinlikler ekranındadır). Dokunuş detayı açar.
class TodayEventCard extends ConsumerWidget {
  const TodayEventCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final List<EventView>? events =
        ref.watch(eventsFeedProvider).valueOrNull;
    if (events == null) return const SizedBox.shrink();
    final DateTime now = DateTime.now();
    final List<EventView> upcoming = events
        .where((EventView e) => !e.cancelled && e.startsAt.isAfter(now))
        .toList()
      ..sort((EventView a, EventView b) => a.startsAt.compareTo(b.startsAt));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final EventView e = upcoming.first;
    return _PulseCard(
      keyValue: 'today-event',
      emoji: '📅',
      caption: t.tdEventCap,
      title: e.title,
      subtitle: '${formatEventMoment(e.startsAt)} · ${e.locationText}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => EventDetailScreen(eventId: e.id)),
      ),
    );
  }
}

/// Ortak kompakt kart: emoji + küçük başlık + içerik (+ alt satır) + ok.
/// Bugün'ün kart ailesiyle aynı dil (SectionCard yüzeyi); uyarı modunda
/// amber tonlanır (tema kuralı: uyarı her ekranda uyarı rengindedir).
class _PulseCard extends StatelessWidget {
  const _PulseCard({
    required this.keyValue,
    required this.emoji,
    required this.caption,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.warning = false,
  });

  final String keyValue;
  final String emoji;
  final String caption;
  final String title;
  final String? subtitle;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Material(
        color: warning
            ? DocklyColors.warning.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey<String>(keyValue),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: warning
                    ? DocklyColors.warning.withValues(alpha: 0.45)
                    : theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        caption.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: warning
                              ? const Color(0xFF92400E)
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                DocklyIcon(DocklyIcons.arrowForward,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
