import 'package:dockly_api/dockly_api.dart' show LocationSummary;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_gate.dart';
import '../../search/presentation/search_screen.dart';
import '../application/my_boat_controller.dart';
import '../domain/my_boat.dart';

/// "Tekneni tanımla" alt sayfası — boy (+ opsiyonel su çekimi) alır, bellekte saklar.
///
/// HESAP KAPISI (kurucu kararı 2026-10-26): tekne tanımlamak HESAP ister.
/// Kapı TEK yerde — burada — durur; 8 çağıranın hiçbiri ayrıca düşünmez.
/// Hesap yoksa "Hesap gerekli" daveti açılır; giriş/kayıt tamamlanırsa
/// tekne formu OTOMATİK devam eder (üyelik kapısı deseni, 2026-07).
Future<void> showBoatSheet(BuildContext context, WidgetRef ref) {
  return requireAccount(
    context,
    ref,
    message: ref.read(l10nProvider).gateBoatMsg,
    onAllowed: () {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) => const _BoatSheet(),
      );
    },
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
  // KATALOG (kurucu onayı 2026-10-23): model + yıl alanları, tür çipleri,
  // marka otomatik tamamlama. Hepsi OPSİYONEL — "bilmiyorum" geçerli cevaptır.
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _brandCtrl;
  final FocusNode _brandFocus = FocusNode();
  String _brandText = '';
  String? _typeId;
  HomeMarina? _marina;
  String? _error;

  @override
  void initState() {
    super.initState();
    final MyBoat? boat = ref.read(myBoatProvider);
    _lengthCtrl = TextEditingController(text: boat?.lengthM.toString() ?? '');
    _draftCtrl = TextEditingController(text: boat?.draftM?.toString() ?? '');
    _nameCtrl = TextEditingController(text: boat?.name ?? '');
    _modelCtrl = TextEditingController(text: boat?.model ?? '');
    _yearCtrl = TextEditingController(text: boat?.buildYear?.toString() ?? '');
    _brandCtrl = TextEditingController(text: boat?.brand ?? '');
    _brandText = boat?.brand ?? '';
    _typeId = boat?.typeId;
    _marina = boat?.homeMarina;
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _draftCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _brandCtrl.dispose();
    _brandFocus.dispose();
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
    // Yıl: boş = bilinmiyor (geçerli); doluysa 1850-2027 aralığı beklenir.
    final String yearText = _yearCtrl.text.trim();
    int? year;
    if (yearText.isNotEmpty) {
      year = int.tryParse(yearText);
      if (year == null || year < kBoatYearMin || year > kBoatYearMax) {
        setState(() => _error = ref.read(l10nProvider).btYearInvalid);
        return;
      }
    }
    final String brand = _brandText.trim();
    final String model = _modelCtrl.text.trim();
    ref.read(myBoatProvider.notifier).set(MyBoat(
          lengthM: length,
          draftM: draft,
          brand: brand.isEmpty ? null : brand,
          typeId: _typeId,
          name: name.isEmpty ? null : name,
          homeMarina: _marina,
          model: model.isEmpty ? null : model,
          buildYear: year,
        ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
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
      child: SingleChildScrollView(
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
          // TÜR ÇİPLERİ — sunucu sözlüğüyle aynı 8 tür (katalog genişlemesi).
          Text(t.btTypeLabel,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String id in kBoatTypeIds)
                ChoiceChip(
                  key: ValueKey<String>('boat-type-$id'),
                  label: Text('${boatTypeEmoji(id)} ${t.boatTypeLabel(id)}'),
                  selected: _typeId == id,
                  onSelected: (_) => setState(() => _typeId = id),
                  showCheckmark: false,
                  selectedColor: DocklyColors.brandPrimary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _typeId == id
                        ? const Color(0xFFFFFFFF)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // MARKA — öneri listesi yol gösterir ama SINIRLAMAZ: 1930 model bir
          // ahşap tekne de, listede olmayan yerli üretici de serbestçe yazılır.
          RawAutocomplete<String>(
            textEditingController: _brandCtrl,
            focusNode: _brandFocus,
            optionsBuilder: (TextEditingValue v) {
              final String q = v.text.trim().toLowerCase();
              if (q.length < 2) return const Iterable<String>.empty();
              return kBoatBrandSuggestions
                  .where((String b) => b.toLowerCase().contains(q));
            },
            onSelected: (String v) => _brandText = v,
            fieldViewBuilder: (BuildContext context,
                TextEditingController ctrl,
                FocusNode focus,
                VoidCallback onFieldSubmitted) {
              return TextField(
                key: const ValueKey<String>('boat-brand-field'),
                controller: ctrl,
                focusNode: focus,
                maxLength: 60,
                onChanged: (String v) => _brandText = v,
                decoration: InputDecoration(
                  labelText: t.btBrandLabel,
                  counterText: '',
                ),
              );
            },
            optionsViewBuilder: (BuildContext context,
                void Function(String) onSelected, Iterable<String> options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 180, maxWidth: 280),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final String o in options)
                          ListTile(
                            dense: true,
                            title: Text(o),
                            onTap: () => onSelected(o),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('boat-model-field'),
            controller: _modelCtrl,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: t.btModelLabel,
              hintText: t.btModelHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('boat-year-field'),
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            maxLength: 4,
            decoration: InputDecoration(
              labelText: t.btYearLabel,
              hintText: t.btYearHint,
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
      ),
    );
  }
}
