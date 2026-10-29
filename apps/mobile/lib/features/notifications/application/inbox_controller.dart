import 'package:dockly_api/dockly_api.dart' show InboxItem;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';

/// BİLDİRİM KUTUSU verisi (SP-2 Döngü, kurucu onayı 2026-10-31).
///
/// Misafirde ağ çağrısı YAPILMAZ — boş liste döner (kutu hesapla gezer;
/// push'lar da zaten hesapla geliyor). Hata yutulmaz, ekran yeniden dene
/// sunar (async.when error dalı).
final FutureProvider<List<InboxItem>> inboxProvider =
    FutureProvider.autoDispose<List<InboxItem>>((ref) async {
  final AuthState auth = ref.watch(authControllerProvider);
  if (auth is! Authenticated || auth.isGuest) return const <InboxItem>[];
  final String? access =
      await ref.read(authRepositoryProvider).validAccessToken();
  if (access == null) return const <InboxItem>[];
  return ref.read(notificationsApiProvider).inbox(accessToken: access);
});

/// Kutu açılınca TÜMÜNÜ okundu işaretler — en iyi çaba (işaret düşmezse
/// bir sonraki açılışta düşer; kullanıcıya hata gösterilmez).
Future<void> markInboxRead(WidgetRef ref) async {
  try {
    final String? access =
        await ref.read(authRepositoryProvider).validAccessToken();
    if (access == null) return;
    await ref.read(notificationsApiProvider).markAllRead(accessToken: access);
  } catch (_) {/* en iyi çaba */}
}
