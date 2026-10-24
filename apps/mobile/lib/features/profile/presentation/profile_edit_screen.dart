import 'package:dockly_api/dockly_api.dart' show UserProfileMe;
import 'package:dockly_core/dockly_core.dart' show AppFailure;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/profile_controller.dart';

/// PROFİL DÜZENLEME ekranı (Sosyalleşme Hafta 1A, kurucu onayı 2026-10-24).
///
/// Kaptanın toplulukta görünen kimliği: görünen ad + kısa tanıtım + deneyim
/// yılı. Sunucu beyaz listesi neyse form da o — e-posta/rol gibi alanlar
/// burada YOK. Kayıtta yalnız DEĞİŞEN alanlar gönderilir; boşaltılan bio ve
/// deneyim bilinçli olarak null yazdırılır (yanlışlıkla silme olmaz, alan
/// gerçekten boşaltıldıysa olur).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _exp = TextEditingController();

  /// Form yalnız BİR kez doldurulur — kullanıcı yazarken sunucudan gelen
  /// yeniden yükleme yazdıklarını ezmesin.
  bool _filled = false;
  bool _saving = false;
  UserProfileMe? _loaded;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _exp.dispose();
    super.dispose();
  }

  void _fillOnce(UserProfileMe p) {
    if (_filled) return;
    _filled = true;
    _loaded = p;
    _name.text = p.displayName;
    _bio.text = p.bio ?? '';
    _exp.text = p.experienceYears?.toString() ?? '';
  }

  String? _validate(L10n t) {
    final String name = _name.text.trim();
    if (name.length < 2 || name.length > 50) return t.peNameShort;
    final String exp = _exp.text.trim();
    if (exp.isNotEmpty) {
      final int? v = int.tryParse(exp);
      if (v == null || v < 0 || v > 80) return t.peExpInvalid;
    }
    return null;
  }

  Future<void> _save(L10n t) async {
    final String? problem = _validate(t);
    if (problem != null) {
      _snack(problem);
      return;
    }
    final UserProfileMe? before = _loaded;
    final String name = _name.text.trim();
    final String bio = _bio.text.trim();
    final String exp = _exp.text.trim();
    final int? expVal = exp.isEmpty ? null : int.parse(exp);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(profileSaverProvider).save(
            // Yalnız değişen alanlar gider — sunucu günlüğü sade kalır.
            displayName: name == before?.displayName ? null : name,
            bio: bio == (before?.bio ?? '') ? null : (bio.isEmpty ? null : bio),
            clearBio: bio.isEmpty && (before?.bio ?? '').isNotEmpty,
            experienceYears:
                expVal == before?.experienceYears ? null : expVal,
            clearExperience: expVal == null && before?.experienceYears != null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.peSaved)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Ham istisna metni arayüze SIZMAZ (gözden geçirme kuralı):
      // sunucu mesajı varsa o, yoksa genel kibar mesaj.
      final String text =
          error is AppFailure ? error.message : t.peSaveFailed;
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<UserProfileMe> async = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.peTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.peLoadFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (UserProfileMe p) {
          _fillOnce(p);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: <Widget>[
              Text(t.peIntro,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey<String>('pe-name'),
                controller: _name,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.peName,
                  helperText: t.peNameHelp,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('pe-bio'),
                controller: _bio,
                maxLength: 500,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: t.peBio,
                  hintText: t.peBioHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('pe-exp'),
                controller: _exp,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.peExp,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey<String>('pe-save'),
                onPressed: _saving ? null : () => _save(t),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(t.peSave),
              ),
            ],
          );
        },
      ),
    );
  }
}
