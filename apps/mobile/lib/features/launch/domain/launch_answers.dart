/// Açılış sorularının cevap uzayı (onaylı tasarım E4–E5, 2026-08;
/// Faz 1'de sadeleştirildi).
library;

/// Ölçü kaydırıcılarının başlangıç değerleri.
///
/// Eskiden bunlar bir "tekne tipi" sorusundan türetiliyordu (yelkenli 12/1,8 ·
/// motoryat 14/1,2 · katamaran 12/1,1 · gulet 20/2,5). O soru Faz 1'de
/// KALDIRILDI: verilen cevap `MyBoat.typeId` alanına yazılıyor ama uygulamada
/// hiçbir yerde OKUNMUYORDU — yani kullanıcıya sorulan ilk soru, hiçbir işe
/// yaramayan bir soruydu. Geriye kalan tek işlevi buradaki iki başlangıç
/// değeriydi; onlar da yelkenli varsayılanına sabitlendi (Türkiye kıyısındaki
/// amatör filonun ağırlık merkezi orası).
///
/// Kullanıcı ölçüyü zaten kaydırıcıyla ayarlıyor; tip bilgisine ihtiyaç
/// duyulursa Profil → Teknem'den girilebilir.
const double kDefaultLengthM = 12;
const double kDefaultDraftM = 1.8;

/// İlerleme çubuğunun paydası: akışta kalan SORU ekranı sayısı (ölçüler +
/// bölge). Karşılama ve konum ön-izni soru değildir, sayılmaz. Bölge yalnız
/// konum reddedilirse çıktığı için çoğu kullanıcı yalnız 1/2'yi görür — bu
/// bilinçli: "en fazla iki soru" sözü, gördüğün her ekranda tutulur.
const int kLaunchQuestionCount = 2;

/// Seyir bölgesi — E5. Adlar YER ADIDIR (özel isim, çevrilmez); merkezler
/// bölgenin coğrafi orta noktası (gerçek koordinat — uydurma veri değil).
/// [nx]/[ny]: kıyı görselindeki normalize konum (0..1, dekoratif).
class LaunchRegion {
  const LaunchRegion(this.name, this.lat, this.lon, this.nx, this.ny);

  final String name;
  final double lat;
  final double lon;
  final double nx;
  final double ny;
}

/// Kuzeybatıdan güneydoğuya Türk kıyıları — onaylı E5 listesi.
const List<LaunchRegion> kLaunchRegions = <LaunchRegion>[
  LaunchRegion('Ayvalık – Kuzey Ege', 39.30, 26.65, 0.16, 0.16),
  LaunchRegion('Çeşme – Sığacık', 38.25, 26.55, 0.10, 0.40),
  LaunchRegion('Bodrum – Gökova', 36.99, 27.85, 0.30, 0.64),
  LaunchRegion('Marmaris – Hisarönü', 36.78, 28.15, 0.50, 0.72),
  LaunchRegion('Fethiye – Göcek', 36.68, 28.90, 0.68, 0.76),
  LaunchRegion('Kaş – Kekova', 36.19, 29.72, 0.86, 0.86),
];

/// Bölge odağının yakınlaştırması — körfez ölçeği (Konumum'un 12'sinden geniş).
const double kRegionFocusZoom = 9;

/// Bağlı marina odağının yakınlaştırması (kullanıcı isteği 2026-08): marina
/// ÇEVRESİ görünsün — bölgeden yakın (9), "Konumum"dan geniş (12). Kaptanın
/// evinden çıkıp gidebileceği koylar tek bakışta ekranda olsun.
const double kHomeMarinaFocusZoom = 11;
