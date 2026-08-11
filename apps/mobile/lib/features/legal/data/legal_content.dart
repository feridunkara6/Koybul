/// YASAL METİN İÇERİĞİ (Faz 0 — yayın engeli).
///
/// Üç belge: gizlilik politikası, KVKK aydınlatma metni, kullanım koşulları.
///
/// DİL KAPSAMI — bilinçli karar: metinler TÜRKÇE ve İNGİLİZCE yazılmıştır;
/// İspanyolca ve Rusça arayüzde İNGİLİZCESİ gösterilir (Akademi ile aynı
/// yedek deseni). Sebep: yasal metinde yaklaşık çeviri, çeviri olmamasından
/// daha risklidir — yanlış çevrilmiş bir hak beyanı kaptanı da bizi de
/// yanıltır. Türkçe metin KVKK açısından geçerli olan metindir.
///
/// DOLDURULACAK İKİ ALAN — yayından ÖNCE: [kLegalEntity] (veri sorumlusunun
/// resmî unvanı) ve [kLegalAddress] (tebligat adresi). KVKK aydınlatma metni
/// veri sorumlusunun kimliğini içermek zorundadır; bu iki sabit boş kaldığı
/// sürece metin eksiktir. [kLegalContact] adresinin de gerçekten okunan bir
/// posta kutusu olması gerekir — başvuru yolu budur.
library;

import 'package:dockly_ui/dockly_ui.dart';

import '../../../core/l10n/app_locale.dart';
import '../domain/legal_doc.dart';

/// Veri sorumlusunun resmî unvanı. YAYINDAN ÖNCE gerçek unvanla değiştirilir.
const String kLegalEntity = 'Koybul';

/// Tebligat adresi. YAYINDAN ÖNCE doldurulur.
const String kLegalAddress = 'Türkiye';

/// Başvuru ve iletişim adresi. Gerçekten okunan bir kutu olmalıdır.
const String kLegalContact = 'destek@koybul.com';

/// Metinlerin yürürlük tarihi — içerik her değiştiğinde elle güncellenir.
const String kLegalUpdated = '2026-08-11';

/// Belge kimliği + ikonu (dilden bağımsız; sıra listede görünen sıradır).
class _Doc {
  const _Doc(this.id, this.icon);
  final String id;
  final DocklyIconData icon;
}

const List<_Doc> _docs = <_Doc>[
  _Doc('privacy', DocklyIcons.shield),
  _Doc('kvkk', DocklyIcons.lockOutline),
  _Doc('terms', DocklyIcons.eventNote),
];

/// Belge sayısı — arayüz ve testler bu sabiti okur.
const int kLegalDocCount = 3;

/// Seçili dildeki belgeler. Metin o dilde yoksa İNGİLİZCESİ gösterilir.
List<LegalDoc> legalDocs(AppLocale locale) {
  final Map<String, LegalText> table = _tableOf(locale);
  final List<LegalDoc> out = <LegalDoc>[];
  for (final _Doc d in _docs) {
    final LegalText? text = table[d.id] ?? _en[d.id];
    if (text == null) continue;
    out.add(LegalDoc(
      id: d.id,
      icon: d.icon,
      title: text.title,
      summary: text.summary,
      updated: kLegalUpdated,
      sections: text.sections,
    ));
  }
  return out;
}

/// Tek belge — kimlikten. Bulunamazsa null.
LegalDoc? legalDocById(AppLocale locale, String id) {
  for (final LegalDoc d in legalDocs(locale)) {
    if (d.id == id) return d;
  }
  return null;
}

Map<String, LegalText> _tableOf(AppLocale locale) => switch (locale) {
      AppLocale.tr => _tr,
      AppLocale.en => _en,
      // Yasal metinde yaklaşık çeviri yapmıyoruz — İngilizcesi gösterilir.
      AppLocale.es => _en,
      AppLocale.ru => _en,
    };

// =====================================================================
// TÜRKÇE
// =====================================================================

