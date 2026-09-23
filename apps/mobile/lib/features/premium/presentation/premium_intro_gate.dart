import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../data/premium_intro_store.dart';
import 'premium_screen.dart';

/// KAYIT SONRASI PREMIUM TANITIMI (kurucu isteği 2026-09-23).
///
/// Kural: kullanıcı BU CİHAZDA ilk kez hesaplı üye olduğunda (kayıt ya da
/// misafirlikten üyeliğe geçiş) premium paket ekranı BİR KEZ kendiliğinden
/// açılır — kurucunun deyişiyle "hesap açana premium önüne gelsin".
///
/// SIKMAMA SÖZLEŞMESİYLE UZLAŞMA (K7): bu bir açılış paywall'u DEĞİLDİR —
/// uygulama açılışında ve oturum GERİ YÜKLEMESİNDE (AuthRestoring→üye) asla
/// çıkmaz; yalnız kullanıcının kendi giriş eylemini izler, cihaz başına tek
/// seferdir ve geri tuşuyla anında kapanır. Satın alma dayatması yoktur.
class PremiumIntroGate extends ConsumerWidget {
  const PremiumIntroGate({required this.child, super.key});

  final Widget child;

  Future<void> _maybeShow(BuildContext context, WidgetRef ref) async {
    final PremiumIntroStore store = ref.read(premiumIntroStoreProvider);
    if (await store.wasShown()) return;
    await store.markShown(); // gösterim garantiden önce işaretlenir — çifte açılmaz
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      // Yalnız GERÇEK giriş eylemi: oturumsuz→üye ya da misafir→üye.
      // Geri yükleme (AuthRestoring→üye) bilerek dışarıda — açılış paywall'u yok.
      final bool cameFromSignedOut =
          prev is Unauthenticated || (prev is Authenticated && prev.isGuest);
      final bool becameMember = next is Authenticated && !next.isGuest;
      if (cameFromSignedOut && becameMember) {
        unawaited(_maybeShow(context, ref));
      }
    });
    return child;
  }
}
