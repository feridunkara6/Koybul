import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_getting_started_store.dart';
import '../domain/getting_started_store.dart';

/// Başlangıç görevleri deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<GettingStartedStore> gettingStartedStoreProvider =
    Provider<GettingStartedStore>(
        (ref) => const SharedPrefsGettingStartedStore());

/// BAŞLANGIÇ GÖREVLERİ kartının kapatılma durumu (Hoş Geldin Paketi,
/// kurucu onayı 2026-10-25).
///
/// Üç durum vardır:
///  - null  → depo henüz okunmadı (kart ÇİZİLMEZ — "önce görünüp sonra
///            kaybolan kart" titremesi yaşanmasın),
///  - false → kart görünür,
///  - true  → kullanıcı "Gizle" dedi; bir daha kendiliğinden çıkmaz.
class GettingStartedDismissed extends Notifier<bool?> {
  @override
  bool? build() {
    unawaited(_load());
    return null;
  }

  GettingStartedStore get _store => ref.read(gettingStartedStoreProvider);

  Future<void> _load() async {
    final bool dismissed = await _store.loadDismissed();
    // Yarış koruması (MyBoatController ilkesi): kullanıcı depo okunurken
    // kartı kapattıysa, geç gelen "false" kararını EZMEZ.
    state ??= dismissed;
  }

  /// "Gizle" — kart o an kapanır ve karar cihaza kalıcı yazılır.
  void dismiss() {
    state = true;
    unawaited(_store.saveDismissed());
  }
}

final NotifierProvider<GettingStartedDismissed, bool?>
    gettingStartedDismissedProvider =
    NotifierProvider<GettingStartedDismissed, bool?>(
        GettingStartedDismissed.new);
