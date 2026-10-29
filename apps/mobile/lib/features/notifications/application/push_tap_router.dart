import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/presentation/moderation_screen.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/events_screen.dart';
import '../../qa/presentation/qa_detail_screen.dart';
import '../../route/presentation/shared_route_detail_screen.dart';
import '../../route/presentation/shared_routes_screen.dart';
import '../presentation/notifications_inbox_screen.dart';
import 'push_controller.dart';

/// Kök gezgin anahtarı (SP-2 Döngü, kurucu onayı 2026-10-31): bildirim
/// dokunuşu widget ağacının DIŞINDAN gelir — ekran açmak için context değil
/// bu anahtar kullanılır. MaterialApp'e bootstrap bağlar.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// BİLDİRİM DOKUNUŞU YÖNLENDİRİCİSİ: push'un `data.kind` alanına göre ilgili
/// ekranı açar. Kapalı döngünün kilit taşı — bildirimi alan kaptan tek
/// dokunuşla olayın olduğu yere iner, ana ekranda aramaz.
final Provider<PushTapRouter> pushTapRouterProvider =
    Provider<PushTapRouter>((Ref ref) {
  final PushTapRouter r = PushTapRouter(ref);
  ref.onDispose(r.stop);
  return r;
});

class PushTapRouter {
  PushTapRouter(this._ref);

  final Ref _ref;
  StreamSubscription<Map<String, String>>? _sub;

  /// Dinlemeye başla (bootstrap'ta BİR kez). Stub köprüde akış boştur —
  /// web ve testlerde hiçbir şey olmaz.
  void start() {
    _sub ??= _ref
        .read(pushGatewayProvider)
        .onNotificationTap
        .listen(route, onError: (_, __) {/* en iyi çaba */});
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// data → ekran. Bilinmeyen tür Bildirim kutusuna düşer (hiçbir dokunuş
  /// boşa gitmez; eski sürüme yeni tür gelirse de güvenli).
  void route(Map<String, String> data) {
    final NavigatorState? nav = rootNavigatorKey.currentState;
    if (nav == null) return; // uygulama henüz kurulmadı — sessizce vazgeç
    final String kind = data['kind'] ?? '';
    final String id = data['id'] ?? '';
    final Widget screen = switch (kind) {
      'qa_answer' when id.isNotEmpty => QaDetailScreen(questionId: id),
      'route_approved' when id.isNotEmpty => SharedRouteDetailScreen(routeId: id),
      // Reddedilen rota keşif listesinde görünmez — sahibinin listesi olan
      // Rota Keşfi açılır (bekleyen/reddedilen üstte, dürüst durumuyla).
      'route_rejected' => const SharedRoutesScreen(),
      'event_reminder' when id.isNotEmpty => EventDetailScreen(eventId: id),
      // İptal edilen etkinliğin detayı yerine liste: kaptan alternatif görür.
      'event_cancelled' => const EventsScreen(),
      'moderation_new' => const ModerationScreen(),
      _ => const NotificationsInboxScreen(),
    };
    nav.push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
