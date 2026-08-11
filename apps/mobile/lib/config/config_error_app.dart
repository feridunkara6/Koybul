import 'package:flutter/material.dart';

import 'flavor.dart';

/// Yanlış yapılandırılmış bir YAYIN derlemesinin açtığı tam ekran uyarı.
///
/// Neden ayrı ve çıplak bir uygulama: bu ekran, uygulamanın geri kalanı hiç
/// kurulmadan çizilir. Tema, dil sağlayıcısı, Firebase, harita — hiçbiri
/// başlatılmamıştır; bu yüzden burada hiçbirine dokunulmaz. Amaç, hatanın
/// kendisi yüzünden hata ekranının da çökmemesidir.
///
/// Metin bilerek Türkçe: bu derlemeyi alan kişi biziz. En altta tek satır
/// İngilizce var, çünkü ekranı görebilecek ikinci kişi mağaza incelemecisidir
/// ve "uygulama açılmıyor" yerine sebebini okuyabilmelidir.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({
    required this.problem,
    required this.rawApiBaseUrl,
    super.key,
  });

  final ConfigProblem problem;
  final String rawApiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final ConfigProblemText text = configProblemText(problem, rawApiBaseUrl);
    return MaterialApp(
      title: 'Koybul',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1D21),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  key: const ValueKey<String>('config-error'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD03B3B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DERLEME YAPILANDIRMASI HATALI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      text.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      text.detail,
                      style: const TextStyle(
                        color: Color(0xFFC9CCD2),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Bu derlemeyi şu ekle ile yeniden al:',
                      style: TextStyle(
                        color: Color(0xFFC9CCD2),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101215),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3A3E45)),
                      ),
                      child: Text(
                        text.fix,
                        key: const ValueKey<String>('config-error-fix'),
                        style: const TextStyle(
                          color: Color(0xFF8FD08F),
                          fontSize: 13,
                          height: 1.45,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'This build is misconfigured (server address missing or '
                      'invalid) and was stopped on purpose instead of starting '
                      'with no working connection.',
                      style: TextStyle(
                        color: Color(0xFF8A9099),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
