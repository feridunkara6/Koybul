// Ortam ayrımı ve YAYIN GÜVENLİĞİ (denetim Faz 0 — en yüksek skorlu madde).
//
// Çözdüğü sessiz felaket şudur: `--dart-define=API_BASE_URL=...` verilmeden
// alınan bir yayın derlemesi hatasız derlenir, imzalanır, mağazaya yüklenir.
// Marka açılışı çizilir, uygulama canlı görünür — ama her ağ isteği
// `http://localhost:3000` adresine gider. iOS bu adresi ATS kuralıyla zaten
// keser. Sonuç: çökmeyen ama ölü bir uygulama. Ne çökme kaydı düşer, ne de
// bir hata ekranı çıkar; yalnız her yer boş kalır.
//
// Buradaki kural o sessizliği GÜRÜLTÜYE çevirir: yayın derlemesinde adres
// eksikse, bozuksa, yerel makineyi gösteriyorsa ya da https değilse uygulama
// açılmaz; yerine ne yapılması gerektiğini yazan tam ekran bir uyarı çıkar.
//
// Dosya bilerek Flutter'dan bağımsızdır (hiç import yok): kural saf
// fonksiyonlarla yazıldığı için birim testinde cihaz/pencere kurmadan
// sınanabilir.

/// Derleme ortamı. Gerçek değer `--dart-define=FLAVOR=dev|staging|prod`.
enum Flavor { dev, staging, prod }

/// Yayın derlemesini kullanılamaz kılan yapılandırma kusurları.
enum ConfigProblem {
  /// `API_BASE_URL` hiç verilmemiş.
  missingUrl,

  /// Verilmiş ama adres olarak okunamıyor (şema ya da alan adı yok).
  malformedUrl,

  /// Adres geliştirici makinesini gösteriyor (localhost, 127.0.0.1, 10.0.2.2).
  localUrlInRelease,

  /// Adres https değil — iOS ATS keser, veri de şifresiz gider.
  insecureUrlInRelease,

  /// `FLAVOR` verilmemiş ya da tanınmıyor.
  missingFlavor,
}

/// Adres verilmediğinde kullanılan GELİŞTİRME varsayılanı. Yayın
/// derlemesinde bu değere düşmek başlı başına hatadır (bkz. [configProblem]).
const String kDevApiBaseUrl = 'http://localhost:3000';

/// Derleme sabitleri — ham hâlleriyle. Ham olmaları önemli: "hiç verilmedi"
/// ile "localhost verildi" ayrımını ancak burada yapabiliriz.
const String kRawApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const String kRawFlavor = String.fromEnvironment('FLAVOR');

/// Yerel makineyi gösteren alan adları. 10.0.2.2 Android öykünücüsünün
/// "ana makine" takma adıdır — gerçek telefonda hiçbir şeye karşılık gelmez.
///
/// BİLİNEN SINIR: ev ağı adresleri (192.168.x.x gibi) burada yakalanmaz.
/// Gerçek kaza senaryosu "adres hiç verilmedi → localhost" olduğu için liste
/// bilerek dar ve kesin tutuldu; aynı liste derleme öncesi kabuk denetiminde
/// de birebir var (tool/check_release_config.sh). İki tarafın AYNI şeyi kabul
/// etmesi, listeyi genişletmekten daha değerli: ayrışırlarsa paket denetimden
/// geçer, sonra telefonda hata ekranıyla açılır.
const Set<String> kLocalHosts = <String>{
  'localhost',
  '127.0.0.1',
  '::1',
  '0.0.0.0',
  '10.0.2.2',
};

class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl});

  final Flavor flavor;
  final String apiBaseUrl;

  static const AppConfig dev = AppConfig(
    flavor: Flavor.dev,
    apiBaseUrl: kDevApiBaseUrl,
  );

  /// Derleme sabitlerinden okur (uygulama girişinde kullanılır).
  static AppConfig fromEnvironment() => AppConfig.parse(
        flavorName: kRawFlavor,
        apiBaseUrl: kRawApiBaseUrl,
      );

  /// Saf ayrıştırma — testten doğrudan çağrılabilsin diye ayrı.
  static AppConfig parse({
    required String flavorName,
    required String apiBaseUrl,
  }) {
    final String url = apiBaseUrl.trim();
    return AppConfig(
      flavor: parseFlavor(flavorName),
      apiBaseUrl: url.isEmpty ? kDevApiBaseUrl : stripTrailingSlash(url),
    );
  }

  bool get isProd => flavor == Flavor.prod;
  bool get isDev => flavor == Flavor.dev;
}

/// `FLAVOR` sabitini okur; tanınmayan ya da boş değer geliştirmeye düşer.
/// Yayın derlemesinde bu düşüş [ConfigProblem.missingFlavor] ile yakalanır.
Flavor parseFlavor(String name) {
  switch (name.trim().toLowerCase()) {
    case 'prod':
    case 'production':
      return Flavor.prod;
    case 'staging':
    case 'stg':
      return Flavor.staging;
    case 'dev':
    case 'development':
      return Flavor.dev;
    default:
      return Flavor.dev;
  }
}

