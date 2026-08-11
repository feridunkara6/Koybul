import 'package:dockly_mobile/config/flavor.dart';
import 'package:flutter_test/flutter_test.dart';

/// YAYIN GÜVENLİĞİ testleri (Faz 0 — denetimdeki en yüksek skorlu madde).
///
/// Korunan senaryo: adres verilmeden alınan bir yayın derlemesi hatasız
/// derlenir, imzalanır, mağazaya çıkar ve her istek localhost'a gider. Ne
/// çökme olur ne hata; uygulama canlı görünüp ölü kalır. Aşağıdaki testler o
/// derlemenin ASLA açılmamasını kilitler.
void main() {
  group('geliştirme derlemesi', () {
    test('localhost geliştirmede sorun DEĞİLDİR', () {
      expect(
        configProblem(
          rawApiBaseUrl: '',
          rawFlavor: '',
          releaseMode: false,
        ),
        isNull,
      );
    });
  });

  group('yayın derlemesi', () {
    ConfigProblem? p(String url, {String flavor = 'prod'}) => configProblem(
          rawApiBaseUrl: url,
          rawFlavor: flavor,
          releaseMode: true,
        );

    test('adres hiç verilmemişse açılmaz', () {
      expect(p(''), ConfigProblem.missingUrl);
      expect(p('   '), ConfigProblem.missingUrl);
    });

    test('adres okunamıyorsa açılmaz', () {
      expect(p('sunucu-adresim'), ConfigProblem.malformedUrl);
      expect(p('localhost:3000'), ConfigProblem.malformedUrl);
      expect(p('https://'), ConfigProblem.malformedUrl);
    });

    test('yerel makine adresleri açılmaz (asıl felaket senaryosu)', () {
      for (final String host in <String>[
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '10.0.2.2',
      ]) {
        expect(p('http://$host:3000'), ConfigProblem.localUrlInRelease,
            reason: host);
        // https yazılmış olması da kurtarmaz — sunucu yine orada yok.
        expect(p('https://$host'), ConfigProblem.localUrlInRelease,
            reason: host);
      }
      // IPv6 döngü adresi köşeli parantezle yazılır; Uri.host parantezleri
      // atar, bu yüzden kLocalHosts içindeki '::1' girdisi eşleşir.
      expect(p('http://[::1]:3000'), ConfigProblem.localUrlInRelease);
      // Büyük harfle yazılmış olması da kurtarmaz.
      expect(p('https://LOCALHOST:3000'), ConfigProblem.localUrlInRelease);
    });

    test('şifresiz http açılmaz (iOS ATS keser, oturum anahtarı açıkta)', () {
      expect(p('http://api.koybul.com'), ConfigProblem.insecureUrlInRelease);
      expect(p('HTTP://api.koybul.com'), ConfigProblem.insecureUrlInRelease);
    });

    test('ortam etiketi eksikse açılmaz', () {
      expect(p('https://api.koybul.com', flavor: ''),
          ConfigProblem.missingFlavor);
      expect(p('https://api.koybul.com', flavor: 'canli'),
          ConfigProblem.missingFlavor);
    });

    test('adres hatası ETİKET hatasından önce bildirilir', () {
      // Sıra önemli: yanlış adres uygulamayı öldürür, yanlış etiket öldürmez.
      // Ekranda tek sorun gösterildiği için ağır olanı göstermeliyiz.
      expect(p('', flavor: ''), ConfigProblem.missingUrl);
    });

    test('doğru yapılandırma geçer', () {
      expect(p('https://api.koybul.com'), isNull);
      expect(p('https://api.koybul.com/', flavor: 'staging'), isNull);
      expect(p(' https://api.koybul.com ', flavor: 'dev'), isNull);
    });
  });

  group('AppConfig.parse', () {
    test('boş adres geliştirme varsayılanına düşer', () {
      expect(AppConfig.parse(flavorName: '', apiBaseUrl: '').apiBaseUrl,
          kDevApiBaseUrl);
    });

    test('sondaki eğik çizgi atılır (tek yazım, tek önbellek anahtarı)', () {
      expect(
        AppConfig.parse(flavorName: 'prod', apiBaseUrl: 'https://a.com///')
            .apiBaseUrl,
        'https://a.com',
      );
    });

    test('etiket okunur, tanınmayan değer geliştirmeye düşer', () {
      expect(AppConfig.parse(flavorName: 'prod', apiBaseUrl: 'https://a.com').flavor,
          Flavor.prod);
      expect(AppConfig.parse(flavorName: 'STAGING', apiBaseUrl: 'https://a.com').flavor,
          Flavor.staging);
      expect(AppConfig.parse(flavorName: 'zzz', apiBaseUrl: 'https://a.com').flavor,
          Flavor.dev);
    });

    test('isProd yalnız prod etiketinde doğrudur', () {
      expect(
        AppConfig.parse(flavorName: 'prod', apiBaseUrl: 'https://a.com').isProd,
        isTrue,
      );
      expect(AppConfig.dev.isProd, isFalse);
      expect(AppConfig.dev.isDev, isTrue);
    });
  });

  test('tanınan etiket yazımları tek kaynaktan gelir', () {
    // kKnownFlavorNames ile parseFlavor ayrışırsa doğru yapılandırılmış bir
    // derleme "etiket yok" diye reddedilir. Bu test o ayrışmayı yakalar.
    for (final String name in kKnownFlavorNames) {
      expect(
        configProblem(
          rawApiBaseUrl: 'https://api.koybul.com',
          rawFlavor: name,
          releaseMode: true,
        ),
        isNull,
        reason: name,
      );
    }
  });

  test('her kusurun okunabilir bir metni vardır', () {
    for (final ConfigProblem problem in ConfigProblem.values) {
      final ConfigProblemText t = configProblemText(problem, 'http://localhost:3000');
      expect(t.title.trim(), isNotEmpty, reason: '$problem');
      expect(t.detail.trim().length, greaterThan(60), reason: '$problem');
      expect(t.fix, contains('API_BASE_URL'), reason: '$problem');
      expect(t.fix, contains('FLAVOR'), reason: '$problem');
    }
  });
}
