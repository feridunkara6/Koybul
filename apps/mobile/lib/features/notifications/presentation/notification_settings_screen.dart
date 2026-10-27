import 'package:dockly_api/dockly_api.dart' show NotificationPrefs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../admin/application/admin_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../application/push_controller.dart';

/// BİLDİRİM AYARLARI (push paketi, kurucu onayı 2026-10-27).
///
/// İki küme: ANLIK bildirimler (sunucu — cihaz tercihi) ve BAKIM hatırlatması
/// (tamamen cihazda; bakım verisi gibi tercihi de telefondan çıkmaz).
/// Moderasyon anahtarı yalnız admin hesaba çizilir — başkasına gürültü olurdu.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _busy = false;

  Future<void> _toggle({bool? community, bool? events, bool? moderation}) async {
    final L10n t = ref.read(l10nProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final NotificationPrefs? updated = await ref
          .read(pushRegistrarProvider)
          .updatePrefs(community: community, events: events, moderation: moderation);
      if (updated == null) throw Exception('no-device');
      // Taze tercihleri ekrana yansıt (provider upsert'i yeniden koşturur).
      ref.invalidate(pushPrefsProvider);
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.ntfLoadFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool signedIn = auth is Authenticated && !auth.isGuest;
    final bool isAdmin = ref.watch(isAdminProvider);
    final bool maintOn = ref.watch(maintReminderEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.ntfTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: <Widget>[
          _groupTitle(theme, t.ntfPushGroup),
          if (!signedIn)
            _noteCard(theme, t.ntfGuestNote, key: 'ntf-guest-note')
          else
            ref.watch(pushPrefsProvider).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (Object e, _) =>
                      _noteCard(theme, t.ntfLoadFailed, key: 'ntf-error-note'),
                  data: (NotificationPrefs? prefs) => prefs == null
                      ? _noteCard(theme, t.ntfPermNote, key: 'ntf-perm-note')
                      : _card(theme, <Widget>[
                          SwitchListTile(
                            key: const ValueKey<String>('ntf-community'),
                            title: Text(t.ntfCommunity),
                            value: prefs.community,
                            onChanged: _busy
                                ? null
                                : (bool v) => _toggle(community: v),
                          ),
                          SwitchListTile(
                            key: const ValueKey<String>('ntf-events'),
                            title: Text(t.ntfEvents),
                            value: prefs.events,
                            onChanged:
                                _busy ? null : (bool v) => _toggle(events: v),
                          ),
                          if (isAdmin)
                            SwitchListTile(
                              key: const ValueKey<String>('ntf-moderation'),
                              title: Text(t.ntfModeration),
                              value: prefs.moderation,
                              onChanged: _busy
                                  ? null
                                  : (bool v) => _toggle(moderation: v),
                            ),
                        ]),
                ),
          const SizedBox(height: 18),
          _card(theme, <Widget>[
            SwitchListTile(
              key: const ValueKey<String>('ntf-maint'),
              title: Text(t.ntfMaint),
              subtitle: Text(t.ntfMaintHint),
              value: maintOn,
              onChanged: (bool v) =>
                  ref.read(maintReminderEnabledProvider.notifier).set(v),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _groupTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _card(ThemeData theme, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
        ),
        child: Column(children: children),
      );

  Widget _noteCard(ThemeData theme, String text, {required String key}) =>
      Container(
        key: ValueKey<String>(key),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: .55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      );
}
