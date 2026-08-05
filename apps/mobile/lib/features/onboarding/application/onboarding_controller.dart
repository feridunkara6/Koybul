import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_onboarding_store.dart';
import '../domain/onboarding_store.dart';

/// Tanıtım deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<OnboardingStore> onboardingStoreProvider =
    Provider<OnboardingStore>((ref) => const SharedPrefsOnboardingStore());

/// Turun adım sayısı (v2, kullanıcı isteği 2026-08 — dokundukça ilerleyen
/// kartlar): ① hoş geldin ② harita & koylar ③ filtreler ④ Konumum ⑤ SOS
/// ⑥ deniz rotası ⑦ rota düzenleme & kaydetme.
const int kTourStepCount = 7;

/// İlk-dokunuş ipucu anahtarları (cihazda kalıcı — bir kez gösterilir).
const String kHintBottomCard = 'bottom_card';
const String kHintCoords = 'coords';

/// Tanıtım durumu. `ready` FALSE kaldıkça hiçbir tanıtım öğesi çizilmez
/// (depo okunamadıysa — test ortamı dahil — kullanıcı rahatsız edilmez).
class OnboardingState {
  const OnboardingState({
    this.ready = false,
    this.welcomeDone = true,
    this.tourStep = -1,
    this.seenHints = const <String>{},
  });

  final bool ready;
  final bool welcomeDone;

  /// -1 = tur kapalı; 0..[kTourStepCount]-1 = aktif adım.
  final int tourStep;
  final Set<String> seenHints;

  bool get tourActive => tourStep >= 0;

  /// İpucu gösterilsin mi? Depo hazır değilse ya da tanıtım kartları açıkken
  /// gösterilmez (ekran kalabalığı olmasın).
  bool showHint(String key) =>
      ready && !tourActive && !seenHints.contains(key);

  OnboardingState copyWith({
    bool? ready,
    bool? welcomeDone,
    int? tourStep,
    Set<String>? seenHints,
  }) {
    return OnboardingState(
      ready: ready ?? this.ready,
      welcomeDone: welcomeDone ?? this.welcomeDone,
      tourStep: tourStep ?? this.tourStep,
      seenHints: seenHints ?? this.seenHints,
    );
  }
}

/// YENİ KULLANICI TANITIMI beyni (2026-08, kullanıcı onaylı): karşılama kartı
/// + 6 adımlı spot ışıklı tur + ilk-dokunuş ipuçları. Kararlar cihazda saklanır
/// (bir kez gösterme sözü); Profil'den tur yeniden izlenebilir.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    unawaited(_load());
    return const OnboardingState();
  }

  OnboardingStore get _store => ref.read(onboardingStoreProvider);

  Future<void> _load() async {
    final OnboardingData? data = await _store.load();
    if (data == null) return; // depo yok/bozuk → tanıtım hiç açılmaz
    if (!data.welcomeDone) {
      // İLK AÇILIŞ (v2, kullanıcı isteği 2026-08): tanıtım kartları
      // KENDİLİĞİNDEN başlar — ayrı karşılama sorusu yok; ekrana dokundukça
      // kart ilerler. Karar hemen işlenir: yarıda kapatılsa bile bir daha
      // kendiliğinden açılmaz (Profil'den istenince tekrar izlenir).
      state = OnboardingState(
        ready: true,
        welcomeDone: true,
        tourStep: 0,
        seenHints: data.seenHints,
      );
      _persist();
      return;
    }
    state = state.copyWith(
      ready: true,
      welcomeDone: true,
      seenHints: data.seenHints,
    );
  }

  void _persist() {
    unawaited(_store.save(OnboardingData(
      welcomeDone: state.welcomeDone,
      seenHints: state.seenHints,
    )));
  }

  /// Ekrana dokunuş — sonraki kart; son kartta tanıtım biter.
  void nextStep() {
    if (!state.tourActive) return;
    final int next = state.tourStep + 1;
    state = state.copyWith(tourStep: next >= kTourStepCount ? -1 : next);
  }

  /// "Atla" — tur o an kapanır.
  void skipTour() {
    if (!state.tourActive) return;
    state = state.copyWith(tourStep: -1);
  }

  /// Profil → "Tanıtım turunu tekrar izle".
  void replayTour() {
    state = state.copyWith(ready: true, welcomeDone: true, tourStep: 0);
  }

  /// İlk-dokunuş ipucu kapatıldı — bir daha gösterilmez.
  void markHintSeen(String key) {
    if (state.seenHints.contains(key)) return;
    state = state.copyWith(seenHints: <String>{...state.seenHints, key});
    _persist();
  }
}

final NotifierProvider<OnboardingController, OnboardingState>
    onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
        OnboardingController.new);
