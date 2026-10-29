import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_gate.dart';
import '../application/community_controller.dart';

/// İÇERİK ŞİKÂYETİ (SP-1 güvenlik, kurucu onayı 2026-10-29).
///
/// Not ve yorum kartlarındaki ⚑ tek kapıdan geçer: hesap kapısı → kısa
/// sebep seçimi → sunucudaki mevcut şikâyet ucu (3 farklı kullanıcı aynı
/// içeriği bildirirse sunucu içeriği otomatik incelemeye düşürür).
/// Sebepler bilerek İKİ taneyle sınırlı: karar yorgunluğu yaratmadan
/// moderasyona yeterli sinyal.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String idOrSlug,
  required String targetType, // 'note' | 'review'
  required String targetId,
}) {
  final L10n t = ref.read(l10nProvider);
  return requireAccount(
    context,
    ref,
    message: t.gateNoteMsg,
    onAllowed: () async {
      final String? reason = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) {
          final ThemeData theme = Theme.of(sheetContext);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(t.reportSheetTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              ListTile(
                key: const ValueKey<String>('report-wrong'),
                leading: const DocklyIcon(DocklyIcons.infoOutline,
                    color: DocklyColors.warning),
                title: Text(t.reportReasonWrong),
                onTap: () => Navigator.of(sheetContext).pop('wrong_info'),
              ),
              ListTile(
                key: const ValueKey<String>('report-abuse'),
                leading: const DocklyIcon(DocklyIcons.flag,
                    color: DocklyColors.error),
                title: Text(t.reportReasonAbuse),
                onTap: () => Navigator.of(sheetContext).pop('abuse'),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      );
      if (reason == null || !context.mounted) return;
      // Mesajcı AWAIT'TEN ÖNCE alınır (dispose güvenliği — yerleşik desen).
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(communityGatewayProvider).report(
              idOrSlug: idOrSlug,
              reason: reason,
              targetType: targetType,
              targetId: targetId,
            );
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.reportThanks)));
      } catch (error) {
        // Ham istisna arayüze sızmaz (docs/26 §13) — sunucu mesajı ya da
        // genel teşekkür dili yerine dürüst, kısa hata.
        final String msg =
            error is AppFailure ? error.message : t.peLoadFailed;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    },
  );
}
