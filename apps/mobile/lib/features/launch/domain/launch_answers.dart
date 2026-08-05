/// Açılış sorularının cevap uzayı (onaylı tasarım E3–E5, 2026-08).
library;

/// Tekne tipi seçenekleri — E3. Kimlikler MyBoat.typeId'ye yazılır.
enum BoatTypeChoice {
  sail('sail'),
  motor('motor'),
  catamaran('catamaran'),
  gulet('gulet');

  const BoatTypeChoice(this.id);

  final String id;

  /// E4 kaydırıcılarının tipe göre AKILLI VARSAYILANLARI (onaylı):
  /// yelkenli 12 m / 1,8 m · motoryat 14 m / 1,2 m · katamaran 12 m / 1,1 m ·
  /// gulet 20 m / 2,5 m. Tip seçilmediyse yelkenli varsayılanı kullanılır.
  double get defaultLengthM => switch (this) {
        BoatTypeChoice.sail => 12,
        BoatTypeChoice.motor => 14,
        BoatTypeChoice.catamaran => 12,
        BoatTypeChoice.gulet => 20,
      };

  double get defaultDraftM => switch (this) {
        BoatTypeChoice.sail => 1.8,
        BoatTypeChoice.motor => 1.2,
        BoatTypeChoice.catamaran => 1.1,
        BoatTypeChoice.gulet => 2.5,
      };
}

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
