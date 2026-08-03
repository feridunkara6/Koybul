import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../domain/auth_gateway.dart';

/// S-03 Giriş ekranı (docs/21). Apple/Google/E-posta/Telefon + Misafir modu.
/// E-posta/Telefon detay ekranları 2.4c'de; şimdilik bilgi mesajı gösterir.
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

  void _comingSoon() {
    _showMessage('Bu giriş yöntemi çok yakında.');
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
              const Text('Hoş geldin, kaptan.', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              DocklyButton(
                label: 'Apple ile devam et',
                icon: DocklyIcons.apple,
                loading: _busyKind == AuthProviderKind.apple,
                onPressed: busy ? null : () => _signIn(AuthProviderKind.apple),
              ),
              const SizedBox(height: 12),
              DocklyButton(
                label: 'Google ile devam et',
                icon: DocklyIcons.google,
                loading: _busyKind == AuthProviderKind.google,
                onPressed: busy ? null : () => _signIn(AuthProviderKind.google),
              ),
              const SizedBox(height: 12),
              DocklyButton(
                label: 'E-posta ile devam et',
                variant: DocklyButtonVariant.secondary,
                icon: DocklyIcons.mailOutline,
                onPressed: busy ? null : _comingSoon,
              ),
              const SizedBox(height: 12),
              DocklyButton(
                label: 'Telefon ile devam et',
                variant: DocklyButtonVariant.secondary,
                icon: DocklyIcons.phoneOutlined,
                onPressed: busy ? null : _comingSoon,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed:
                    busy ? null : () => _signIn(AuthProviderKind.guest),
                child: const Text('Misafir olarak gez'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
