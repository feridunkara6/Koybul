import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';

import 'bootstrap.dart';
import 'config/config_error_app.dart';
import 'config/flavor.dart';

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
  return bootstrap(AppConfig.fromEnvironment());
}
