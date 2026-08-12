import 'dart:async';

import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_onboarding_store.dart';
import '../domain/onboarding_store.dart';

/// Tanıtım deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<OnboardingStore> onboardingStoreProvider =
    Provider<OnboardingStore>((ref) => const SharedPrefsOnboardingStore());

/// Turun adım sayısı (v2.0 kabuğu, kurucu onayı 2026-08 — tur ilgili bölgeyi
/// ışıkla gösterir, gerekirse SAYFA DEĞİŞİR):
/// ① hoş geldin ② harita & koylar ③ filtreler ④ Konumum ⑤ SOS
/// ⑥ deniz rotası ⑦ rota düzenleme & kaydetme ⑧ Defter (sekme 2)
/// ⑨ Teknem (sekme 3) ⑩ "Hazırsın" — Keşfet'e dönülür.
const int kTourStepCount = 10;

/// ÖRNEKLİ TUR v5 (kullanıcı isteği 2026-08): bu adımlarda ekranlar CANLI
/// ÖRNEK gösterir — kalıcı hiçbir şey yazılmaz, tur bitince örnekler silinir.
const int kTourStepMarkers = 1; // bir koy işareti örnek olarak seçilir
const int kTourStepRoute = 5; // gerçek motorla örnek rota çizilir
const int kTourStepRouteEdit = 6; // örnek rotanın bilgi kartı anlatılır
const int kTourStepSaved = 7; // Defter: örnek rota kartı görünür
const int kTourStepBoat = 8; // Teknem: tekne kimlik kartı vurgulanır

/// ÖRNEK ROTA uçları — sea_mask'e karşı DOĞRULANMIŞ su noktaları (Göcek
/// açığı -> 5,1 nm güney; aynı su kütlesi). TEK KAYNAK: hem turdaki canlı
/// rota hem Defter'deki örnek kart bu uçları kullanır.
const GeoPoint kTourDemoOrigin = GeoPoint(lat: 36.740, lon: 28.935);
const GeoPoint kTourDemoDest = GeoPoint(lat: 36.660, lon: 28.900);

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
    this.tourInvite = false,
    this.seenHints = const <String>{},
  });

  final bool ready;
  final bool welcomeDone;

  /// -1 = tur kapalı; 0..[kTourStepCount]-1 = aktif adım.
  final int tourStep;

  /// Tur DAVETİ görünür mü? (Faz 1: tur artık kendiliğinden başlamıyor.)
  final bool tourInvite;

  final Set<String> seenHints;

  bool get tourActive => tourStep >= 0;

  /// İpucu gösterilsin mi? Depo hazır değilse, tur açıkken ya da davet
  /// dururken gösterilmez (ekran kalabalığı olmasın).
  bool showHint(String key) =>
      ready && !tourActive && !tourInvite && !seenHints.contains(key);

  OnboardingState copyWith({
    bool? ready,
    bool? welcomeDone,
    int? tourStep,
    bool? tourInvite,
    Set<String>? seenHints,
  }) {
    return OnboardingState(
      ready: ready ?? this.ready,
      welcomeDone: welcomeDone ?? this.welcomeDone,
      tourStep: tourStep ?? this.tourStep,
      tourInvite: tourInvite ?? this.tourInvite,
      seenHints: seenHints ?? this.seenHints,
    );
  }
}

/// YENİ KULLANICI TANITIMI beyni (2026-08, kullanıcı onaylı): 10 adımlı OKLU
/// tur (spot ışığı + sayfa gezintisi) + ilk-dokunuş ipuçları. Kararlar cihazda saklanır
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
      // İLK AÇILIŞ — FAZ 1'DE DEĞİŞTİ: tur artık KENDİLİĞİNDEN BAŞLAMIYOR.
      //
      // Eskiden 10 kartlık tur, karşılama akışının hemen ardından zorla
      // başlıyordu. Kullanıcı haritayı görmeden önce 15 yüzey geçiyordu; tur
      // atlanabiliyordu ama "atla"yı bulmak da bir işti. Denetim bunu ilk iki
      // dakikadaki en büyük kayıp kalemi olarak işaretledi.
      //
      // Yerine tek satırlık bir DAVET çıkar: "kısa bir tanıtım ister misin?"
      // İsteyen açar, istemeyen haritaya dokunmaya başlar. Karar hemen
      // işlenir: davet bir kez gösterilir, cevap ne olursa olsun bir daha
      // kendiliğinden çıkmaz (Profil'den istenince tur tekrar izlenir).
      state = OnboardingState(
        ready: true,
        welcomeDone: true,
        tourStep: -1,
        tourInvite: true,
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

  /// Davet → "Evet, göster": tur başlar, davet kapanır.
  void acceptTourInvite() {
    if (!state.tourInvite) return;
    state = state.copyWith(tourInvite: false, tourStep: 0);
  }

  /// Davet → "Şimdi değil": davet kapanır, tur açılmaz. Bir daha
  /// kendiliğinden sorulmaz — Profil'den istendiğinde izlenir.
  void declineTourInvite() {
    if (!state.tourInvite) return;
    state = state.copyWith(tourInvite: false);
  }

  /// Profil → "Tanıtım turunu tekrar izle".
  void replayTour() {
    state = state.copyWith(
      ready: true,
      welcomeDone: true,
      tourInvite: false,
      tourStep: 0,
    );
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