const Map<String, LegalText> _tr = <String, LegalText>{
  'privacy': LegalText(
    title: 'Gizlilik Politikası',
    summary: 'Hangi veriyi neden topluyoruz, kiminle paylaşıyoruz.',
    sections: <LegalSection>[
      LegalSection(heading: 'Kısaca', paragraphs: <String>[
        'Koybul hesap açmadan kullanılabilir. Hesap açmazsan sana ait hiçbir kişisel veri sunucumuzda saklanmaz.',
        'Teknenin bilgileri, seyir defterin, favorilerin, kayıtlı rotaların ve bakım kayıtların YALNIZCA telefonunda durur. Bunlar bize hiç gönderilmez.',
        'Verini satmıyoruz, reklam için kullanmıyoruz ve reklam takip araçları kullanmıyoruz.',
      ]),
      LegalSection(heading: 'Hesap açmadan kullanırken', paragraphs: <String>[
        'Harita, koy bilgileri, arama, hava tahmini ve rota planlama için sunucumuza istek gönderilir. Bu isteklerde adın, e-postan ya da bir hesap kimliğin bulunmaz.',
        'Teknik olarak sunucu kayıtlarında isteğin geldiği IP adresi ve istek zamanı tutulur. Bunlar hizmetin çalışması ve kötüye kullanımın engellenmesi için gereklidir.',
      ]),
      LegalSection(heading: 'Hesap açarsan işlenen veriler', paragraphs: <String>[
        '· E-posta adresin ve hesap kimliğin. Girişi Google, Apple ya da e-posta+şifre ile yapabilirsin. E-posta ile girişte şifreni Google Firebase kimlik doğrulama servisi işler; şifren bizim sunucumuza HİÇ gönderilmez ve bizde saklanmaz.',
        '· Görünen adın. Varsayılan olarak "Kaptan" ve kısa bir numaradır; istersen değiştirebilirsin. Yazdığın notların ve yorumların yanında herkese görünür.',
        '· Yazdığın kaptan notları, yorumlar, doluluk bildirimleri ve bunların tarihleri.',
        '· Katkı puanların, seviyen ve rozetlerin.',
        '· Oturum kayıtları: giriş yaptığın cihazın türü, IP adresi ve giriş zamanı. Bunlar hesabını çalınmaya karşı korumak içindir.',
      ]),
      LegalSection(heading: 'Konum verisi', paragraphs: <String>[
        'Konumun yalnızca sen izin verirsen alınır. İzni her zaman telefon ayarlarından geri çekebilirsin.',
        'Konumun şunlar için kullanılır: sana en yakın koyları sıralamak, haritada tekne imlecini göstermek, rota başlangıcını belirlemek, hava tahminini bulunduğun yer için istemek ve yakınında paylaşılan kaptan notlarını getirmek (bu son istekte konum yaklaşık 11 kilometreye yuvarlanır).',
        'Uyarı ve güncel durum notu yazdığında, notun gerçekten oradan yazıldığını doğrulamak için konumun sunucuya gönderilir ve o notla birlikte saklanır. Bu, yanlış bilginin yayılmasını engellemek içindir ve notun kendisi zaten herkese açıktır.',
        'Sürekli konum takibi YOKTUR. Uygulama kapalıyken ya da arka planda konumunu izlemez.',
      ]),
      LegalSection(heading: 'Telefonunda kalan, bize gelmeyen veriler', paragraphs: <String>[
        '· Tekne bilgilerin (boy, su çekimi, marka, tip)',
        '· Seyir defteri notların ve seyir kayıtların',
        '· Favori yerlerin ve kayıtlı rotaların',
        '· Tekne bakım kayıtların ve kontrol listelerin',
        '· Dil tercihin',
        'Bu veriler telefonundan silinirse geri getirilemez; bizde bir kopyası yoktur.',
      ]),
      LegalSection(heading: 'Verinin paylaşıldığı taraflar', paragraphs: <String>[
        '· Google (Firebase Authentication): girişi yönetir. E-posta adresin burada tutulur.',
        '· Mapbox: harita görüntüsünü telefonuna doğrudan gönderir; bu sırada IP adresini ve haritada baktığın bölgeyi görür.',
        '· MET Norway (Norveç Meteoroloji Enstitüsü): hava tahminini sağlar. İsteği bizim sunucumuz yapar ve koordinatı yaklaşık 1 kilometreye yuvarlar; senin kimliğin gönderilmez.',
        '· OpenStreetMap ve OpenSeaMap: yalnızca tarayıcı sürümünde harita ve deniz işaretleri katmanını sağlar; bu sırada IP adresini ve baktığın bölgeyi görürler.',
        '· Sunucu ve veritabanı barındırma hizmetleri.',
        'Bunun dışında hiçbir üçüncü tarafla veri paylaşılmaz. Yasal bir zorunluluk doğarsa yalnızca istenen ölçüde paylaşılır.',
      ]),
      LegalSection(heading: 'Ne kadar süre saklanır', paragraphs: <String>[
        'Hesap verilerin, hesabın açık kaldığı sürece saklanır.',
        'Yazdığın notlar ve yorumlar, sen silmediğin sürece yayında kalır. Bazı not türleri (güncel durum gibi) kendiliğinden süresi dolar ve görünmez olur.',
        'Erişim kayıtları (IP adresi ve istek zamanı) hizmetin işletilmesi ve kötüye kullanımın tespiti için tutulur.',
        'GÜVENLİK DENETİM KAYITLARI: hesapla ilgili önemli işlemler (giriş, yetki değişikliği, hesap silme) ayrı bir denetim kaydına yazılır ve bu kayıt IP adresini içerir. Bu kayıtlar, kötüye kullanımın araştırılabilmesi ve yasal yükümlülükler sebebiyle hesap silindikten SONRA da saklanır. Silinmelerini talep edebilirsin; talebini kanunun izin verdiği ölçüde değerlendiririz.',
      ]),
      LegalSection(heading: 'Hakların ve hesabını silme', paragraphs: <String>[
        'Uygulama içinden hesabını istediğin an silebilirsin: Profil sekmesi, Hesap bölümü, "Hesabımı sil".',
        'Hesabını sildiğinde kimlik bilgilerin kaldırılır ve tüm cihazlardaki oturumların kapatılır. Güvenlik denetim kayıtları (işlem zamanı ve IP adresi) yukarıda anlatıldığı gibi saklanmaya devam eder.',
        'Daha önce yazdığın notlar ve yorumlar, başka kaptanların güvenliği için yayında kalabilir; ancak seninle bağlantısı kesilir. Bir notun tamamen silinmesini istiyorsan silmeden önce kendin kaldırabilir ya da bize yazabilirsin.',
        'Kişisel verilerine erişmek, düzeltilmesini ya da silinmesini istemek için: $kLegalContact',
      ]),
      LegalSection(heading: 'Çocuklar', paragraphs: <String>[
        'Koybul 13 yaşın altındaki çocuklara yönelik değildir ve bilerek onlardan veri toplamaz.',
      ]),
      LegalSection(heading: 'Değişiklikler ve iletişim', paragraphs: <String>[
        'Bu metin değişirse uygulamadaki yürürlük tarihi güncellenir. Önemli bir değişiklikte uygulama içinde bilgilendirilirsin.',
        'Her türlü soru için: $kLegalContact',
      ]),
    ],
  ),
  'kvkk': LegalText(
    title: 'KVKK Aydınlatma Metni',
    summary: '6698 sayılı kanun kapsamında bilgilendirme.',
    sections: <LegalSection>[
      LegalSection(heading: 'Veri sorumlusu', paragraphs: <String>[
        '6698 sayılı Kişisel Verilerin Korunması Kanunu uyarınca veri sorumlusu $kLegalEntity\'dir.',
        'Adres: $kLegalAddress',
        'İletişim: $kLegalContact',
      ]),
      LegalSection(heading: 'İşlenen kişisel veriler', paragraphs: <String>[
        '· Kimlik ve iletişim verisi: e-posta adresi, görünen ad.',
        '· İşlem güvenliği verisi: IP adresi, oturum ve giriş kayıtları, cihaz türü.',
        '· Konum verisi: yalnızca izin verildiğinde ve yalnızca uygulama açıkken; uyarı/durum notlarında notla birlikte kaydedilir.',
        '· Kullanıcı içeriği: yazdığın notlar, yorumlar, doluluk bildirimleri, katkı puanı ve rozetler.',
        'Hesap açılmadan uygulama kullanıldığında bu verilerin hiçbiri işlenmez; yalnızca teknik sunucu kayıtları oluşur.',
      ]),
      LegalSection(heading: 'İşleme amaçları', paragraphs: <String>[
        '· Üyelik oluşturulması ve hesabın yönetilmesi',
        '· Denizcilik bilgisinin paylaşılması ve doğruluğunun denetlenmesi',
        '· Yanlış ve yanıltıcı içeriğin engellenmesi, kötüye kullanımın önlenmesi',
        '· Hizmetin güvenliğinin ve sürekliliğinin sağlanması',
        '· Yasal yükümlülüklerin yerine getirilmesi',
      ]),
      LegalSection(heading: 'Hukuki sebep', paragraphs: <String>[
        'Verilerin, kanunun 5. maddesi kapsamında; sözleşmenin kurulması ve ifası, veri sorumlusunun hukuki yükümlülüğünü yerine getirmesi ve temel hak ve özgürlüklere zarar vermemek kaydıyla meşru menfaati hukuki sebeplerine dayanarak işlenir.',
        'Konum verisi yalnızca AÇIK RIZA ile işlenir. Rızanı telefon ayarlarından konum iznini kapatarak her an geri çekebilirsin.',
      ]),
      LegalSection(heading: 'Aktarım', paragraphs: <String>[
        'Kişisel veriler; kimlik doğrulama, harita ve barındırma hizmetleri alınabilmesi amacıyla yurt dışında yerleşik hizmet sağlayıcılara aktarılabilir.',
        'Yazdığın notların, yorumların ve görünen adının uygulama içinde diğer kullanıcılara açık olduğunu bilerek paylaşırsın.',
        'Bunun dışında üçüncü kişilerle paylaşım yapılmaz; yasal talep hâlinde yalnızca talebin kapsamıyla sınırlı paylaşım yapılır.',
      ]),
      LegalSection(heading: 'Toplama yöntemi', paragraphs: <String>[
        'Veriler, mobil uygulama üzerinden elektronik ortamda; kayıt olurken, içerik oluştururken ve uygulamayı kullanırken otomatik ve kısmen otomatik yollarla toplanır.',
      ]),
      LegalSection(heading: 'Kanunun 11. maddesindeki haklarınız', paragraphs: <String>[
        'Kişisel verilerinizle ilgili olarak;',
        '· işlenip işlenmediğini öğrenme,',
        '· işlenmişse buna ilişkin bilgi talep etme,',
        '· işlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,',
        '· yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,',
        '· eksik veya yanlış işlenmişse düzeltilmesini isteme,',
        '· kanunda öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme,',
        '· düzeltme, silme ve yok etme işlemlerinin aktarıldığı üçüncü kişilere bildirilmesini isteme,',
        '· münhasıran otomatik sistemlerle analiz edilmesi suretiyle aleyhinize bir sonuç çıkmasına itiraz etme,',
        '· kanuna aykırı işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme',
        'haklarına sahipsiniz.',
      ]),
      LegalSection(heading: 'Başvuru', paragraphs: <String>[
        'Haklarınıza ilişkin taleplerinizi $kLegalContact adresine iletebilirsiniz. Başvurunuz en geç otuz gün içinde sonuçlandırılır.',
        'Hesabınızı silmek için başvuruya gerek yoktur: Profil sekmesindeki Hesap bölümünden "Hesabımı sil" ile anında silebilirsiniz.',
      ]),
    ],
  ),
  'terms': LegalText(
    title: 'Kullanım Koşulları',
    summary: 'Uygulamanın sınırları ve kaptanın sorumluluğu.',
    sections: <LegalSection>[
      LegalSection(heading: 'Kabul', paragraphs: <String>[
        'Koybul\'u kullanarak bu koşulları kabul etmiş olursun. Kabul etmiyorsan uygulamayı kullanma.',
      ]),
      LegalSection(heading: 'ÖNEMLİ: Koybul bir seyir yayını değildir', paragraphs: <String>[
        'Koybul resmî bir seyir yayını, harita, kılavuz kitap ya da elektronik seyir sistemi DEĞİLDİR ve bunların yerine geçmez.',
        'Uygulamadaki rota önerileri kaba bir kıyı-kara ayrımına dayanır. Sığlıkları, kayalıkları, resifleri, batıkları, balık çiftliklerini, askerî ve yasak bölgeleri, trafik ayrım düzenlerini, akıntıyı ve gel-gitleri BİLMEZ.',
        'Derinlik, zemin, korunak ve kapasite bilgileri kaynaklardan derlenmiş ve zaman içinde değişebilecek bilgilerdir. Doğrulukları garanti edilmez.',
        'Hava ve rüzgâr bilgisi üçüncü taraf tahminidir; tahmin gerçekleşmeyebilir.',
        'Seyir kararlarını her zaman güncel resmî haritalar, seyir yayınları ve kendi gözlemlerinle ver.',
      ]),
      LegalSection(heading: 'Kaptanın sorumluluğu', paragraphs: <String>[
        'Teknenin, mürettebatının ve seyrinin güvenliğinden yalnızca kaptan sorumludur.',
        'Uygulamadaki hiçbir bilgi bu sorumluluğu azaltmaz, paylaşmaz ya da devralmaz.',
        'Acil durumda uygulamaya değil, telsize ve resmî acil yardım hatlarına başvur.',
      ]),
      LegalSection(heading: 'Hesap ve topluluk kuralları', paragraphs: <String>[
        'Paylaştığın bilgi doğru ve kendi gözlemine dayalı olmalıdır. Bilmediğin bir şeyi biliyormuş gibi paylaşma.',
        'Şunlar yasaktır: yanıltıcı ya da uydurma denizcilik bilgisi, hakaret ve taciz, başkasının kişisel bilgisini paylaşmak, reklam ve spam, başkasının içeriğini kendi adına paylaşmak.',
        'Kuralları ihlal eden içerik kaldırılabilir; tekrarında hesap askıya alınabilir.',
        'Emniyet uyarıları özellikle önemlidir: gerçek olmayan bir uyarı, gerçek bir tehlikeyi gölgede bırakır.',
      ]),
      LegalSection(heading: 'Paylaştığın içerik', paragraphs: <String>[
        'Yazdığın içerik sana aittir. Paylaşarak, bu içeriğin Koybul içinde gösterilmesi için bize ücretsiz ve süresiz kullanım izni vermiş olursun.',
        'İçeriğini istediğin an silebilirsin. Silinen içerik uygulamada görünmez olur.',
      ]),
      LegalSection(heading: 'Hizmetin sürekliliği', paragraphs: <String>[
        'Hizmet "olduğu gibi" sunulur. Kesintisiz ya da hatasız çalışacağı garanti edilmez.',
        'Uygulamanın bazı bölümleri internet bağlantısı gerektirir; denizde bağlantı olmayabilir. Kritik bilgiyi denize çıkmadan önce not al.',
      ]),
      LegalSection(heading: 'Sorumluluğun sınırı', paragraphs: <String>[
        'Yürürlükteki hukukun izin verdiği azami ölçüde; uygulamanın kullanımından doğan dolaylı zararlardan, veri kaybından ve kâr kaybından sorumlu tutulamayız.',
        'Bu sınırlama, kanunen sınırlandırılamayan sorumluluk hâllerini kapsamaz.',
      ]),
      LegalSection(heading: 'Değişiklikler ve iletişim', paragraphs: <String>[
        'Bu koşullar değişirse uygulamadaki yürürlük tarihi güncellenir.',
        'Uyuşmazlıklarda Türkiye Cumhuriyeti hukuku uygulanır.',
        'İletişim: $kLegalContact',
      ]),
    ],
  ),
};

