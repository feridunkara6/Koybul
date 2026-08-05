import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_prefs_checklist_store.dart';
import '../domain/checklist_store.dart';

/// Kontrol listesi madde sayısı — l10n `checklistItems` listeleriyle AYNI
/// olmak zorundadır (4 dilde de).
const int kChecklistItemCount = 10;

/// Kontrol deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<ChecklistStore> checklistStoreProvider =
    Provider<ChecklistStore>((ref) => const SharedPrefsChecklistStore());

/// Seyir öncesi kontrol durumu.
class ChecklistState {
  const ChecklistState({
    required this.ready,
    required this.mask,
    required this.promptVisible,
  });

  /// Depo okundu mu? (okunana dek şerit gösterilmez)
  final bool ready;

  /// O günün işaretli maddeleri (bit i = madde i).
  final int mask;

  /// Nazik şerit ekranda mı? (rota çizilince, günde bir — onaylı doz)
  final bool promptVisible;

  bool isChecked(int i) => (mask >> i) & 1 == 1;

  int get checkedCount {
    int n = 0;
    for (int i = 0; i < kChecklistItemCount; i++) {
      if (isChecked(i)) n++;
    }
    return n;
  }

  ChecklistState copyWith({bool? ready, int? mask, bool? promptVisible}) =>
      ChecklistState(
        ready: ready ?? this.ready,
        mask: mask ?? this.mask,
        promptVisible: promptVisible ?? this.promptVisible,
      );
}

/// SEYİR ÖNCESİ KONTROL beyni (kullanıcı onayı 2026-08, "günde bir, nazik").
/// İşaretler GÜNLÜKTÜR: gün değişince liste sıfır başlar (dünkü kontroller
/// bugünü aklamaz — güvenlik ilkesi).
class ChecklistController extends Notifier<ChecklistState> {
  String? _checksDay; // maskenin ait olduğu gün
  String? _askDay; // şeridin en son sorulduğu gün

  @override
  ChecklistState build() {
    unawaited(_load());
    return const ChecklistState(ready: false, mask: 0, promptVisible: false);
  }

  ChecklistStore get _store => ref.read(checklistStoreProvider);

  Future<void> _load() async {
    final (String?, int) checks = await _store.loadChecks();
    final String? askDay = await _store.loadAskDay();
    _checksDay = checks.$1;
    _askDay = askDay;
    state = state.copyWith(ready: true, mask: checks.$2);
  }

  int _maskFor(DateTime now) {
    // Gün değiştiyse dünkü işaretler geçersiz (sıfır maske).
    return _checksDay == checklistDayKey(now) ? state.mask : 0;
  }

  /// Yeni rota çizildi → günde bir kez nazik şerit (onaylı doz). Depo hazır
  /// değilse sessiz geçilir; bir sonraki rotada tekrar denenir.
  void maybePrompt({DateTime? now}) {
    if (!state.ready || state.promptVisible) return;
    final String day = checklistDayKey(now ?? DateTime.now());
    if (_askDay == day) return; // bugün soruldu
    state = state.copyWith(promptVisible: true);
  }

  /// Şerit kapandı ("Hazırım" ya da listeyi açtı) → bugün bir daha sorulmaz.
  void dismissPrompt({DateTime? now}) {
    final String day = checklistDayKey(now ?? DateTime.now());
    _askDay = day;
    unawaited(_store.saveAskDay(day));
    if (state.promptVisible) {
      state = state.copyWith(promptVisible: false);
    }
  }

  /// Madde işaretle/kaldır — o günün maskesine yazılır.
  void toggle(int index, {DateTime? now}) {
    if (index < 0 || index >= kChecklistItemCount) return;
    final DateTime t = now ?? DateTime.now();
    final String day = checklistDayKey(t);
    final int mask = _maskFor(t) ^ (1 << index);
    _checksDay = day;
    state = state.copyWith(mask: mask);
    unawaited(_store.saveChecks(day, mask));
  }

  /// O günün maskesi (gün değiştiyse görünüm sıfırdan başlar).
  int maskFor(DateTime now) => _maskFor(now);
}

final NotifierProvider<ChecklistController, ChecklistState>
    checklistProvider =
    NotifierProvider<ChecklistController, ChecklistState>(
        ChecklistController.new);
