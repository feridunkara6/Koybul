/// YASAL METİNLER — alan modeli (Faz 0, yayın engeli).
///
/// Üç belge uygulamanın İÇİNDE okunur: gizlilik politikası, KVKK aydınlatma
/// metni ve kullanım koşulları. İnternet gerekmez — kaptan denizde de
/// okuyabilmeli. Metinler bu uygulama için yazılmıştır ve UYGULAMANIN
/// GERÇEKTE YAPTIĞINI anlatır; şablon değildir.
///
/// KURAL: burada yazan her cümlenin kodda karşılığı olmalı. Bir veri
/// toplamayı bırakırsak ya da yenisini eklersek bu dosya AYNI pakette
/// güncellenir. Yanlış bir gizlilik metni, hiç metin olmamasından kötüdür.
library;

import 'package:dockly_ui/dockly_ui.dart' show DocklyIconData;

/// Belge içindeki tek başlık ve altındaki paragraflar.
class LegalSection {
  const LegalSection({required this.heading, required this.paragraphs});

  final String heading;

  /// Düz paragraflar. Madde işareti gerekiyorsa paragraf '· ' ile başlar —
  /// ekran bunu girintili çizer. Zengin metin (kalın/bağlantı) bilinçli
  /// olarak YOK: yasal metinde biçim değil, okunabilirlik önemli.
  final List<String> paragraphs;
}

/// Tek yasal belge.
class LegalDoc {
  const LegalDoc({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.updated,
    required this.sections,
  });

  /// Kalıcı kimlik (dilden bağımsız): 'privacy' | 'kvkk' | 'terms'.
  final String id;
  final DocklyIconData icon;
  final String title;

  /// Listede başlığın altında görünen tek cümle.
  final String summary;

  /// Yürürlük tarihi (metinle birlikte elle güncellenir).
  final String updated;

  final List<LegalSection> sections;
}

/// Belge metni (dile göre değişen kısım).
class LegalText {
  const LegalText({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<LegalSection> sections;
}
