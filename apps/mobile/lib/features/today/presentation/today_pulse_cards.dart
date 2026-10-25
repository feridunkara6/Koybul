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
import '../../events/presentation/events_screen.dart';
import '../../marina/application/marina_controller.dart';
import '../../marina/presentation/marina_community_screen.dart';
import '../../community/presentation/reputation_shell.dart' show formatNm;
import '../../qa/application/qa_controller.dart';
import '../../qa/presentation/qa_composer_screen.dart';
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

/// TOPLULUK ŞERİDİ (UX keşfedilebilirlik paketi, kurucu onayı 2026-10-25):
/// dört kalıcı kısayol — Soru-Cevap · Rotalar · Etkinlik · Marinam.
///
/// Köprü kartlarından farkı BİLİNÇLİDİR: şerit veriye bakmaz ve HER ZAMAN
/// görünür. İçerik yokken bile özelliklerin kapısı ortada durur (analiz
/// bulgusu: veri-koşullu köprüler, tanıtıma en çok ihtiyaç duyulan boş
/// dönemde kayboluyordu). İçerik iddiası taşımadığı için 0-uydurma kuralını
/// da ihlal etmez — bunlar kapı, kart değil.
class TodayCommunityStrip extends ConsumerWidget {
  const TodayCommunityStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final HomeMarina? marina = ref.watch(myBoatProvider)?.homeMarina;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: <Widget>[
          _StripButton(
            keyValue: 'ts-qa',
            emoji: '💬',
            label: t.tsQa,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QaListScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _StripButton(
            keyValue: 'ts-routes',
            emoji: '🧭',
            label: t.tsRoutes,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const SharedRoutesScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _StripButton(
            keyValue: 'ts-events',
            emoji: '📅',
            label: t.tsEvents,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _StripButton(
            keyValue: 'ts-marina',
            emoji: '🏠',
            label: t.tsMarina,
            // Marina bağlıysa topluluk ekranı doğrudan açılır; değilse
            // Teknem'e götürür (marina orada seçilir — Marinam kartı kuralı).
            onTap: marina != null
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              MarinaCommunityScreen(marinaId: marina.id)),
                    )
                : () => ref.read(shellTabProvider.notifier).state =
                    _kBoatTabIndex,
          ),
        ],
      ),
    );
  }
}

/// Şerit düğmesi: emoji + kısa etiket; turkuaz çerçeveli ince kapı.
class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.keyValue,
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String keyValue;
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: ValueKey<String>(keyValue),
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: DocklyColors.accentTurquoise.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DocklyColors.accentTurquoise,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
            // BELİRGİN DÜĞME (UX paketi P2, 2026-10-25): silik "tümü" yazısı
            // hap zeminli "Tümünü gör" oldu — Rota Keşfi'nin kapısı görünsün.
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor:
                  DocklyColors.brandPrimary.withValues(alpha: 0.08),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
/// Yüklenmemiş/hatalıysa kart çizilmez. AKIŞ BOŞSA kaybolmak yerine dürüst
/// bir DAVET kartına dönüşür (UX paketi, kurucu onayı 2026-10-25): sahte
/// içerik yazılmaz, yalnız "ilk soruyu sor" çağrısı yapılır — özellik,
/// tanıtıma en çok ihtiyaç duyduğu boş dönemde de kapısını gösterir.
class TodayQaCard extends ConsumerWidget {
  const TodayQaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final QaFeed? feed = ref.watch(qaFeedProvider(null)).valueOrNull;
    if (feed == null) return const SizedBox.shrink();
    final List<QaQuestionSummary> all =
        <QaQuestionSummary>[...feed.featured, ...feed.items];
    if (all.isEmpty) return const _QaInviteCard();
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

/// SORU DAVET KARTI — akış yüklendi ama hiç onaylı soru yok. Karta dokunmak
/// listeyi (boş hâliyle, dürüst) açar; düğme doğrudan soru yazmaya götürür.
/// Premium/hesap kapıları her zamanki evlerinde: sunucuda ve composer'da.
class _QaInviteCard extends ConsumerWidget {
  const _QaInviteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    const Color turq = DocklyColors.accentTurquoise;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Material(
        color: turq.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey<String>('today-qa-invite'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const QaListScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: turq.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('💬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.qaInviteTitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t.qaInviteSub,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey<String>('today-qa-invite-btn'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: turq,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const QaComposerScreen()),
                  ),
                  child: Text(t.qaAskCta),
                ),
              ],
            ),
          ),
        ),
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
