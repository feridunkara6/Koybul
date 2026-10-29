import 'package:dockly_api/dockly_api.dart' show FeedItem;

/// TAKİP AKIŞI + SEYİR PAYLAŞIMI ağ geçidi (SP-3b, kurucu onayı 2026-10-31).
///
/// TÜM uçlar hesap ister (misafir etkileşemez); testte sahteyle değiştirilir
/// (profil geçidiyle aynı desen).
abstract interface class FeedGateway {
  /// Takip ettiklerimin akışı — en yeni önce.
  Future<List<FeedItem>> following();

  /// Gerçekleşen seyri paylaşır; sunucu kimliğini döndürür.
  /// GİZLİLİK: "Konumum" başlangıcında [startName] null GÖNDERİLİR.
  Future<String> shareTrip({
    String? startName,
    String? endName,
    required double distanceNm,
    int? durationMin,
    required int stopCount,
    required String sailedOn,
  });

  /// "Pruvan neta" ⚓ aç/kapat — güncel durum + sayaç döner.
  Future<({bool reacted, int pruvaCount})> togglePruva(String tripId);
}
