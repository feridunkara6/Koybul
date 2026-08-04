import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/auth_controller.dart';
import '../domain/auth_gateway.dart';

/// S-03 Giriş ekranı (docs/21). Apple/Google + Misafir modu.
/// UX kararı (2026-08): ÇALIŞMAYAN seçenek gösterilmez — E-posta/Telefon
/// düğmeleri gerçek akışları gelene dek ekrandan kaldırıldı ("çok yakında"
/// duvarı ürünü yarım gösteriyordu). Metinler l10n'dadır (4 dil).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  AuthProviderKind? _busyKind;

  Future<void> _signIn(AuthProviderKind kind) async {
    setState(() => _busyKind = kind);
    try {
      await ref.read(authControllerProvider.notifier).signIn(kind);
    } on AppFailure catch (failure) {
      _showMessage(failure.message);
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busyKind != null;
    final L10n t = ref.watch(l10nProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Koybul',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(t.signInWelcome, textAlign: TextAlign.center),
              const SizedBox(height: 40),
              DocklyButton(
                label: t.appleBtn,
                icon: DocklyIcons.apple,
                loading: _busyKind == AuthProviderKind.apple,
                onPressed: busy ? null : () => _signIn(AuthProviderKind.apple),
              ),
              const SizedBox(height: 12),
              DocklyButton(
                label: t.googleBtn,
                icon: DocklyIcons.google,
                loading: _busyKind == AuthProviderKind.google,
                onPressed: busy ? null : () => _signIn(AuthProviderKind.google),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed:
                    busy ? null : () => _signIn(AuthProviderKind.guest),
                child: Text(t.guestBtn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
