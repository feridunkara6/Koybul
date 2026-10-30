import 'package:dockly_api/dockly_api.dart' show MarinaCommunity, MyMarinaBoat;
import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_section.dart' show showSignInSheet;
import '../../boat/application/my_boat_controller.dart';
import '../../boat/domain/my_boat.dart';
import '../../boat/presentation/boat_sheet.dart' show showBoatSheet;
import '../application/marina_controller.dart';
import 'marina_community_screen.dart';

/// MARİNAM kartı — Tekne sekmesi (onaylı görsel konsept Ekran 11).
///
/// AÇIK RIZA İLKESİ: telefondaki tekne kendiliğinden sunucuya GİTMEZ;
/// "Topluluğa katıl" düğmesi tek katılım yoludur ve katılan tekne varsayılan
/// GİZLİDİR (yalnız isimsiz sayıya eklenir). "Marinada görün" ve "tip/boy/
/// marka paylaş" anahtarları sunucuda tutulur; kart sunucu kaydını tek
/// doğruluk kaynağı sayar.
class MarinamCard extends ConsumerStatefulWidget {
  const MarinamCard({super.key});

  @override
  ConsumerState<MarinamCard> createState() => _MarinamCardState();
}

class _MarinamCardState extends ConsumerState<MarinamCard> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Katılım / anahtar / eşitleme: hepsi aynı PUT ucundan geçer.
  Future<void> _put({
    required MyBoat local,
    required bool visible,
    required bool shareSpecs,
    // 0024: hikâye yalnız [withStory] true iken gönderilir.
    bool withStory = false,
    String? story,
  }) async {
    if (_busy) return;
    final String? typeCode = serverBoatTypeCode(local.typeId);
    final String? name = local.name?.trim();
    if (name == null || name.isEmpty || typeCode == null) {
      _snack(ref.read(l10nProvider).marinamNeedNameType);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(marinaGatewayProvider).upsertMyBoat(
            name: name,
            boatTypeCode: typeCode,
            lengthM: local.lengthM,
            brand: local.brand,
            // Hafta 2 (Tekne Kartı): model + yıl da sunucuya gider ki
            // kartta MODELE ÖZEL çizim seçilebilsin.
            model: local.model,
            buildYear: local.buildYear,
            marinaLocationId: local.homeMarina!.id,
            visible: visible,
            shareSpecs: shareSpecs,
            storySet: withStory,
            story: story,
          );
      if (withStory && story != null) {
        // Dürüst süreç: hikâye önce moderasyona gider, sonra kartta görünür.
        _snack(ref.read(l10nProvider).mnStorySent);
      }
      ref.invalidate(myServerBoatProvider);
      ref.invalidate(marinaCommunityProvider(local.homeMarina!.id));
    } on AppFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// TEKNENİN HİKÂYESİ (0024): kısa metin sayfası — kaydet, moderasyona
  /// gitsin; boş bırakmak hikâyeyi kaldırır (nötr durum).
  /// NOT (CI dersi 2026-10-30): metin denetleyicisi SAYFANIN İÇİNDE yaşar —
  /// dışarıda tutup kapanışta imha etmek, kapanış animasyonu süren alanı
  /// "disposed controller" ile çökertti.
  Future<void> _editStory(MyBoat local, MyMarinaBoat mine) async {
    final L10n t = ref.read(l10nProvider);
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _StorySheet(initial: mine.story ?? ''),
      ),
    );
    if (result == null || !mounted) return; // vazgeçti
    if (result.isNotEmpty && result.length < 10) {
      _snack(t.mnStoryShort);
      return;
    }
    await _put(
      local: local,
      visible: mine.visible,
      shareSpecs: mine.shareSpecs,
      withStory: true,
      story: result.isEmpty ? null : result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final bool member = auth is Authenticated && !auth.isGuest;

    // DURUM 1: hesap yok → topluluk için giriş daveti.
    if (!member) {
      return _Shell(
        t: t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.marinamNeedAccount,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 10),
            _WhiteButton(
              keyValue: 'marinam-signin',
              label: t.accCta,
              onTap: () => showSignInSheet(context),
            ),
          ],
        ),
      );
    }

    // DURUM 2: tekne/marina seçilmemiş → marina seçim daveti.
    if (boat == null || boat.homeMarina == null) {
      return _Shell(
        t: t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.marinamNeedMarina,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 10),
            _WhiteButton(
              keyValue: 'marinam-pick',
              label: t.marinaPickTitle,
              onTap: () => showBoatSheet(context, ref),
            ),
          ],
        ),
      );
    }

    final HomeMarina marina = boat.homeMarina!;
    final AsyncValue<MyMarinaBoat?> server = ref.watch(myServerBoatProvider);

    return _Shell(
      t: t,
      marinaName: marina.name,
      child: server.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ),
        ),
        error: (Object e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(e is AppFailure ? e.message : '$e',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 8),
            _WhiteButton(
              keyValue: 'marinam-retry',
              label: t.retryLabel,
              onTap: () => ref.invalidate(myServerBoatProvider),
            ),
          ],
        ),
        data: (MyMarinaBoat? mine) {
          final bool joined = mine != null && mine.marinaId == marina.id;
          if (!joined) {
            // DURUM 3: henüz katılmamış (ya da marinası değişmiş) → açık rıza.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(t.marinamJoinSub,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white.withValues(alpha: .9))),
                const SizedBox(height: 10),
                _WhiteButton(
                  keyValue: 'marinam-join',
                  label: _busy ? t.busyLabel : t.marinamJoinCta,
                  onTap: _busy
                      ? null
                      : () => _put(
                            local: boat,
                            visible: mine?.visible ?? false,
                            shareSpecs: mine?.shareSpecs ?? false,
                          ),
                ),
              ],
            );
          }
          // DURUM 4: kayıtlı → sayılar + topluluk + rıza anahtarları.
          return _JoinedBody(
            t: t,
            marinaId: marina.id,
            mine: mine,
            busy: _busy,
            onSee: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => MarinaCommunityScreen(marinaId: marina.id)),
            ),
            onVisible: (bool v) =>
                _put(local: boat, visible: v, shareSpecs: mine.shareSpecs),
            onSpecs: (bool v) =>
                _put(local: boat, visible: mine.visible, shareSpecs: v),
            onStory: () => _editStory(boat, mine),
          );
        },
      ),
    );
  }
}

