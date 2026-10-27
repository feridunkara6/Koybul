import 'dart:async';

import 'package:dockly_api/dockly_api.dart' show NotificationPrefs;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/local_notifier.dart';
import '../domain/push_gateway.dart';

/// Push köprüsü — bootstrap, Firebase başlatıldıysa gerçek impl ile override
/// eder (authGateway deseni). Varsayılan stub: web/test hiç kanala dokunmaz.
final Provider<PushGateway> pushGatewayProvider =
    Provider<PushGateway>((ref) => const StubPushGateway());

/// Yerel bildirim köprüsü — bootstrap mobilde gerçek impl ile override eder.
final Provider<LocalNotifier> localNotifierProvider =
    Provider<LocalNotifier>((ref) => const StubLocalNotifier());

/// CİHAZ KAYDI orkestrasyonu (push paketi, kurucu onayı 2026-10-27).
///
/// Akış: giriş → izin iste → FCM tokenını sunucuya yaz (upsert). Çıkışta
/// kayıt düşürülür ki eski hesabın bildirimi yeni sahipsiz cihaza gitmesin.
/// Her adım en-iyi-çaba: push, ana akışları asla bozamaz.
class PushRegistrar {
  PushRegistrar(this._ref);

  final Ref _ref;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  /// Kayıt (idempotent) — başarıda cihazın güncel tercihleri, aksi null:
  /// misafir, izin reddi, token üretilemedi ya da sunucu hatası.
  Future<NotificationPrefs?> register() async {
    final AuthState auth = _ref.read(authControllerProvider);
    if (auth is! Authenticated || auth.isGuest) return null;
    final PushGateway gw = _ref.read(pushGatewayProvider);
    if (!await gw.requestPermission()) return null;
    final String? token = await gw.token();
    if (token == null) return null;
    final String? access =
        await _ref.read(authRepositoryProvider).validAccessToken();
    if (access == null) return null;
    final NotificationPrefs prefs =
        await _ref.read(notificationsApiProvider).registerDevice(
              accessToken: access,
              token: token,
              platform: _platformName(),
              locale: _ref.read(appLocaleProvider).name,
            );
    _token = token;
    _watchRefresh();
    return prefs;
  }

  /// Tercih değişikliği — güncel tercihleri döndürür (null: kayıt yok).
  Future<NotificationPrefs?> updatePrefs({
    bool? community,
    bool? events,
    bool? moderation,
  }) async {
    final String? token = _token ?? await _ref.read(pushGatewayProvider).token();
    if (token == null) return null;
    final String? access =
        await _ref.read(authRepositoryProvider).validAccessToken();
    if (access == null) return null;
    return _ref.read(notificationsApiProvider).updatePrefs(
          accessToken: access,
          token: token,
          community: community,
          events: events,
          moderation: moderation,
        );
  }

  /// Çıkış/silme öncesi kayıt düşürme — EN İYİ ÇABA, asla fırlatmaz
  /// (çıkış her hâlükârda tamamlanmalı; logout akışıyla aynı ilke).
  Future<void> unregister() async {
    try {
      final String? token =
          _token ?? await _ref.read(pushGatewayProvider).token();
      if (token == null) return;
      final String? access =
          await _ref.read(authRepositoryProvider).validAccessToken();
      if (access == null) return;
      await _ref
          .read(notificationsApiProvider)
          .removeDevice(accessToken: access, token: token);
    } catch (_) {/* sunucu ölü tokenı 'gone' temizliğiyle de yakalar */}
  }

  /// Token tazelenirse sunucudaki kayıt sessizce güncellenir (upsert).
  void _watchRefresh() {
    _refreshSub ??= _ref
        .read(pushGatewayProvider)
        .onTokenRefresh
        .listen((_) => unawaited(register().catchError((_) => null)));
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
  }
}

final Provider<PushRegistrar> pushRegistrarProvider =
    Provider<PushRegistrar>((ref) {
  final PushRegistrar r = PushRegistrar(ref);
  ref.onDispose(() => r._refreshSub?.cancel());
  return r;
});

/// Ayarlar ekranının gördüğü tercihler: açılışta kayıt (upsert) yapılır ve
/// güncel tercihler okunur. null → push bu cihazda kurulamadı (misafir/izin).
final AutoDisposeFutureProvider<NotificationPrefs?> pushPrefsProvider =
    FutureProvider.autoDispose<NotificationPrefs?>((ref) async {
  try {
    return await ref.watch(pushRegistrarProvider).register();
  } catch (_) {
    return null; // ekran dürüst "kurulamadı" notunu gösterir
  }
});

/// BAKIM HATIRLATMASI (yerel) anahtarı — cihazda saklanır, varsayılan AÇIK.
/// Sunucuyla ilgisi yok: bakım verisi gibi tercihi de cihazda yaşar.
class MaintReminderToggle extends Notifier<bool> {
  static const String _key = 'ntf.maint.enabled';

  @override
  bool build() {
    unawaited(_load());
    return true;
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool? v = prefs.getBool(_key);
      if (v != null) state = v;
    } catch (_) {/* okunamazsa varsayılan açık kalır */}
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {/* en iyi çaba */}
  }
}

final NotifierProvider<MaintReminderToggle, bool> maintReminderEnabledProvider =
    NotifierProvider<MaintReminderToggle, bool>(MaintReminderToggle.new);
