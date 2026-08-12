import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart';
import '../data/shared_prefs_welcome_store.dart';
import '../domain/welcome_store.dart';

/// Karşılama deposu sağlayıcısı — testte sahte ile override edilir.
final Provider<WelcomeStore> welcomeStoreProvider =
    Provider<WelcomeStore>((ref) => const SharedPrefsWelcomeStore());

/// İlk açılışta BİR KEZ "Teknen kaç metre?" sorusunu gösterir (wow anı: cevap
/// verilirse tüm liman/arama sonuçlarında "teknen sığar mı?" rozetleri anında
/// kişiselleşir). Gösterilmez: daha önce soruldu ya da tekne zaten tanımlı.
Future<void> maybeShowWelcomePrompt(BuildContext context, WidgetRef ref) async {
  final WelcomeStore store = ref.read(welcomeStoreProvider);
  if (await store.wasShown()) return;
  // Tekne zaten var mı? Bellek + cihaz deposu (açılış geri-yükleme yarışına
  // karşı doğrudan depoya da bakılır) — varsa soruya gerek yok.
  final MyBoat? stored = await ref.read(boatStorageProvider).load();
  if (!context.mounted) return;
  if (stored != null || ref.read(myBoatProvider) != null) {
    await store.markShown();
    return;
  }
  // Soru bir kez sorulur — kullanıcı kaydırıp kapatsa bile tekrar nag'lenmez.
  await store.markShown();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // İçerik (marka alanı + feet çipleri) standart tavandan uzun olabilir;
    // scroll-controlled + içerideki kaydırma küçük ekranlarda taşmayı önler.
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => WelcomeSheetBody(
      onPickLength: (double lengthM, String? brand) {
        // Dokunulmayan alanlar korunur (emekli akış; tutarlılık için aynı kural).
        final MyBoat? current = ref.read(myBoatProvider);
        ref.read(myBoatProvider.notifier).set(MyBoat(
              lengthM: lengthM,
              brand: brand,
              draftM: current?.draftM,
              typeId: current?.typeId,
              // Ad + bağlı marina da korunur (2026-08 alanları): boy
              // güncellemek teknenin kimliğini silmesin.
              name: current?.name,
              homeMarina: current?.homeMarina,
            ));
        Navigator.of(sheetContext).pop();
      },
      onCustom: () {
        Navigator.of(sheetContext).pop();
        // Ana bağlam üzerinden tam tekne sayfası (boy + su çekimi).
        if (context.mounted) showBoatSheet(context);
      },
      onSkip: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// Karşılama içeriği: DENİZCİ DİLİYLE — tekne markası + FEET cinsinden boy
/// (ürün kararı: "özel hissettirsin"). İç birim metre kalır; feet burada
/// çevrilir. Ayrı widget — test edilir.
class WelcomeSheetBody extends ConsumerStatefulWidget {
  const WelcomeSheetBody({
    required this.onPickLength,
    required this.onCustom,
    required this.onSkip,
    super.key,
  });

  /// Seçilen boy (METRE, çevrilmiş) + opsiyonel marka.
  final void Function(double lengthM, String? brand) onPickLength;
  final VoidCallback onCustom;
  final VoidCallback onSkip;

  @override
  ConsumerState<WelcomeSheetBody> createState() => _WelcomeSheetBodyState();
}

class _WelcomeSheetBodyState extends ConsumerState<WelcomeSheetBody> {
  /// Hızlı boy seçenekleri (feet) — 26ft≈7.9m ... 79ft≈24.1m.
  static const List<int> _quickFeet = <int>[26, 33, 39, 46, 59, 79];

  final TextEditingController _brand = TextEditingController();

  @override
  void dispose() {
    _brand.dispose();
    super.dispose();
  }

  String? get _brandOrNull => _brand.text.trim().isEmpty ? null : _brand.text.trim();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    // SingleChildScrollView: klavye açıkken / kısa ekranlarda içerik kaydırılır,
    // asla taşmaz (CI dersi: taşma testte hata sayılır).
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 4, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const DocklyIcon(DocklyIcons.sailing, color: DocklyColors.brandPrimary),
              const SizedBox(width: 10),
              Text(t.sheetTitle, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.welcomeBody),
          const SizedBox(height: 14),
          TextField(
            controller: _brand,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.welcomeBrandHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int ft in _quickFeet)
                ActionChip(
                  label: Text('$ft ft'),
                  onPressed: () =>
                      widget.onPickLength(feetToMeters(ft.toDouble()), _brandOrNull),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TextButton(
                  onPressed: widget.onCustom, child: Text(t.welcomeOtherLen)),
              const Spacer(),
              TextButton(onPressed: widget.onSkip, child: Text(t.welcomeSkip)),
            ],
          ),
        ],
      ),
    );
  }
}
