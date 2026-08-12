import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/amenity_labels.dart' show kSearchAmenities;
import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_fit.dart';
import '../../boat/presentation/boat_sheet.dart';
import '../../detail/presentation/location_detail_screen.dart';
import '../application/search_controller.dart';
import '../application/search_view_options.dart';
import '../domain/search_state.dart';

/// Arama ekranı (S-07, docs/01-prd §6.13). Misafir: liman/koy/şehir adıyla arar,
/// sonuca dokununca detay açılır. Yazma eylemleri yok — tamamen misafir-dostu.
///
/// SEÇİM KİPİ (Faz 1): [pickDestination] true ise ekran "hedef seç" olarak
/// davranır — sonuca dokununca detay AÇILMAZ, seçilen kayıt geri döndürülür.
/// Haritadaki "Deniz rotası" düğmesi bunu kullanır: kullanıcı gitmek istediği
/// yeri pin arayarak değil, adıyla bulur.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.pickDestination = false, this.pickHint, super.key});

  /// Sonuç seçilince ekranı [LocationSummary] ile kapatır (detay açmaz).
  final bool pickDestination;

  /// Seçim kipinde arama kutusunun ipucu metni (verilmezse rota hedefi
  /// metni). Açılıştaki "bağlı marina seç" adımı kendi metnini geçer —
  /// kullanıcı rota planladığını sanmasın.
  final String? pickHint;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(searchControllerProvider).query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final SearchState state = ref.watch(searchControllerProvider);
    final LocationSearchController controller = ref.read(searchControllerProvider.notifier);
    final MyBoat? boat = ref.watch(myBoatProvider);

    // "Teknem sığar" açık ve tekne tanımlıysa: kesinlikle sığmayanları gizle.
    final List<LocationSummary> base = (state.boatFitOnly && boat != null)
        ? state.results
            .where((LocationSummary s) =>
                computeBoatFit(
                  boat: boat,
                  maxBoatLengthM: s.maxBoatLengthM,
                  maxDraftM: s.maxDraftM,
                ) !=
                BoatFit.tooBig)
            .toList(growable: false)
        : state.results;

    // İstemci-tarafı görünüm: "ücretsiz" süzgeci + sıralama (puan/yakınlık).
    final List<LocationSummary> visible = applySearchView(
      base,
      freeOnly: ref.watch(searchFreeOnlyProvider),
      sort: ref.watch(searchSortProvider),
      origin: ref.watch(originProvider),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onChanged: controller.onQueryChanged,
          decoration: InputDecoration(
            // Seçim kipinde ipucu metni ne yaptığımızı söyler; kullanıcı
            // arama ekranına yanlışlıkla düştüğünü sanmasın.
            hintText: widget.pickDestination
                ? (widget.pickHint ?? t.routePickTitle)
                : t.searchHint,
            border: InputBorder.none,
            suffixIcon: state.query.isEmpty
                ? const DocklyIcon(DocklyIcons.search)
                : IconButton(
                    icon: const DocklyIcon(DocklyIcons.clear),
                    tooltip: t.clearTooltip,
                    onPressed: () {
                      _ctrl.clear();
                      controller.onQueryChanged('');
                    },
                  ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: _FilterRow(),
        ),
      ),
      body: _SearchBody(
        state: state,
        results: visible,
        onRetry: () => controller.retry(),
        pickDestination: widget.pickDestination,
      ),
    );
  }
}

