import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/presentation/account_gate.dart';
import '../application/community_controller.dart';

/// YORUM YAZMA. Yorum bir DEĞERLENDİRMEdir (yıldız zorunlu, nokta başına tek);
/// not ise bir BİLGİdir. İkisi bilinçli olarak ayrı tutulur.
class ReviewComposerScreen extends ConsumerStatefulWidget {
  const ReviewComposerScreen({
    required this.idOrSlug,
    required this.locationName,
    super.key,
  });

  final String idOrSlug;
  final String locationName;

  @override
  ConsumerState<ReviewComposerScreen> createState() => _ReviewComposerScreenState();
}

class _ReviewComposerScreenState extends ConsumerState<ReviewComposerScreen> {
  int _rating = 0;
  final TextEditingController _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final L10n t = ref.read(l10nProvider);
    // Messenger pop'tan ÖNCE yakalanır (ölü context'ten okumak çökertir).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(communityGatewayProvider).createReview(
            idOrSlug: widget.idOrSlug,
            overallRating: _rating,
            body: _body.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.reviewSubmitted)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      // Ham istisna metni arayüze SIZMAZ: 409 çakışması makine kodundan tanınır.
      final String text = error is ConflictFailure && error.code == 'duplicate-review'
          ? t.reviewDuplicate
          : (error is AppFailure ? error.message : t.reviewDuplicate);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.reviewWriteCta)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Text(widget.locationName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          Text(
            t.reviewRatingLabel,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (int i = 1; i <= 5; i++)
                IconButton(
                  key: ValueKey<String>('review-star-$i'),
                  onPressed: () => setState(() => _rating = i),
                  icon: DocklyIcon(
                    i <= _rating ? DocklyIcons.star : DocklyIcons.starBorder,
                    size: 30,
                    color: DocklyColors.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('review-body'),
            controller: _body,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: t.reviewBodyHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.reviewSubmitted,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          DocklyButton(
            key: const ValueKey<String>('review-submit'),
            label: t.noteSubmit,
            loading: _sending,
            onPressed: _rating > 0 && !_sending ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Yorum yazma akışı: üyelik kapısı → düzenleyici.
Future<void> openReviewComposer(
  BuildContext context,
  WidgetRef ref, {
  required String idOrSlug,
  required String locationName,
}) async {
  final L10n t = ref.read(l10nProvider);
  await requireAccount(
    context,
    ref,
    message: t.gateReviewMsg,
    onAllowed: () => Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ReviewComposerScreen(idOrSlug: idOrSlug, locationName: locationName),
      ),
    ),
  );
}