// =====================================================================
// ENGLISH — also the fallback for Spanish and Russian.
// =====================================================================

const Map<String, LegalText> _en = <String, LegalText>{
  'privacy': LegalText(
    title: 'Privacy Policy',
    summary: 'What we collect, why, and who we share it with.',
    sections: <LegalSection>[
      LegalSection(heading: 'In short', paragraphs: <String>[
        'Koybul works without an account. If you do not create one, we store no personal data about you on our servers.',
        'Your boat details, logbook, favourites, saved routes and maintenance records stay ONLY on your phone. They are never sent to us.',
        'We do not sell your data, do not use it for advertising, and use no advertising trackers.',
      ]),
      LegalSection(heading: 'Using the app without an account', paragraphs: <String>[
        'Requests are sent to our server for the map, cove information, search, weather and route planning. Those requests carry no name, e-mail or account identifier.',
        'Our server logs record the requesting IP address and the time of the request. These are needed to operate the service and to prevent abuse.',
      ]),
      LegalSection(heading: 'Data processed if you create an account', paragraphs: <String>[
        '· Your e-mail address and account identifier. You can sign in with Google, Apple, or e-mail and password. With e-mail sign-in your password is handled by Google Firebase Authentication; it is never sent to our server and we never store it.',
        '· Your display name. By default it is "Kaptan" plus a short number; you can change it. It is visible to everyone next to your notes and reviews.',
        '· The captain notes, reviews and occupancy reports you write, and their timestamps.',
        '· Your contribution points, level and badges.',
        '· Session records: device type, IP address and sign-in time. These protect your account against theft.',
      ]),
      LegalSection(heading: 'Location data', paragraphs: <String>[
        'Your location is only read if you allow it. You can withdraw that permission at any time in your phone settings.',
        'It is used to sort the nearest coves, show your boat marker on the map, set a route start point, request the forecast for where you are, and fetch captain notes shared near you (for that last request the position is rounded to roughly 11 kilometres).',
        'When you write a hazard or status note, your position is sent to the server and stored with that note, to verify the note was really written there. This exists to stop false information spreading, and the note itself is public anyway.',
        'There is NO continuous location tracking. The app does not follow you in the background or while closed.',
      ]),
      LegalSection(heading: 'Data that stays on your phone', paragraphs: <String>[
        '· Boat details (length, draft, brand, type)',
        '· Logbook entries and voyage records',
        '· Favourites and saved routes',
        '· Maintenance records and checklists',
        '· Language preference',
        'If this data is deleted from your phone it cannot be recovered; we hold no copy.',
      ]),
      LegalSection(heading: 'Who we share data with', paragraphs: <String>[
        '· Google (Firebase Authentication): handles sign-in. Your e-mail address is held there.',
        '· Mapbox: delivers map imagery directly to your phone, and in doing so sees your IP address and the area you are viewing.',
        '· MET Norway (Norwegian Meteorological Institute): provides the forecast. Our server makes the request and rounds the coordinate to roughly 1 kilometre; your identity is not sent.',
        '· OpenStreetMap and OpenSeaMap: only in the browser version, they serve the map and seamark layers and in doing so see your IP address and the area you are viewing.',
        '· Server and database hosting providers.',
        'We share data with no one else. If legally compelled, we share only what is required.',
      ]),
      LegalSection(heading: 'How long we keep it', paragraphs: <String>[
        'Account data is kept for as long as your account exists.',
        'Notes and reviews you write stay published until you delete them. Some note types (such as status notes) expire on their own.',
        'Access logs (IP address and request time) are kept to operate the service and to detect abuse.',
        'SECURITY AUDIT RECORDS: significant account events (sign-in, permission change, account deletion) are written to a separate audit record that includes the IP address. Those records are retained even AFTER an account is deleted, so that abuse can be investigated and legal obligations met. You may request their erasure; we will assess the request to the extent the law allows.',
      ]),
      LegalSection(heading: 'Your rights and deleting your account', paragraphs: <String>[
        'You can delete your account at any time from inside the app: Profile tab, Account section, "Delete my account".',
        'Deleting your account removes your identifying data and ends your sessions on every device. Security audit records (event time and IP address) are retained as described above.',
        'Notes and reviews you wrote earlier may remain published for the safety of other captains, but they are disconnected from you. If you want a note removed entirely, delete it yourself first or write to us.',
        'To access, correct or erase your personal data: $kLegalContact',
      ]),
      LegalSection(heading: 'Children', paragraphs: <String>[
        'Koybul is not directed at children under 13 and does not knowingly collect data from them.',
      ]),
      LegalSection(heading: 'Changes and contact', paragraphs: <String>[
        'If this text changes, the effective date in the app is updated. You will be told in the app about any significant change.',
        'Questions: $kLegalContact',
      ]),
    ],
  ),
  'kvkk': LegalText(
    title: 'Data Protection Notice (KVKK)',
    summary: 'Notice under Turkish data protection law no. 6698.',
    sections: <LegalSection>[
      LegalSection(heading: 'Data controller', paragraphs: <String>[
        'Under Turkish Personal Data Protection Law no. 6698, the data controller is $kLegalEntity.',
        'Address: $kLegalAddress',
        'Contact: $kLegalContact',
      ]),
      LegalSection(heading: 'Personal data processed', paragraphs: <String>[
        '· Identity and contact data: e-mail address, display name.',
        '· Transaction security data: IP address, session and sign-in records, device type.',
        '· Location data: only with permission and only while the app is open; stored with hazard and status notes.',
        '· User content: notes, reviews, occupancy reports, contribution points and badges.',
        'If you use the app without an account, none of this is processed; only technical server logs are created.',
      ]),
      LegalSection(heading: 'Purposes', paragraphs: <String>[
        '· Creating and managing a membership',
        '· Sharing maritime information and verifying its accuracy',
        '· Preventing false or misleading content and abuse',
        '· Keeping the service secure and available',
        '· Meeting legal obligations',
      ]),
      LegalSection(heading: 'Legal basis', paragraphs: <String>[
        'Data is processed under Article 5 of the law on the grounds of performance of a contract, compliance with a legal obligation, and legitimate interest that does not harm fundamental rights and freedoms.',
        'Location data is processed only with EXPRESS CONSENT. You may withdraw that consent at any time by turning off location permission in your phone settings.',
      ]),
      LegalSection(heading: 'Transfers', paragraphs: <String>[
        'Personal data may be transferred to service providers established abroad for authentication, mapping and hosting.',
        'Your notes, reviews and display name are visible to other users inside the app; you share them knowing this.',
        'No other sharing takes place. Where legally compelled, sharing is limited to the scope of the request.',
      ]),
      LegalSection(heading: 'Collection method', paragraphs: <String>[
        'Data is collected electronically through the mobile application, automatically and partly automatically, when you register, create content and use the app.',
      ]),
      LegalSection(heading: 'Your rights under Article 11', paragraphs: <String>[
        'Regarding your personal data you have the right to:',
        '· learn whether it is processed,',
        '· request information if it has been processed,',
        '· learn the purpose and whether it is used accordingly,',
        '· know the third parties it is transferred to, at home or abroad,',
        '· request correction if it is incomplete or incorrect,',
        '· request erasure or destruction within the conditions of the law,',
        '· request that correction, erasure and destruction be notified to third parties,',
        '· object to a result against you produced solely by automated analysis,',
        '· claim compensation if you suffer loss because of unlawful processing.',
      ]),
      LegalSection(heading: 'Applications', paragraphs: <String>[
        'Send requests regarding your rights to $kLegalContact. Your application will be concluded within thirty days at the latest.',
        'You do not need to apply in order to delete your account: use "Delete my account" in the Account section of the Profile tab.',
      ]),
    ],
  ),
  'terms': LegalText(
    title: 'Terms of Use',
    summary: 'The limits of the app and the skipper\'s responsibility.',
    sections: <LegalSection>[
      LegalSection(heading: 'Acceptance', paragraphs: <String>[
        'By using Koybul you accept these terms. If you do not accept them, do not use the app.',
      ]),
      LegalSection(heading: 'IMPORTANT: Koybul is not a navigational publication', paragraphs: <String>[
        'Koybul is NOT an official navigational publication, chart, pilot book or electronic navigation system, and does not replace one.',
        'Route suggestions rest on a coarse land-and-water grid. They do NOT know about shallows, rocks, reefs, wrecks, fish farms, military or restricted zones, traffic separation schemes, currents or tides.',
        'Depth, seabed, shelter and capacity information is compiled from sources and can change over time. Its accuracy is not guaranteed.',
        'Weather and wind information is a third-party forecast; forecasts can be wrong.',
        'Always make navigational decisions using current official charts, navigational publications and your own observation.',
      ]),
      LegalSection(heading: 'The skipper is responsible', paragraphs: <String>[
        'The safety of the vessel, her crew and her passage is the skipper\'s responsibility alone.',
        'Nothing in this app reduces, shares or takes over that responsibility.',
        'In an emergency call the radio and official rescue services, not the app.',
      ]),
      LegalSection(heading: 'Account and community rules', paragraphs: <String>[
        'What you share must be accurate and based on your own observation. Do not present something you do not know as fact.',
        'Prohibited: misleading or invented maritime information, insults and harassment, sharing another person\'s private information, advertising and spam, passing off someone else\'s content as your own.',
        'Content breaking these rules may be removed; repeated breaches may suspend the account.',
        'Safety warnings matter most: a false warning buries a real danger.',
      ]),
      LegalSection(heading: 'Content you share', paragraphs: <String>[
        'Your content remains yours. By sharing it you grant us a free, open-ended licence to display it inside Koybul.',
        'You can delete your content at any time. Deleted content stops being visible in the app.',
      ]),
      LegalSection(heading: 'Availability', paragraphs: <String>[
        'The service is provided "as is". It is not guaranteed to be uninterrupted or error-free.',
        'Parts of the app need an internet connection, and there may be none at sea. Note down critical information before you leave.',
      ]),
      LegalSection(heading: 'Limitation of liability', paragraphs: <String>[
        'To the maximum extent permitted by law, we are not liable for indirect damages, data loss or loss of profit arising from use of the app.',
        'This limitation does not cover liability that cannot be limited by law.',
      ]),
      LegalSection(heading: 'Changes and contact', paragraphs: <String>[
        'If these terms change, the effective date in the app is updated.',
        'Turkish law applies to disputes.',
        'Contact: $kLegalContact',
      ]),
    ],
  ),
};
