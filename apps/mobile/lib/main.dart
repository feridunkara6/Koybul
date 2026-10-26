import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'bootstrap.dart';
import 'config/config_error_app.dart';
import 'config/flavor.dart';

/// Mobil çökme izleme DSN'i (denetim K3, kurucu onayı 2026-10-26) —
/// `--dart-define=SENTRY_DSN_MOBILE=...` ile yalnız Codemagic'te verilir.
/// Boşken Sentry HİÇ başlatılmaz: CI, yerel ve web derlemeleri etkilenmez.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN_MOBILE');

/// Uygulama girişi.
///
/// Açılıştan ÖNCE tek bir soru sorulur: bu yayın derlemesi gerçek bir sunucuyu
/// gösteriyor mu? Göstermiyorsa uygulama başlatılmaz; yerine sebebi ve
/// çözümü yazan tam ekran bir uyarı çıkar (bkz. config/flavor.dart başlığı).
/// Geliştirme derlemesinde denetim çalışmaz — orada localhost doğru adrestir.
Future<void> main() async {
  final ConfigProblem? problem = configProblem(
    rawApiBaseUrl: kRawApiBaseUrl,
    rawFlavor: kRawFlavor,
    releaseMode: kReleaseMode,
  );
  if (problem != null) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(ConfigErrorApp(problem: problem, rawApiBaseUrl: kRawApiBaseUrl));
    return;
  }
  final AppConfig config = AppConfig.fromEnvironment();
  if (_sentryDsn.isEmpty) {
    return bootstrap(config);
  }
  // Çökme izleme: yalnız hata olayları (tracesSampleRate 0 — performans
  // izleme kapalı); kişisel veri gönderilmez. API tarafındaki Sentry ile
  // aynı dürüstlük sözleşmesi: token/kimlik asla olaya girmez.
  return SentryFlutter.init(
    (SentryFlutterOptions options) {
      options
        ..dsn = _sentryDsn
        ..environment = 'production'
        ..tracesSampleRate = 0
        ..sendDefaultPii = false;
    },
    appRunner: () => bootstrap(config),
  );
}
