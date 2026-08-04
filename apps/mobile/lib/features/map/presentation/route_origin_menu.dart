import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../location/application/location_controller.dart';
import '../application/map_controller.dart';

/// BAŞLANGIÇ MENÜSÜ (rota planlama 2026-08, kullanıcı onaylı): rota
/// başlangıcı ya paylaşılan GPS konumudur ya da haritadan/koydan seçilir.
/// İki yerden açılır: koy kartındaki "Deniz rotası" (konum yokken) ve rota
/// çipindeki "değiştir". [destPos] doluysa yeni rota kurulur; boşsa mevcut
/// rotanın başlangıcı değiştirilir. [afterPick] BAŞLANGIÇ SEÇ moduna
/// girildikten sonra çağrılır (ör. detay sayfası haritaya döner).
Future<void> showRouteOriginMenu(
  BuildContext context,
  WidgetRef ref, {
  GeoPoint? destPos,
  String? destId,
  String? destName,
  VoidCallback? afterPick,
}) async {
  final L10n t = ref.read(l10nProvider);
  final String? choice = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: const DocklyIcon(DocklyIcons.sailing,
              color: DocklyColors.brandPrimary),
          title: Text(t.routeFromDeviceOpt),
          onTap: () => Navigator.of(sheetContext).pop('device'),
        ),
        ListTile(
          leading: const DocklyIcon(DocklyIcons.place,
              color: DocklyColors.brandPrimary),
          title: Text(t.routePickOriginOpt),
          onTap: () => Navigator.of(sheetContext).pop('pick'),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final MapController controller = ref.read(mapControllerProvider.notifier);
  if (choice == 'device') {
    // KONUM ŞARTI: GPS yoksa dürüst uyarı + tek dokunuşla konum isteme.
    if (ref.read(devicePositionProvider) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(t.routeNeedOrigin),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: t.locateTooltip,
            onPressed: () =>
                ref.read(locationControllerProvider.notifier).locateMe(),
          ),
        ));
      return;
    }
    if (destPos != null && destId != null) {
      await controller.routeTo(destPos, destId, name: destName);
    } else {
      await controller.setDeviceOrigin();
    }
    return;
  }
  // 'pick' → BAŞLANGIÇ SEÇ modu (haritada şerit çıkar).
  controller.beginOriginPick(
      destPos: destPos, destId: destId, destName: destName);
  afterPick?.call();
}
