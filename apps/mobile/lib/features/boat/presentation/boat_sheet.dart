import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    final MyBoat? boat = ref.read(myBoatProvider);
    _lengthCtrl = TextEditingController(text: boat?.lengthM.toString() ?? '');
    _draftCtrl = TextEditingController(text: boat?.draftM?.toString() ?? '');
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _draftCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final double? length = double.tryParse(_lengthCtrl.text.trim().replaceAll(',', '.'));
    if (length == null || length <= 0 || length > 200) {
      setState(() => _error = 'Geçerli bir tekne boyu gir (m).');
      return;
    }
    final String draftText = _draftCtrl.text.trim();
    final double? draft = draftText.isEmpty ? null : double.tryParse(draftText.replaceAll(',', '.'));
    // Dokunulmayan alanlar KORUNUR (Paket 2 dersi): boy/su çekimi güncellemek
    // marka ve tekne tipini (açılış E3 cevabı) silmesin.
    final MyBoat? current = ref.read(myBoatProvider);
    ref.read(myBoatProvider.notifier).set(MyBoat(
          lengthM: length,
          draftM: draft,
          brand: current?.brand,
          typeId: current?.typeId,
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