/// Arama kutusunun altında yatay kayan filtre çipleri: "Teknem sığar" (istemci
/// tarafı boat-fit) + tür çipleri (backend `type` filtresi). Boş seçim = tümü.
class _FilterRow extends ConsumerWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final SearchState state = ref.watch(searchControllerProvider);
    final LocationSearchController controller = ref.read(searchControllerProvider.notifier);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final List<String> types = DocklyMapColors.knownTypes.toList();
    final SearchSort sort = ref.watch(searchSortProvider);
    final bool freeOnly = ref.watch(searchFreeOnlyProvider);
    final GeoPoint? origin = ref.watch(originProvider);

    final List<Widget> chips = <Widget>[
      FilterChip(
        label: Text(t.fitChip),
        avatar: const DocklyIcon(DocklyIcons.sailing, size: 16),
        selected: state.boatFitOnly,
        // Tekne yoksa önce tanımlama sayfasını aç; varsa filtreyi aç/kapat.
        onSelected: (bool _) {
          if (boat == null) {
            showBoatSheet(context);
          } else {
            controller.toggleBoatFitOnly();
          }
        },
        visualDensity: VisualDensity.compact,
      ),
      // Ücretsiz süzgeci + sıralama (istemci tarafı).
      FilterChip(
        label: Text(t.freeChip),
        selected: freeOnly,
        onSelected: (bool _) =>
            ref.read(searchFreeOnlyProvider.notifier).state = !freeOnly,
        visualDensity: VisualDensity.compact,
      ),
      FilterChip(
        label: Text(t.sortRating),
        selected: sort == SearchSort.rating,
        onSelected: (bool _) => ref.read(searchSortProvider.notifier).state =
            sort == SearchSort.rating ? SearchSort.relevance : SearchSort.rating,
        visualDensity: VisualDensity.compact,
      ),
      // "Yakınıma göre" yalnız konum biliniyorsa anlamlı (Konumum alındıysa).
      if (origin != null)
        FilterChip(
          label: Text(t.sortNearby),
          selected: sort == SearchSort.distance,
          onSelected: (bool _) => ref.read(searchSortProvider.notifier).state =
              sort == SearchSort.distance ? SearchSort.relevance : SearchSort.distance,
          visualDensity: VisualDensity.compact,
        ),
      // GELİŞMİŞ ARAMA — olanak çipleri ("yakıtı olan" gibi; AND birleşir).
      // Metin yazmadan da çalışır: çip seçiliyse keşif modu aramayı koşar.
      for (final String a in kSearchAmenities)
        FilterChip(
          label: Text(t.amenityLabel(a)),
          selected: state.amenities.contains(a),
          onSelected: (bool _) => controller.toggleAmenity(a),
          avatar: DocklyIcon(DocklyIcons.forAmenity(a), size: 14),
          visualDensity: VisualDensity.compact,
        ),
      for (final String type in types)
        FilterChip(
          label: Text(t.typeLabel(type)),
          selected: state.types.contains(type),
          onSelected: (bool _) => controller.toggleType(type),
          avatar: DocklyIcon(DocklyIcons.circle, size: 12, color: DocklyMapColors.forType(type)),
          visualDensity: VisualDensity.compact,
        ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        // Test kimliği: çip şeridi yatay kaydırılabilir — testler dokunmadan
        // önce hedef çipi bu şeritte görünür konuma kaydırır (CI dersi).
        key: const ValueKey<String>('search-filter-row'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (BuildContext _, int __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) => Center(child: chips[i]),
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({
    required this.state,
    required this.results,
    required this.onRetry,
    required this.pickDestination,
  });

  final SearchState state;
  final List<LocationSummary> results;
  final VoidCallback onRetry;
  final bool pickDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    if (!state.canSearch) {
      return _Hint(icon: DocklyIcons.search, message: t.searchPrompt);
    }
    if (state.isLoading && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && results.isEmpty) {
      return _ErrorView(message: state.failure!.message, onRetry: onRetry);
    }
    if (state.hasSearched && !state.isLoading && state.failure == null && results.isEmpty) {
      return _Hint(icon: DocklyIcons.sailingOutlined, message: t.noResults);
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (BuildContext _, int __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) =>
          _ResultTile(item: results[i], pickDestination: pickDestination),
    );
  }
}

class _ResultTile extends ConsumerWidget {
  const _ResultTile({required this.item, required this.pickDestination});

  final LocationSummary item;
  final bool pickDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String subtitle = <String>[
      ref.watch(l10nProvider).typeLabel(item.type),
      if (_place(item) != null) _place(item)!,
    ].join(' · ');

    // Tekne-uyum rozeti: yalnız tekne tanımlıysa VE lokasyonun bilinen bir
    // limiti varsa gösterilir. Böylece kullanıcı listeye bakar bakmaz "teknem
    // sığar mı" görür (denizci-odaklı fark). Veri yoksa (unknown) rozet çıkmaz.
    final MyBoat? boat = ref.watch(myBoatProvider);
    final BoatFit fit = computeBoatFit(
      boat: boat,
      maxBoatLengthM: item.maxBoatLengthM,
      maxDraftM: item.maxDraftM,
    );
    final bool showFit = boat != null && fit != BoatFit.unknown;

    return ListTile(
      isThreeLine: showFit,
      leading: DocklyTypeAvatar(type: item.type),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (showFit) ...<Widget>[
            const SizedBox(height: 4),
            BoatFitBadge(fit: fit),
          ],
        ],
      ),
      trailing: item.ratingAvg != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const DocklyIcon(DocklyIcons.star, size: 16, color: DocklyColors.warning),
                const SizedBox(width: 2),
                Text(item.ratingAvg!.toStringAsFixed(1)),
              ],
            )
          : null,
      onTap: () {
        if (pickDestination) {
          // Seçim kipi: detay AÇMA, seçilen kaydı çağırana geri ver.
          Navigator.of(context).pop<LocationSummary>(item);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => LocationDetailScreen(idOrSlug: item.id),
          ),
        );
      },
    );
  }

  static String? _place(LocationSummary item) {
    final List<String> parts = <String>[];
    if (item.city != null) parts.add(item.city!);
    if (item.waterBodyName != null) parts.add(item.waterBodyName!);
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.message});

  final DocklyIconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DocklyIcon(icon, size: 48, color: DocklyColors.brandPrimary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
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
