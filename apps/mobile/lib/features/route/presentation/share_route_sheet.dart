import 'package:dockly_core/dockly_core.dart' show AppFailure;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/shared_routes_controller.dart';
import '../domain/saved_route.dart';
import '../domain/sea_route.dart' show etaHours;
import '../domain/sea_trip.dart';

/// ROTAYI PAYLAŞ akışı (Sosyalleşme Hafta 3, kurucu onayı 2026-10-24) —
/// Defter'deki kayıtlı rotadan topluluk rotası üretir.
///
/// DÜRÜSTLÜK KURALLARI:
/// - Yalnız KATALOG kimliği taşıyan duraklar paylaşılır (serbest nokta ve
///   "Konumum" başlangıcı PAYLAŞILMAZ — konum sızmaz). En az 2 durak şart.
/// - Mesafe/süre uygulamanın hesabıdır; kullanıcı elle yazamaz.
/// - Gönderim moderasyon onayına düşer; kullanıcıya açıkça söylenir.
Future<void> openShareRouteSheet(BuildContext context, SavedRoute route) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext _) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ShareRouteSheetBody(route: route),
    ),
  );
}

/// Kayıtlı rotadan paylaşılabilir durak kimlikleri: ardışık tekrarlar
/// ayıklanır (sunucu kuralıyla aynı). Testlenebilir saf fonksiyon.
List<String> shareableStopIds(SavedRoute route) {
  final List<String> ids = <String>[];
  for (final RouteWaypoint w in route.waypoints) {
    final String? id = w.id;
    if (id == null) continue; // serbest nokta paylaşılmaz
    if (ids.isNotEmpty && ids.last == id) continue; // ardışık tekrar
    ids.add(id);
  }
  return ids;
}

class ShareRouteSheetBody extends ConsumerStatefulWidget {
  const ShareRouteSheetBody({required this.route, super.key});

  final SavedRoute route;

  @override
  ConsumerState<ShareRouteSheetBody> createState() =>
      _ShareRouteSheetBodyState();
}

class _ShareRouteSheetBodyState extends ConsumerState<ShareRouteSheetBody> {
  late final TextEditingController _name =
      TextEditingController(text: widget.route.name);
  final TextEditingController _body = TextEditingController();
  final TextEditingController _season = TextEditingController();
  final TextEditingController _boat = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    _season.dispose();
    _boat.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final L10n t = ref.read(l10nProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);

    final List<String> stops = shareableStopIds(widget.route);
    if (stops.length < 2) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.rtNeedStops)));
      return;
    }
    if (_body.text.trim().length < 30) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.rtBodyShort)));
      return;
    }
    final String name = _name.text.trim();
    if (name.length < 3) return;

    setState(() => _sending = true);
    try {
      await ref.read(sharedRoutesGatewayProvider).share(
            name: name,
            body: _body.text.trim(),
            season:
                _season.text.trim().isEmpty ? null : _season.text.trim(),
            boatSuggestion:
                _boat.text.trim().isEmpty ? null : _boat.text.trim(),
            // Mesafe/süre UYGULAMA HESABI — elle alan yok (dürüstlük).
            distanceNm: widget.route.distanceNm,
            durationHours: etaHours(widget.route.distanceNm),
            stopLocationIds: stops,
          );
      if (!mounted) return;
      nav.pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.rtShareSent)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      final String text =
          error is AppFailure ? error.message : t.rtLoadFailed;
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.rtShareTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(t.rtShareIntro,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey<String>('rts-name'),
              controller: _name,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: t.routeSaveNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('rts-body'),
              controller: _body,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t.rtFieldBody,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('rts-season'),
              controller: _season,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: t.rtFieldSeason,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('rts-boat'),
              controller: _boat,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: t.rtFieldBoat,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('rts-send'),
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.rtShareSend),
            ),
          ],
        ),
      ),
    );
  }
}
