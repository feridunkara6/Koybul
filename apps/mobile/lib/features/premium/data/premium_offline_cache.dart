import 'package:dockly_api/dockly_api.dart' show PremiumMe;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
abstract interface class PremiumOfflineStore {
  /// Sunucudan gelen son durumu saklar; aktif değilse izi siler.
  Future<void> save(PremiumMe me);

  /// Saklanan izden durum kurar; iz yoksa ya da süresi geçtiyse null.
  Future<PremiumMe?> read();
}

/// Depo sağlayıcısı — TESTLERDE HER ZAMAN sahteyle değiştirilir (depo kuralı:
/// testler gerçek shared_preferences'a asla gitmez; docs/15).
final Provider<PremiumOfflineStore> premiumOfflineStoreProvider =
    Provider<PremiumOfflineStore>((_) => const SharedPrefsPremiumOfflineStore());

/// Gerçek uygulama. Cihaz deposu her ortamda bulunmayabilir — her okuma ve
/// yazma try/catch ile korunur; olmazsa sessizce vazgeçilir.
class SharedPrefsPremiumOfflineStore implements PremiumOfflineStore {
  const SharedPrefsPremiumOfflineStore();

  static const String _kUntilMs = 'premium.until_ms';
  static const String _kProductId = 'premium.product_id';

  @override
  Future<void> save(PremiumMe me) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DateTime? until = me.until;
      if (!me.active || until == null) {
        // Süresi bitmiş üyelik çevrimdışına "aktif" diye taşınmaz.
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

  @override
  Future<PremiumMe?> read() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? untilMs = prefs.getInt(_kUntilMs);
      if (untilMs == null) return null;
      final DateTime until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      // Çevrimdışı af yok — tarih tek hakem.
      if (!until.isAfter(DateTime.now())) return null;
      return PremiumMe(
        active: true,
        until: until,
        productId: prefs.getString(_kProductId),
        // Keşif hakkı sayaçları çevrimdışı BİLİNEMEZ: dürüstçe 0 kalan.
        explorationRemaining: 0,
        explorationLimit: 3,
        monthKey: '',
      );
    } catch (_) {
      return null;
    }
  }
}
