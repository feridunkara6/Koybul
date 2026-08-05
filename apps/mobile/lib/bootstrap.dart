import 'dart:async';

import 'package:dockly_api/dockly_api.dart' show DocklyClient;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/flavor.dart';
import 'core/firebase_options.dart';
import 'core/l10n/app_locale.dart';
import 'core/providers.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/auth/infrastructure/firebase_auth_gateway.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/launch/presentation/launch_gate.dart';
import 'features/shell/presentation/dockly_shell.dart';
import 'features/splash/presentation/splash_screen.dart';
// Harita platform katmanı: mobilde Mapbox, web'de liste-yüzeyi (Mapbox web'de
// derlenmez). Koşullu import ile doğru dosya seçilir.
import 'platform/map_platform.dart'
    if (dart.library.html) 'platform/map_platform_web.dart' as mapplat;

/// Mapbox public erişim token'ı — `--dart-define=MAPBOX_ACCESS_TOKEN=pk...` ile
/// gelir (repoya gömülmez). Boşsa harita gri kalır ama uygulama çökmez.
const String _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

/// Uygulama giriş noktası — ProviderScope + config bağlama (docs/26 §1 bootstrap).
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  mapplat.applyMapAccessToken(_mapboxToken);
  // Sunucuyu HEMEN uyandır (fire-and-forget): kullanıcı daha ilk ekrana
  // bakarken ısınma başlasın → veri daha erken gelir.
  unawaited(DocklyClient(baseUrl: config.apiBaseUrl).warmUp());

  // DİL (kullanıcı kararı 2026-07): önce kayıtlı seçim, yoksa CİHAZ DİLİ
  // (tr/en/es/ru; diğerleri İngilizce'ye düşer). Profil'deki menüden
  // değiştirilebilir; seçim cihazda saklanır.
  final AppLocale initialLocale = await readInitialLocale();

  final List<Override> overrides = <Override>[
    appConfigProvider.overrideWithValue(config),
    appLocaleProvider.overrideWith(() => AppLocaleController(initialLocale)),
    ...mapplat.mapPlatformOverrides(),
  ];

  // Firebase kimlik köprüsü: web her zaman; iOS, Firebase konsol kaydı yapılıp
  // mooriraFirebaseOptionsIos dolunca devreye girer (mağaza fazı). Başlatma
  // BAŞARISIZ olursa ya da seçenekler henüz yoksa uygulama stub gateway ile
  // misafir modda sorunsuz çalışır; giriş düğmesi nazik bir mesaj gösterir.
  final FirebaseOptions? firebaseOptions =
      kIsWeb ? mooriraFirebaseOptionsWeb : mooriraFirebaseOptionsIos;
  if (firebaseOptions != null) {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
      overrides.add(
        authGatewayProvider.overrideWithValue(FirebaseAuthGateway()),
      );
    } catch (err) {
      debugPrint('Firebase başlatılamadı (misafir mod sürer): $err');
    }
  }

  runApp(ProviderScope(overrides: overrides, child: const DocklyApp()));
}

class DocklyApp extends ConsumerStatefulWidget {
  const DocklyApp({super.key});

  @override
  ConsumerState<DocklyApp> createState() => _DocklyAppState();
}

class _DocklyAppState extends ConsumerState<DocklyApp> {
  @override
  void initState() {
    super.initState();
    // Saklanan oturumu arka planda geri yükle (docs/26 §8): kullanıcı sekmeyi
    // kapatıp açınca girişi sürer. Hata olursa sessizce misafir kalınır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>(() async {
        try {
          await ref.read(authControllerProvider.notifier).restore();
        } catch (_) {/* oturum yok/geçersiz → misafir */}
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocale loc = ref.watch(appLocaleProvider);
    return MaterialApp(
      title: 'Koybul',
      debugShowCheckedModeBanner: false,
      theme: buildDocklyTheme(Brightness.light),
      darkTheme: buildDocklyTheme(Brightness.dark),
      // Dil: Material bileşenleri (tarih seçici, geri düğmesi ipuçları vb.)
      // seçili dile uyar; uygulama metinleri l10nProvider'dan gelir.
      locale: Locale(loc.name),
      supportedLocales: const <Locale>[
        Locale('tr'), Locale('en'), Locale('es'), Locale('ru'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Açılış ekranı (marka) → İLK açılışta karşılama (E2, onaylı tasarım
      // 2026-08) → 5 sekmeli kabuk; dönen kullanıcı karşılamayı görmez.
      // Giriş/hesap Profil sekmesinde (AccountSection). Giriş zorunlu değil —
      // misafir modu ilkedir.
      home: const SplashGate(child: LaunchGate(child: DocklyShell())),
    );
  }
}

/// Oturum durumuna göre ekran seçer (docs/26 §5 — tam GoRouter 2.4c'de).
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Açılışta saklanan oturumu geri yükle (docs/26 §8).
    Future<void>.microtask(() => ref.read(authControllerProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthRestoring() => const _SplashView(),
      Unauthenticated() => const SignInScreen(),
      Authenticated(:final user) => _HomePlaceholder(isGuest: user.isGuest),
    };
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Geçici ana ekran — asıl harita/ana sayfa Faz 3'te.
class _HomePlaceholder extends ConsumerWidget {
  const _HomePlaceholder({required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koybul')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(isGuest ? 'Merhaba, misafir kaptan' : 'Giriş yapıldı'),
            const SizedBox(height: 16),
            DocklyButton(
              label: 'Çıkış yap',
              variant: DocklyButtonVariant.secondary,
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
