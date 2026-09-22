import 'package:dockly_api/dockly_api.dart' show PremiumMe;
import 'package:shared_preferences/shared_preferences.dart';

/// PREMIUM ÇEVRİMDIŞI HAFIZASI (P4, premium v3 raporu §7 "denizde internet yok").
///
/// Amaç: sunucuya ULAŞILAMADIĞINDA (açık denizde, çekimsiz koyda) premium
/// üyenin hakkı kaybolmasın. Son BAŞARILI /premium/me yanıtından yalnız iki
/// şey saklanır: bitiş tarihi + paket kimliği. Karar yine tarihe bakılarak
/// verilir — süre geçtiyse çevrimdışı bile olsa premium KAPANIR (uydurma
/// "sonsuz premium" yok, kurucu ilkesi: tahmin yok).
///
/// GÜVENLİK NOTU: bu bir yetki kaynağı DEĞİLDİR — sunucu tarafı zaten her
/// kilitli veriyi kendisi korur (vitrin sunucuda kesilir). Buradaki kayıt
/// yalnız cihaz içi görünüm (rota kotası sınırsız mı?) için yumuşak izdir.
///
/// Cihaz deposu her ortamda bulunmayabilir (testler, ilk açılış) — her okuma
/// ve yazma try/catch ile korunur; olmazsa sessizce vazgeçilir.
class PremiumOfflineCache {
  const PremiumOfflineCache._();

  static const String _kUntilMs = 'premium.until_ms';
  static const String _kProductId = 'premium.product_id';

  /// Sunucudan gelen son durumu saklar. Aktif değilse izi SİLER — süresi
  /// bitmiş üyelik çevrimdışına "aktif" diye taşınmaz.
  static Future<void> save(PremiumMe me) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DateTime? until = me.until;
      if (!me.active || until == null) {
        await prefs.remove(_kUntilMs);
        await prefs.remove(_kProductId);
        return;
      }
      await prefs.setInt(_kUntilMs, until.millisecondsSinceEpoch);
      final String? product = me.productId;
      if (product == null) {
        await prefs.remove(_kProductId);
      } else {
        await prefs.setString(_kProductId, product);
      }
    } catch (_) {
      // Depo yoksa premium yine sunucudan bilinir; sadece çevrimdışı izi olmaz.
    }
  }

  /// Saklanan izden bir durum kurar. İz yoksa ya da SÜRE GEÇTİYSE null döner
  /// (çevrimdışı af yok — tarih tek hakem). Keşif hakkı sayaçları çevrimdışı
  /// BİLİNEMEZ: dürüstçe 0 kalan / boş ay olarak işaretlenir.
  static Future<PremiumMe?> read() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? untilMs = prefs.getInt(_kUntilMs);
      if (untilMs == null) return null;
      final DateTime until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      if (!until.isAfter(DateTime.now())) return null;
      return PremiumMe(
        active: true,
        until: until,
        productId: prefs.getString(_kProductId),
        explorationRemaining: 0,
        explorationLimit: 3,
        monthKey: '',
      );
    } catch (_) {
      return null;
    }
  }
}
