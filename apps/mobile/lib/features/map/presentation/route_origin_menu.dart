import 'dart:async' show unawaited;

import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../location/application/location_controller.dart';
import '../application/map_controller.dart';

/// ROTA BAŞLAT — AKILLI AKIŞ (kullanıcı isteği 2026-08): "Deniz rotası"na
/// basınca konum İZNİ OTOMATİK istenir; kullanıcı onay verirse rota kendiliğinden
/// çizilir — koyu yeniden bulup basmak gerekmez. İzin reddedilir/alınamazsa
/// başlangıç menüsüne düşülür (Konumumdan / Başlangıç noktası seç).
Future<void> startSeaRoute(
  BuildContext context,
  WidgetRef ref, {
  required GeoPoint destPos,
  required String destId,
  String? destName,
  VoidCallback? afterPick,
  VoidCallback? onRouted,
}) async {
  final MapController controller = ref.read(mapControllerProvider.notifier);
  // Konum zaten paylaşılmışsa: doğrudan rota (eski hızlı yol).
  if (ref.read(devicePositionProvider) != null) {
    unawaited(controller.routeTo(destPos, destId, name: destName));
    onRouted?.call();
    return;
  }
  // KONUM İZNİ OTOMATİK: tarayıcı/işletim sistemi izin penceresi burada açılır.
  await ref.read(locationControllerProvider.notifier).locateMe();
  if (!context.mounted) return;
  if (ref.read(devicePositionProvider) != null) {
    unawaited(controller.routeTo(destPos, destId, name: destName));
    onRouted?.call();
    return;
  }
  // İzin gelmedi → dürüst geri düşüş: başlangıç menüsü.
  await showRouteOriginMenu(
    context,
    ref,
    destPos: destPos,
    destId: destId,
    destName: destName,
    afterPick: afterPick,
    onRouted: onRouted,
  );
}

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
  VoidCallback? onRouted,
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
      unawaited(controller.routeTo(destPos, destId, name: destName));
      onRouted?.call();
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
