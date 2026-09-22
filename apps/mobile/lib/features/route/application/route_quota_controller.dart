import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../premium/application/premium_controller.dart';
import '../data/shared_prefs_route_quota_store.dart';

/// GÜNLÜK ROTA KOTASI (P4b, kurucu onayı 2026-09-22 — premium v3 raporu K3).
///
/// Kural: ücretsiz kullanıcı günde [kRouteDailyLimit] YENİ rota çizer; premium
/// sınırsız. "Yeni rota" = kullanıcının başlattığı planlama (haritada Rota /
/// bekleyen hedefle başlangıç seçimi). ŞUNLAR SAYILMAZ: kayıtlı rotayı açmak,
/// var olan rotayı düzenlemek (durak ekle/çıkar/taşı) — cezalandırma yok.
///
/// Sayaç CİHAZDA tutulur (sunucu maliyeti sıfır; rota motoru zaten cihazda).
/// Gece yarısı (yerel saat) kendiliğinden sıfırlanır. Depo yoksa sayaç oturum
/// hafızasında sürer — kullanıcıya asla hata gösterilmez.
const int kRouteDailyLimit = 3;

/// Sayaç deposu sözleşmesi — testte sahteyle değiştirilir.
abstract interface class RouteQuotaStore {
  /// Kayıtlı (günAnahtarı, kullanılan) çifti; hiç kayıt yoksa null.
  Future<(String, int)?> load();

  Future<void> save(String dayKey, int used);
}

final Provider<RouteQuotaStore> routeQuotaStoreProvider =
    Provider<RouteQuotaStore>((_) => const SharedPrefsRouteQuotaStore());

class RouteQuotaState {
  const RouteQuotaState({
    required this.used,
    required this.unlimited,
    this.consumeSeq = 0,
  });

  /// Bugün üretilen rota sayısı (yalnız ücretsiz kullanıcı için anlamlı).
  final int used;

  /// Premium etkin — kota hiç uygulanmaz, sayaç arayüzde gösterilmez.
  final bool unlimited;

  /// Her BAŞARILI hak kullanımında artar — GÖRÜNÜR SAYAÇ bildirimi (K3) bu
  /// sinyalle gösterilir. Depodan tazeleme (açılış) bunu ARTIRMAZ: kullanıcı
  /// rota çizmeden "X/3" bildirimi görmez.
  final int consumeSeq;

  int get limit => kRouteDailyLimit;
  int get remaining {
    if (unlimited) return kRouteDailyLimit;
    final int left = kRouteDailyLimit - used;
    return left < 0 ? 0 : left;
  }
}

/// Kota bekçisi. [tryConsume] planlamadan HEMEN ÖNCE çağrılır: hak varsa
/// sayacı artırıp true, doluysa false döner (arayüz o zaman kota sayfasını
/// gösterir; rota hesabı hiç başlamaz — boşuna pil/işlemci yakılmaz).
class RouteQuotaController extends Notifier<RouteQuotaState> {
  String _dayKey = '';
  Future<void>? _hydration;

  static String dayKeyFor(DateTime now) {
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Testlerde sabitlenebilir saat; üretimde gerçek saat.
  DateTime Function() nowProvider = DateTime.now;

  @override
  RouteQuotaState build() {
    final bool premium = ref.watch(isPremiumActiveProvider);
    _dayKey = dayKeyFor(nowProvider());
    // Her kurulumda depodan tazele (premium değişse de sayaç kaybolmasın).
    _hydration = _hydrate();
    return RouteQuotaState(used: 0, unlimited: premium);
  }

  Future<void> _hydrate() async {
    final (String, int)? saved = await ref.read(routeQuotaStoreProvider).load();
    if (saved == null) return;
    final (String day, int used) = saved;
    if (day != _dayKey) return; // eski gün — sıfırdan başla
    state = RouteQuotaState(
      used: used,
      unlimited: state.unlimited,
      consumeSeq: state.consumeSeq,
    );
  }

  /// Bir "yeni rota" hakkı kullanmayı dener. Premium'da her zaman true.
  Future<bool> tryConsume() async {
    // Premium'da depo hiç beklenmez — sınırsızda sayacın önemi yok (ve depo
    // yavaş/tıkalıysa rota çizimi buna takılmamalı).
    if (state.unlimited) return true;
    await (_hydration ??= _hydrate());
    if (state.unlimited) return true; // bekleme sırasında premium açılmış olabilir

    // Gece yarısı devri: gün değiştiyse sayaç sıfırlanır.
    final String today = dayKeyFor(nowProvider());
    int used = state.used;
    if (today != _dayKey) {
      _dayKey = today;
      used = 0;
    }

    if (used >= kRouteDailyLimit) {
      if (used != state.used) {
        state = RouteQuotaState(
            used: used, unlimited: false, consumeSeq: state.consumeSeq);
      }
      return false;
    }

    used += 1;
    state = RouteQuotaState(
        used: used, unlimited: false, consumeSeq: state.consumeSeq + 1);
    // Kalıcılaştırma en iyi çaba — beklenmez, hata yutulur (depo zaten yutar).
    unawaited(ref.read(routeQuotaStoreProvider).save(_dayKey, used));
    return true;
  }
}

final NotifierProvider<RouteQuotaController, RouteQuotaState>
    routeQuotaControllerProvider =
    NotifierProvider<RouteQuotaController, RouteQuotaState>(
        RouteQuotaController.new);
