import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../location/application/location_controller.dart';
import '../../weather/application/weather_controller.dart';
import '../application/community_controller.dart';
import '../application/reputation_controller.dart';
import 'note_card.dart';

/// NOT BIRAKMA — 3 adım, ama kullanıcı yalnız İKİSİNİ doldurur.
///
/// Tasarım sözü: "gereksiz bilgi isteme, sistem otomatik doldursun."
/// Nokta, tarih ve o anki hava önceden gelir; kaptan yalnız tipi ve metni verir.
class NoteComposerScreen extends ConsumerStatefulWidget {
  const NoteComposerScreen({
    required this.locationId,
    required this.locationName,
    required this.position,
    this.devicePosition,
    super.key,
  });

  final String locationId;
  final String locationName;

  /// Noktanın konumu (hava tahmini için).
  final GeoPoint position;

  /// Kaptanın GERÇEK konumu — status/hazard notları bunu ister.
  final GeoPoint? devicePosition;

  @override
  ConsumerState<NoteComposerScreen> createState() => _NoteComposerScreenState();
}

/// Bu ekrandan yazılabilen not tipleri.
///
/// SEYİR NOTU BURADA YOK: iki nokta ister (nereden → nereye) ve bu ekran tek
/// bir koydan açılıyor, varış noktasını soracak bir yer yok. Listede duruyordu
/// ama gönderilince sunucu "seyir notu iki nokta ister" diye geri çeviriyordu —
/// kaptan yazdığı notu kaybediyordu (hata 2026-08). Varış seçici gelene kadar
/// seçenek gösterilmiyor; sunucu tarafı olduğu gibi duruyor.
const List<NoteKind> kComposerKinds = <NoteKind>[
  NoteKind.status,
  NoteKind.hazard,
  NoteKind.experience,
];

