import 'package:dockly_api/dockly_api.dart' show QaCreateResult, kQaCategories;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../premium/presentation/premium_screen.dart';
import '../application/qa_controller.dart';

/// SORU OLUŞTURMA (Blog V1 — onaylı görsel konsept Ekran 5).
///
/// Doğrulama İKİ katmanlı: burada kibar mesajla (başlık 10-140, detay 30+),
/// sunucuda zod + DB CHECK ile. Premium kapısı SUNUCUDADIR: ücretsiz üyenin
/// "yayınla" denemesi 403 alır ve paket ekranına taşınır — kilit arayüzde
/// taklit edilmez. Gönderim sonucu dürüsttür: yayınlandı ya da denetimde.
class QaComposerScreen extends ConsumerStatefulWidget {
  const QaComposerScreen({super.key});

  @override
  ConsumerState<QaComposerScreen> createState() => _QaComposerScreenState();
}

class _QaComposerScreenState extends ConsumerState<QaComposerScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  String _category = kQaCategories.first;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final L10n t = ref.read(l10nProvider);
    final String title = _title.text.trim();
    final String body = _body.text.trim();
    if (title.length < 10 || title.length > 140) {
      _snack(t.qaValTitle);
      return;
    }
    if (body.length < 30) {
      _snack(t.qaValBody);
      return;
    }
    setState(() => _busy = true);
    try {
      final QaCreateResult res = await ref.read(qaGatewayProvider).createQuestion(
            category: _category,
            title: title,
            body: body,
          );
      // Akış tazelenir: yayınlanan soru listede, bekleyen soru kuyruktadır.
      ref.invalidate(qaFeedProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _snack(res.pending ? t.qaPendingNote : t.qaPublishedNote);
      }
    } on ForbiddenFailure catch (f) {
      // Premium kapısı: dürüst mesaj + paket ekranı (sıkmama sözleşmesi:
      // yalnız kullanıcının kendi denemesi üzerine açılır).
      _snack(f.message);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
        );
      }
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.qaAskCta)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String code in kQaCategories)
                ChoiceChip(
                  key: ValueKey<String>('qa-cat-$code'),
                  label: Text(t.qaCategoryLabel(code)),
                  selected: _category == code,
                  onSelected: (_) => setState(() => _category = code),
                  selectedColor: DocklyColors.brandPrimary,
                  showCheckmark: false,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: _category == code
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('qa-title'),
            controller: _title,
            enabled: !_busy,
            maxLength: 140,
            decoration: InputDecoration(
              hintText: t.qaTitleHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('qa-body'),
            controller: _body,
            enabled: !_busy,
            minLines: 5,
            maxLines: 10,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: t.qaBodyHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '🛡️ ${t.qaRulesNote} ${t.qaPendingNote}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey<String>('qa-submit'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? t.busyLabel : t.qaSubmit),
          ),
        ],
      ),
    );
  }
}
