/// PUSH BİLDİRİM tercihleri (push paketi, kurucu onayı 2026-10-27) —
/// cihaz başına üç anahtar. Sunucu `/v1/notifications/devices*` uçlarının
/// döndürdüğü güncel durumdur; ayarlar ekranı bunu çizer.
class NotificationPrefs {
  const NotificationPrefs({
    required this.community,
    required this.events,
    required this.moderation,
  });

  /// Topluluk: soruna cevap + rota moderasyon kararı.
  final bool community;

  /// Etkinlikler: iptal + "yarın başlıyor" hatırlatması.
  final bool events;

  /// Moderasyon kuyruğu (yalnız admin hesaplarda anlamlı).
  final bool moderation;

  static NotificationPrefs fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        community: json['community'] as bool? ?? true,
        events: json['events'] as bool? ?? true,
        moderation: json['moderation'] as bool? ?? true,
      );
}