/// Kart kabuğu — Kaptan Kartı ailesinden lacivert→mavi degrade.
class _Shell extends StatelessWidget {
  const _Shell({required this.t, required this.child, this.marinaName});

  final L10n t;
  final Widget child;
  final String? marinaName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[DocklyColors.brandDeep, DocklyColors.brandPrimary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Text('🏠', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                marinaName ?? t.marinamTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(t.marinamSub,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white.withValues(alpha: .75))),
          ),
          child,
        ],
      ),
    );
  }
}

class _JoinedBody extends ConsumerWidget {
  const _JoinedBody({
    required this.t,
    required this.marinaId,
    required this.mine,
    required this.busy,
    required this.onSee,
    required this.onVisible,
    required this.onSpecs,
    required this.onStory,
  });

  final L10n t;
  final String marinaId;
  final MyMarinaBoat mine;
  final bool busy;
  final VoidCallback onSee;
  final ValueChanged<bool> onVisible;
  final ValueChanged<bool> onSpecs;
  final VoidCallback onStory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<MarinaCommunity> community =
        ref.watch(marinaCommunityProvider(marinaId));
    final String total =
        community.valueOrNull != null ? '${community.valueOrNull!.total}' : '…';
    final String visible = community.valueOrNull != null
        ? '${community.valueOrNull!.visibleCount}'
        : '…';

    Widget count(String v, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: <Widget>[
              Text(v,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 8.5,
                      letterSpacing: .3,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );

    Widget toggle({
      required String keyValue,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) =>
        Row(children: <Widget>[
          Expanded(
            child: Text(title,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Switch(
            key: ValueKey<String>(keyValue),
            value: value,
            onChanged: busy ? null : onChanged,
            activeTrackColor: DocklyColors.success,
          ),
        ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(children: <Widget>[
          count(total, t.mcTotalCap),
          const SizedBox(width: 10),
          count(visible, t.mcVisibleCap),
        ]),
        const SizedBox(height: 10),
        _WhiteButton(
            keyValue: 'marinam-see', label: t.marinamSeeCta, onTap: onSee),
        const SizedBox(height: 4),
        toggle(
          keyValue: 'marinam-visible',
          title: t.marinamVisibleToggle,
          value: mine.visible,
          onChanged: onVisible,
        ),
        toggle(
          keyValue: 'marinam-specs',
          title: t.marinamSpecsToggle,
          value: mine.shareSpecs,
          onChanged: onSpecs,
        ),
        // TEKNENİN HİKÂYESİ (0024): kart vitrinine kısa tanıtım — her
        // kaydediş moderasyona düşer; durum burada dürüstçe görünür.
        InkWell(
          key: const ValueKey<String>('marinam-story'),
          borderRadius: BorderRadius.circular(10),
          onTap: busy ? null : onStory,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: <Widget>[
              Expanded(
                child: Text(
                  mine.story == null ? t.mnStoryAdd : t.mnStoryTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (mine.story != null && mine.storyStatus == 'pending')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(t.rtPendingChip,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: DocklyColors.warning)),
                )
              else if (mine.story != null && mine.storyStatus == 'rejected')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(t.evRejectedChip,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: DocklyColors.error)),
                ),
              const SizedBox(width: 6),
              const Text('›',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        Text(
          '🔒 ${t.marinamPrivacyNote}',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: Colors.white.withValues(alpha: .75)),
        ),
      ],
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton(
      {required this.keyValue, required this.label, required this.onTap});

  final String keyValue;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey<String>(keyValue),
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: DocklyColors.brandDeep,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}


/// Hikâye yazma sayfası (0024) — denetleyici BU durumun malıdır; sayfa
/// kapanırken Flutter kendi düzeninde imha eder (yakıt sayfası deseni).
class _StorySheet extends ConsumerStatefulWidget {
  const _StorySheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_StorySheet> createState() => _StorySheetState();
}

class _StorySheetState extends ConsumerState<_StorySheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.mnStoryTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('marinam-story-field'),
              controller: _ctrl,
              minLines: 3,
              maxLines: 6,
              maxLength: 600,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: t.mnStoryHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('marinam-story-save'),
              onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
              child: Text(t.saveLabel),
            ),
            const SizedBox(height: 6),
            Text(t.mnStoryModNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
