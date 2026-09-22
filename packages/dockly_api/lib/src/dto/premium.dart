/// Premium DTO'ları (P3, kurucu onayı 2026-09-21) — `/v1/premium/*` sözleşmesinin
/// Dart izdüşümü (sunucu: apps/api premium modülü).
library;

/// `GET /v1/premium/me` gövdesi: abonelik durumu + aylık keşif hakkı.
class PremiumMe {
  const PremiumMe({
    required this.active,
    required this.until,
    required this.productId,
    required this.explorationRemaining,
    required this.explorationLimit,
    required this.monthKey,
  });

  /// Premium şu an geçerli mi (sunucu kararı: premiumUntil > şimdi).
  final bool active;

  /// Aboneliğin bitiş/yenilenme anı; hiç abone olunmamışsa null.
  /// Süresi geçmiş tarih = ESKİ abone (kayıtları salt-okunur korunur).
  final DateTime? until;

  /// Son bilinen mağaza ürünü (ör. koybul.premium.yillik); yoksa null.
  final String? productId;

  /// Bu ay kalan keşif hakkı (üyeye ayda [explorationLimit] koy açma hediyesi).
  final int explorationRemaining;
  final int explorationLimit;

  /// Sunucunun saydığı takvim ayı (UTC 'YYYY-AA') — bilgi amaçlı.
  final String monthKey;

  factory PremiumMe.fromJson(Map<String, dynamic> json) {
    final premium = json['premium'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final exploration =
        json['exploration'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final String? untilRaw = premium['until'] as String?;
    return PremiumMe(
      active: premium['active'] as bool? ?? false,
      until: untilRaw == null ? null : DateTime.tryParse(untilRaw),
      productId: premium['productId'] as String?,
      explorationRemaining: (exploration['remaining'] as num?)?.toInt() ?? 0,
      explorationLimit: (exploration['limit'] as num?)?.toInt() ?? 0,
      monthKey: exploration['monthKey'] as String? ?? '',
    );
  }
}

/// `POST /v1/premium/apple/link` yanıtı — Apple'dan DOĞRULANMIŞ gerçek durum.
class PremiumLinkResult {
  const PremiumLinkResult({
    required this.active,
    required this.until,
    required this.productId,
  });

  final bool active;
  final DateTime? until;
  final String? productId;

  factory PremiumLinkResult.fromJson(Map<String, dynamic> json) {
    final String? untilRaw = json['until'] as String?;
    return PremiumLinkResult(
      active: json['active'] as bool? ?? false,
      until: untilRaw == null ? null : DateTime.tryParse(untilRaw),
      productId: json['productId'] as String?,
    );
  }
}
