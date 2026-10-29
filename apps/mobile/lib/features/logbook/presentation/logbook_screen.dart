import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_gate.dart';
import '../application/logbook_controller.dart';
import '../domain/log_entry.dart';

/// KAPTANIN GÜNLÜĞÜ ekranı (kullanıcı onayı 2026-08): seyir notları — en yeni
/// başta. "+" yeni giriş açar; aktif rota varsa bağlam kendiliğinden gelir.
class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.logbookTitle)),
      floatingActionButton: FloatingActionButton.extended(
        // Defter sekmesindeki not FAB'ıyla Hero çakışmasın (ikisi de
        // ağaçta olabilir: Defter sekme + Profil'den açılan bu ekran).
        heroTag: 'logbook-fab',
        key: const ValueKey<String>('logbook-new'),
        onPressed: () => showLogEntryEditor(context, ref),
        icon: const DocklyIcon(DocklyIcons.edit, size: 18, color: Colors.white),
        label: Text(t.logbookNew),
        backgroundColor: DocklyColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: const LogbookBody(),
    );
  }
}

/// Günlük GÖVDESİ (v2.0: Defter sekmesinin "Notlar" segmenti de kullanır —
/// tek kaynak, iki yüzey). Boş durum + kayıt listesi.
///
/// NOT (v2.0, 2026-08): turun örnek-not kancası KALDIRILDI — turun 8. adımı
/// artık Teknem'i anlatıyor ve bu gövde iki yüzeyde birden yaşadığı için
/// aynı GlobalKey iki kez ağaca girebilirdi (çift-anahtar çökmesi riski).
/// Notlar'a tur adımı dönerse örnek kart DeckScreen içinde kurulmalı.
class LogbookBody extends ConsumerWidget {
  const LogbookBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<LogEntry> entries = ref.watch(logbookProvider);
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.logbookEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    // AY GRUPLARI (mock_gunluk, kurucu onayı 2026-10-27): liste zaten en
    // yeni başta sıralı gelir — ay değiştikçe "EKİM 2026" başlığı atılır.
    // monthLong değerleri l10n'da HAZIR BÜYÜK gelir (Türkçe İ/I tuzağı:
    // kodda .toUpperCase() çağrılmaz — 'Ekim' → 'EKIM' olurdu).
    final List<Widget> children = <Widget>[];
    int? shownYm;
    for (final LogEntry e in entries) {
      final DateTime d = DateTime.fromMillisecondsSinceEpoch(e.dateMs);
      final int ym = d.year * 100 + d.month;
      if (ym != shownYm) {
        shownYm = ym;
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 2 : 10, 4, 8),
          child: Text(
            '${t.monthLong[d.month - 1]} ${d.year}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ));
      }
      children.add(_LogEntryCard(entry: e));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: children,
    );
  }
}

/// Tek günlük girişi kartı: tarih + (varsa) başlık + bağlam satırı + not.
///
/// SİLME (P0, UX denetimi 2026-08 — kullanıcı onaylı): karttaki çöp ikonu
/// KALDIRILDI — tek dokunuşla geri alınamaz silme, kaptanın en kişisel
/// verisi (anıları) için fazla riskliydi. Yeni akış: kartı SOLA KAYDIR →
/// giriş silinir + 5 saniyelik "Geri al" snackbar'ı çıkar. Geri al, kaydı
/// tarih sırası bozulmadan geri getirir (controller.restore).
class _LogEntryCard extends ConsumerStatefulWidget {
  const _LogEntryCard({required this.entry});

  final LogEntry entry;

  @override
  ConsumerState<_LogEntryCard> createState() => _LogEntryCardState();
}

class _LogEntryCardState extends ConsumerState<_LogEntryCard> {
  /// Kart KAPALI başlar: not 2 satır önizlemedir (mock_gunluk) — dokununca
  /// açılır/kapanır; uzun anılar listeyi boğmaz ama kaybolmaz da.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final LogEntry entry = widget.entry;
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(entry.dateMs);
    final bool hasTitle = entry.title != null && entry.title!.isNotEmpty;
    final String? ctx = entry.ctxRoute == null
        ? null
        : entry.ctxNm == null
            ? entry.ctxRoute
            : '${entry.ctxRoute} · ≈ ${entry.ctxNm! >= 10 ? entry.ctxNm!.round() : entry.ctxNm!.toStringAsFixed(1)} ${t.nmUnit}';
    // TARİH ROZETİ (mock_gunluk): gün büyük + kısa ay — yıl ay başlığında.
    final Widget dateBadge = Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: DocklyColors.brandPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('${d.day}',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: DocklyColors.brandPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1)),
          const SizedBox(height: 2),
          Text(t.monthShort[d.month - 1],
              style: theme.textTheme.labelSmall?.copyWith(
                  color: DocklyColors.brandPrimary,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
    final Widget card = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            dateBadge,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Başlıksız giriş dürüstçe "Başlıksız giriş" der (soluk).
                  Text(hasTitle ? entry.title! : t.logbookUntitled,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            hasTitle ? FontWeight.w800 : FontWeight.w700,
                        color: hasTitle
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 3),
                  Text(entry.text,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4)),
                  if (ctx != null) ...<Widget>[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: DocklyColors.accentTurquoise
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const DocklyIcon(DocklyIcons.navigation,
                              size: 11, color: DocklyColors.accentTurquoise),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(ctx,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Kaydırınca arkada beliren kırmızı "sil" zemini — yalnız sola kaydırma.
    final Widget deleteBg = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        color: DocklyColors.error.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const DocklyIcon(DocklyIcons.deleteOutline,
          size: 20, color: Colors.white),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey<String>('log-dismiss-${entry.id}'),
        direction: DismissDirection.endToStart,
        background: deleteBg,
        onDismissed: (_) {
          // Kart birazdan ağaçtan düşer; snackbar'daki Geri al o esnada
          // çalışacağı için ref/context ÖNCE yakalanır (dispose güvenliği).
          final LogbookController controller =
              ref.read(logbookProvider.notifier);
          final ScaffoldMessengerState messenger =
              ScaffoldMessenger.of(context);
          controller.remove(entry.id);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(t.logbookDeleted),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: t.undoLabel,
                  onPressed: () => controller.restore(entry),
                ),
              ),
            );
        },
        child: card,
      ),
    );
  }
}