class _NoteComposerScreenState extends ConsumerState<NoteComposerScreen> {
  NoteKind _kind = NoteKind.experience;
  final TextEditingController _body = TextEditingController();
  DateTime _observed = DateTime.now();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Kaptan noktanın yanındaysa muhtemelen "şu anki durumu" paylaşacaktır.
    if (widget.devicePosition != null) _kind = NoteKind.status;
  }

  /// GÜNCEL konum. Yapıcıdan gelen değer yalnız BAŞLANGIÇTIR: kaptan bu ekran
  /// açıkken "Konumumu kullan"a basarsa izin gelir ve kilitli tipler açılmalı.
  ///
  /// `read` KULLANILIR: bu getter `_submit` gibi build DIŞINDAN da çağrılıyor
  /// ve orada `watch` etmek build'e bağlı olmayan bir abonelik açardı.
  /// Yeniden çizim `build`'in kendi `watch`'ı ile sağlanır.
  GeoPoint? get _device => ref.read(devicePositionProvider) ?? widget.devicePosition;

  /// Konum izni ister. Reddedilirse kibar bir açıklama çıkar; ekran kapanmaz,
  /// kaptan "Deneyim" notu yazmaya devam edebilir.
  Future<void> _askLocation() async {
    final L10n t = ref.read(l10nProvider);
    await ref.read(locationControllerProvider.notifier).locateMe();
    if (!mounted) return;
    if (ref.read(devicePositionProvider) == null) _snack(t.noteLocateFailed);
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int _maxChars(NoteKind k) => switch (k) {
        NoteKind.status => 280,
        NoteKind.hazard => 500,
        _ => 4000,
      };

  bool _needsGps(NoteKind k) => k == NoteKind.status || k == NoteKind.hazard;

  /// O anki rüzgâr — kullanıcıdan İSTENMEZ, tahminden okunup nota dondurulur.
  NoteWind? _currentWind() {
    final AsyncValue<WeatherForecast> wx = ref.read(
      weatherForecastProvider(weatherKeyFor(widget.position.lat, widget.position.lon)),
    );
    final WeatherForecast? f = wx.valueOrNull;
    if (f == null || f.points.isEmpty) return null;
    final ForecastPoint p = f.points.first;
    final L10n t = ref.read(l10nProvider);
    return NoteWind(kn: p.windKn.round(), dirTr: t.compassDir(_dirCode(p.windDirDeg)));
  }

  static String _dirCode(int deg) {
    const List<String> codes = <String>['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    return codes[(((deg % 360) + 22) ~/ 45) % 8];
  }

  Future<void> _submit() async {
    final L10n t = ref.read(l10nProvider);
    if (_needsGps(_kind) && _device == null) {
      _snack(t.noteNeedLocation);
      return;
    }
    // Messenger ÖNCEDEN yakalanır: pop'tan sonra bu context ölür ve
    // ScaffoldMessenger.of(context) patlar (sessiz bir çökme kaynağı).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final Note note = await ref.read(communityGatewayProvider).createNote(
            locationId: widget.locationId,
            kind: _kind,
            body: _body.text.trim(),
            observedOn: _ymd(_observed),
            position: _needsGps(_kind) ? _device : null,
            wind: _currentWind(),
          );
      if (!mounted) return;
      ref.read(noteOverridesProvider.notifier).prepend(widget.locationId, note);
      // Katkı sayaçları (Profil bloğu, Teknem kartı, Katkılarım) yeni notu
      // hemen göstersin: özet bir sonraki okumada sunucudan tazelenir.
      ref.invalidate(reputationSummaryProvider);
      Navigator.of(context).pop(true);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(note.status == 'approved' ? t.notePublished : t.noteSubmitted),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(_message(error, t));
    }
  }

  /// Sunucu zaten yerelleştirilmiş bir `message` gönderir; ham istisna metni
  /// arayüze SIZMAZ (docs/26 §13, occupancy_row ile aynı desen).
  String _message(Object error, L10n t) {
    if (error is ValidationFailure) return error.message;
    if (error is AppFailure) return error.message;
    return t.noteTooFar;
  }

  void _snack(String text) {
    final ScaffoldMessengerState m = ScaffoldMessenger.of(context);
    m
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final int max = _maxChars(_kind);
    final NoteWind? wind = _currentWind();
    final String body = _body.text.trim();
    final GeoPoint? device = ref.watch(devicePositionProvider) ?? widget.devicePosition;
    final bool locating = ref.watch(locationControllerProvider) == LocationStatus.loading;
    // Konum eksikse düğme de KAPALIDIR: sebep yukarıda yazıyor, kaptan
    // yazdıktan sonra reddedilmek yerine baştan görsün.
    final bool canSend = body.length >= 3 &&
        body.length <= max &&
        !_sending &&
        !(_needsGps(_kind) && device == null);

    return Scaffold(
      appBar: AppBar(title: Text(t.noteComposerTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _StepLabel(index: 1, text: t.noteStep1),
          for (final NoteKind k in kComposerKinds)
            _KindTile(
              kind: k,
              selected: _kind == k,
              // Konum gerektiren tip, konum yokken SEÇİLEMEZ ve sebebi altta
              // yazar. Eskiden seçilebiliyordu; kaptan notu yazıyor, ancak
              // "Gönder"e bastıktan sonra reddediliyordu.
              locked: _needsGps(k) && device == null,
              onTap: () => setState(() => _kind = k),
            ),
          if (device == null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    t.noteKindNeedsGps,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('note-locate'),
                  onPressed: locating ? null : _askLocation,
                  child: Text(t.locUseBtn),
                ),
              ],
            ),
          const SizedBox(height: 18),
          _StepLabel(index: 2, text: t.noteStep2),
          TextField(
            key: const ValueKey<String>('note-body'),
            controller: _body,
            maxLines: 6,
            maxLength: max,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: t.noteBodyHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _StepLabel(index: 3, text: t.noteStep3),
              const SizedBox(width: 6),
              Text(
                '· ${t.noteAutoFilled}',
                style: theme.textTheme.labelSmall?.copyWith(color: DocklyColors.success),
              ),
            ],
          ),
          _ContextRow(icon: DocklyIcons.place, label: widget.locationName),
          _ContextRow(
            icon: DocklyIcons.eventNoteOutlined,
            label: _ymd(_observed),
            trailing: t.editLabel,
            onTap: _pickDate,
          ),
          if (wind != null)
            _ContextRow(
              icon: DocklyIcons.navigation,
              label: '${t.noteWindLabel}: ${wind.kn} kn ${wind.dirTr}',
            ),
          if (_needsGps(_kind))
            _ContextRow(
              icon: DocklyIcons.verified,
              label: device != null ? t.noteGpsOk : t.noteNeedLocation,
              danger: device == null,
            ),
          const SizedBox(height: 14),
          DocklyButton(
            key: const ValueKey<String>('note-submit'),
            label: t.noteSubmit,
            loading: _sending,
            onPressed: canSend ? _submit : null,
          ),
          const SizedBox(height: 8),
          Text(
            // Gönderim ÖNCESİ moderasyon bildirimi (09 §10.2 onaylı mikro-metin).
            // "Notun alındı" metni yalnız gönderimden SONRA çıkar.
            t.noteModerationNotice,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _observed.isAfter(now) ? now : _observed,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _observed = picked);
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$index · $text',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}

class _KindTile extends ConsumerWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final NoteKind kind;
  final bool selected;
  final VoidCallback onTap;

  /// Konum olmadan seçilemeyen tip: soluk çizilir, dokunuşa yanıt vermez.
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final Color color = noteKindColor(context, kind);
    final String hint = switch (kind) {
      NoteKind.status => t.noteKindStatusHint,
      NoteKind.hazard => t.noteKindHazardHint,
      NoteKind.experience => t.noteKindExperienceHint,
      NoteKind.passage => t.noteKindPassageHint,
    };
    final bool active = selected && !locked;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: InkWell(
        key: ValueKey<String>('note-kind-${kind.wire}'),
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.08) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? color : theme.colorScheme.outline,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              DocklyIcon(
                locked ? DocklyIcons.lockOutline : noteKindIcon(kind),
                size: 18,
                color: locked ? theme.colorScheme.onSurfaceVariant : color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      t.noteKindLabel(kind.wire),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final DocklyIconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = danger ? DocklyColors.error : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            DocklyIcon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }
}