/// Sondaki `/` işaretini atar — aynı sunucu iki farklı yazımla iki farklı
/// önbellek anahtarı üretmesin.
String stripTrailingSlash(String url) {
  String out = url;
  while (out.length > 1 && out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// Yayın derlemesinin gerçekten çalışabilir olup olmadığını söyler.
/// `null` dönerse sorun yok.
///
/// [releaseMode] false iken hiçbir şey denetlenmez: geliştirirken localhost
/// zaten DOĞRU adrestir, geliştiriciye her seferinde uyarı çıkarmak gürültüyü
/// anlamsızlaştırır ve asıl uyarıyı görünmez kılar.
ConfigProblem? configProblem({
  required String rawApiBaseUrl,
  required String rawFlavor,
  required bool releaseMode,
}) {
  if (!releaseMode) {
    return null;
  }
  final String url = rawApiBaseUrl.trim();
  if (url.isEmpty) {
    return ConfigProblem.missingUrl;
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return ConfigProblem.malformedUrl;
  }
  if (kLocalHosts.contains(uri.host.toLowerCase())) {
    return ConfigProblem.localUrlInRelease;
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return ConfigProblem.insecureUrlInRelease;
  }
  // Adres sağlam; sıra ortam etiketinde. En sona bırakıldı çünkü yanlış
  // adres, yanlış etiketten kat kat ağır bir hatadır.
  if (!kKnownFlavorNames.contains(rawFlavor.trim().toLowerCase())) {
    return ConfigProblem.missingFlavor;
  }
  return null;
}

/// [parseFlavor] içinde tanınan yazımlar. Tek kaynak olsun diye burada.
const Set<String> kKnownFlavorNames = <String>{
  'dev',
  'development',
  'staging',
  'stg',
  'prod',
  'production',
};

/// Hata ekranında gösterilecek metin. Sunum katmanı değil, veri: ekran bunu
/// yalnız çizer, karar vermez.
class ConfigProblemText {
  const ConfigProblemText({
    required this.title,
    required this.detail,
    required this.fix,
  });

  /// Tek cümlelik başlık (Türkçe).
  final String title;

  /// Ne olduğunu ve neden önemli olduğunu anlatan paragraf.
  final String detail;

  /// Derlemeyi alan kişinin yazması gereken komut satırı parçası.
  final String fix;
}

const String _fixLine =
    '--dart-define=API_BASE_URL=https://sunucu-adresin --dart-define=FLAVOR=prod';

ConfigProblemText configProblemText(ConfigProblem problem, String rawUrl) {
  switch (problem) {
    case ConfigProblem.missingUrl:
      return const ConfigProblemText(
        title: 'Sunucu adresi verilmemiş',
        detail: 'Bu derleme hangi sunucuyla konuşacağını bilmiyor. Adres '
            'verilmediği için uygulama geliştirme varsayılanına '
            '($kDevApiBaseUrl) düşerdi; o adres yalnız geliştiricinin kendi '
            'bilgisayarında vardır. Açılmasına izin verilmedi, çünkü açılsaydı '
            'uygulama canlı görünüp hiçbir veri getiremezdi.',
        fix: _fixLine,
      );
    case ConfigProblem.malformedUrl:
      return ConfigProblemText(
        title: 'Sunucu adresi okunamıyor',
        detail: 'Verilen adres bir web adresi gibi görünmüyor: "$rawUrl". '
            'Beklenen biçim https://alanadi.com şeklindedir; başındaki '
            'https:// bölümü eksikse adres geçersiz sayılır.',
        fix: _fixLine,
      );
    case ConfigProblem.localUrlInRelease:
      return ConfigProblemText(
        title: 'Yayın derlemesi yerel bilgisayara bakıyor',
        detail: 'Adres "$rawUrl" — bu, derlemeyi yapan bilgisayarın kendi '
            'içidir. Kullanıcının telefonunda böyle bir sunucu yoktur; iOS bu '
            'tür adresleri ayrıca güvenlik kuralıyla engeller. Uygulama '
            'açılsaydı çökmeden ölü kalırdı.',
        fix: _fixLine,
      );
    case ConfigProblem.insecureUrlInRelease:
      return ConfigProblemText(
        title: 'Sunucu adresi güvenli değil (https değil)',
        detail: 'Adres "$rawUrl" şifresiz http üzerinden gidiyor. iOS bunu '
            'varsayılan olarak engeller, ayrıca kullanıcının konumu ve oturum '
            'anahtarı açık ağda okunabilir hâle gelir.',
        fix: _fixLine,
      );
    case ConfigProblem.missingFlavor:
      return const ConfigProblemText(
        title: 'Ortam etiketi verilmemiş',
        detail: 'Sunucu adresi doğru ama derlemenin hangi ortam olduğu '
            '(dev / staging / prod) belirtilmemiş. Etiket olmadan uygulama '
            'kendini geliştirme derlemesi sanır; ileride ortama göre değişen '
            'davranışlar sessizce yanlış tarafa düşer.',
        fix: _fixLine,
      );
  }
}