/// YENİ GİRİŞ düzenleyicisi (alt sayfa).
///
/// BAĞIMSIZ GÜNLÜK (kurucu isteği 2026-10-29): günlük rotaya ZORUNLU
/// bağlanmaz — bağlam yalnız [logContext] AÇIKÇA verilirse eklenir (örn.
/// rota kaydı snackbar'ındaki "Not düş" yolu) ve ✕ ile kaldırılabilir.
/// Günlük/Defter FAB'ından açılan yeni kayıt aktif rotadan habersizdir.
///
/// HESAP KAPISI (Defter paketi 2026-10-27): günlük girişleri hesapla gezer —
/// tüm çağrı noktaları (Defter FAB'ı, Günlük ekranı, rota kartı) bu tek
/// kapıdan geçer. Giriş/kayıt tamamlanırsa düzenleyici OTOMATİK açılır.
Future<void> showLogEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  LogContext? logContext,
}) {
  return requireAccount(
    context,
    ref,
    message: ref.read(l10nProvider).gateLogMsg,
    onAllowed: () async {
      // Otomatik rota bağlamı KALDIRILDI (2026-10-29): yalnız açık istek.
      final LogContext? ctx = logContext;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _LogEntryEditor(initialContext: ctx),
        ),
      );
    },
  );
}

class _LogEntryEditor extends ConsumerStatefulWidget {
  const _LogEntryEditor({required this.initialContext});

  final LogContext? initialContext;

  @override
  ConsumerState<_LogEntryEditor> createState() => _LogEntryEditorState();
}

class _LogEntryEditorState extends ConsumerState<_LogEntryEditor> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _text = TextEditingController();
  late LogContext? _ctx = widget.initialContext;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Hazır başlangıcı metnin BAŞINA ekler (mock_gunluk): "Rüzgâr: " gibi.
  /// İmleç eklemenin sonuna konur — kaptan kaldığı yerden yazar.
  void _prependStarter(String label) {
    final String add = '$label: ';
    final String cur = _text.text;
    _text.value = TextEditingValue(
      text: '$add$cur',
      selection: TextSelection.collapsed(offset: add.length),
    );
  }

  Future<void> _save() async {
    final String text = _text.text.trim();
    if (text.isEmpty || _saving) return; // boş giriş kaydedilmez
    setState(() => _saving = true);
    final int now = DateTime.now().millisecondsSinceEpoch;
    await ref.read(logbookProvider.notifier).add(LogEntry(
          id: 'l$now',
          dateMs: now,
          text: text,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          ctxRoute: _ctx?.routeName,
          ctxNm: _ctx?.distanceNm,
          ctxStops: _ctx?.stops,
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final LogContext? ctx = _ctx;
    // KAYDIRILABİLİR (CI dersi "rota paketi 1" taşması): çipler + ipucuyla
    // uzayan içerik dar/kısa ekranda sabit boy iddia etmez, sığmazsa kayar.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(t.logbookNew,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (ctx != null) ...<Widget>[
            const SizedBox(height: 10),
            // Otomatik rota bağlamı — ✕ ile kaldırılabilir (onaylı tasarım).
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(
                color: DocklyColors.accentTurquoise.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const DocklyIcon(DocklyIcons.navigation,
                      size: 13, color: DocklyColors.accentTurquoise),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ctx.routeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('logbook-ctx-remove'),
                    visualDensity: VisualDensity.compact,
                    icon: const DocklyIcon(DocklyIcons.close, size: 14),
                    onPressed: () => setState(() => _ctx = null),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // ÖNCE METİN (mock_gunluk, kurucu onayı 2026-10-27): günlükte asıl
          // iş hikâyedir — kutu büyük, imleç hazır; başlık en sona taşındı.
          TextField(
            controller: _text,
            maxLines: 6,
            minLines: 4,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: t.logbookTextHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          // HAZIR BAŞLANGIÇLAR: dokununca "Etiket: " metnin başına eklenir,
          // imleç eklemenin sonuna konur — yazmaya oradan devam edilir.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final (String, String) s in <(String, String)>[
                ('starter-wind', t.starterWind),
                ('starter-anchor', t.starterAnchor),
                ('starter-issue', t.starterIssue),
                ('starter-view', t.starterView),
              ])
                ActionChip(
                  key: ValueKey<String>(s.$1),
                  label: Text(s.$2),
                  labelStyle: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _prependStarter(s.$2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t.logbookStartersHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: t.logbookTitleHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>('logbook-save'),
              onPressed: _saving ? null : _save,
              child: Text(t.logbookSaveCta),
            ),
          ),
        ],
      ),
    );
  }
}
