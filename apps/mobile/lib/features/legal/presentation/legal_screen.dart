import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_strings.dart';
import '../data/legal_content.dart';
import '../domain/legal_doc.dart';

/// YASAL METİNLER — liste ekranı (Faz 0).
///
/// Üç belge: gizlilik, KVKK aydınlatma, kullanım koşulları. İçerik uygulamanın
/// içindedir; ÇEVRİMDIŞI okunur — kaptan denizde de bakabilmeli, ve mağaza
/// incelemesi de internetsiz bir cihazda bu ekranı açabilmeli.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final List<LegalDoc> docs = legalDocs(ref.watch(appLocaleProvider));
    return Scaffold(
      appBar: AppBar(title: Text(t.legalTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Text(
            t.legalLead,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          for (final LegalDoc d in docs) ...<Widget>[
            _DocRow(
              doc: d,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => LegalDocScreen(docId: d.id)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text(
            L10n.fmt(t.legalUpdatedFmt, kLegalUpdated),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});

  final LegalDoc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('legal-${doc.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DocklyIcon(doc.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(doc.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(doc.summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DocklyIcon(DocklyIcons.arrowForward,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek yasal belgenin tam metni.
class LegalDocScreen extends ConsumerWidget {
  const LegalDocScreen({required this.docId, super.key});

  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final LegalDoc? doc = legalDocById(ref.watch(appLocaleProvider), docId);
    if (doc == null) {
      // Kimlik bilinmiyorsa boş ekran yerine dürüst bir satır.
      return Scaffold(
        appBar: AppBar(title: Text(t.legalTitle)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.legalMissing, style: theme.textTheme.bodyMedium),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          Text(
            L10n.fmt(t.legalUpdatedFmt, doc.updated),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final LegalSection s in doc.sections) ...<Widget>[
            Text(
              s.heading,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final String p in s.paragraphs) _Paragraph(text: p),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// Paragraf. '· ' ile başlayanlar madde olarak girintili çizilir.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool bullet = text.startsWith('· ');
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: bullet ? 12 : 0),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }
}
