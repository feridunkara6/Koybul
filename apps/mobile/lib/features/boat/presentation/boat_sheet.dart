import 'package:dockly_api/dockly_api.dart' show LocationSummary;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../search/presentation/search_screen.dart';
import '../application/my_boat_controller.dart';
import '../domain/my_boat.dart';

/// "Tekneni tanımla" alt sayfası — boy (+ opsiyonel su çekimi) alır, bellekte saklar.
Future<void> showBoatSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext _) => const _BoatSheet(),
  );
}

class _BoatSheet extends ConsumerStatefulWidget {
  const _BoatSheet();

  @override
  ConsumerState<_BoatSheet> createState() => _BoatSheetState();
}

class _BoatSheetState extends ConsumerState<_BoatSheet> {
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _draftCtrl;
  late final TextEditingController _nameCtrl;
  HomeMarina? _marina;
  String? _error;

  @override
  void initState() {
    super.initState();
    final MyBoat? boat = ref.read(myBoatProvider);
    _lengthCtrl = TextEditingController(text: boat?.lengthM.toString() ?? '');
    _draftCtrl = TextEditingController(text: boat?.draftM?.toString() ?? '');
    _nameCtrl = TextEditingController(text: boat?.name ?? '');
    _marina = boat?.homeMarina;
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _draftCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Bağlı marinayı arama ekranından seçtirir (açılış akışıyla aynı yol).
  Future<void> _pickMarina() async {
    final LocationSummary? picked =
        await Navigator.of(context).push<LocationSummary>(
      MaterialPageRoute<LocationSummary>(
        builder: (BuildContext _) => SearchScreen(
          pickDestination: true,
          pickHint: ref.read(l10nProvider).marinaPickTitle,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _marina = HomeMarina(
            id: picked.id,
            name: picked.name,
            lat: picked.position.lat,
            lon: picked.position.lon,
          ));
    }
  }

  void _save() {
    final double? length = double.tryParse(_lengthCtrl.text.trim().replaceAll(',', '.'));
    if (length == null || length <= 0 || length > 200) {
      setState(() => _error = 'Geçerli bir tekne boyu gir (m).');
      return;
    }
    final String draftText = _draftCtrl.text.trim();
    final double? draft = draftText.isEmpty ? null : double.tryParse(draftText.replaceAll(',', '.'));
    final String name = _nameCtrl.text.trim();
    // Dokunulmayan alanlar KORUNUR (Paket 2 dersi): boy/su çekimi güncellemek
    // marka ve tekne tipini (açılış E3 cevabı) silmesin. Ad ve bağlı marina
    // bu sayfada DÜZENLENEBİLİR (kullanıcı isteği 2026-08) — adın silinmesi
    // bilinçli bir eylemdir (alanı boşaltmak), korunmaz.
    final MyBoat? current = ref.read(myBoatProvider);
    ref.read(myBoatProvider.notifier).set(MyBoat(
          lengthM: length,
          draftM: draft,
          brand: current?.brand,
          typeId: current?.typeId,
          name: name.isEmpty ? null : name,
          homeMarina: _marina,
        ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Tekneni tanımla', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Böylece her limanda "teknen sığar mı?" işaretini görürsün. Bilgi cihazında kalır.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('boat-name-field'),
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Teknenin adı — opsiyonel',
              hintText: 'ör. Martı',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lengthCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: formatters,
            decoration: const InputDecoration(
              labelText: 'Tekne boyu (m)',
              hintText: 'ör. 12.5',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _draftCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: formatters,
            decoration: const InputDecoration(
              labelText: 'Su çekimi (m) — opsiyonel',
              hintText: 'ör. 1.9',
            ),
          ),
          const SizedBox(height: 12),
          // BAĞLI MARİNA (kullanıcı isteği 2026-08): harita açılışta bu
          // çevreye odaklanır. Arama ekranından seçilir; ✕ ile kaldırılır.
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('boat-marina-pick'),
                  onPressed: _pickMarina,
                  icon: const DocklyIcon(DocklyIcons.amMooring, size: 16),
                  label: Text(
                    _marina?.name ?? 'Bağlı marina seç — opsiyonel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_marina != null)
                IconButton(
                  key: const ValueKey<String>('boat-marina-clear'),
                  tooltip: 'Kaldır',
                  icon: const DocklyIcon(DocklyIcons.clear, size: 16),
                  onPressed: () => setState(() => _marina = null),
                ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: DocklyColors.error)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: DocklyButton(label: 'Kaydet', onPressed: _save),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
