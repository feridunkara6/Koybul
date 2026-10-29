/// Bildirim kutusu satırı (SP-2 Döngü, kurucu onayı 2026-10-31).
///
/// Sunucu METİN GÖNDERMEZ: tür + data (kimlik/ad) gelir, metni istemci kendi
/// dilinde üretir (l10n mobilde yaşar ilkesi). Bilinmeyen tür atlanmaz —
/// liste genel bir satırla gösterir (ileri sürüm uyumu).
class InboxItem {
  const InboxItem({
    required this.id,
    required this.type,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;

  /// 'qa_answer' | 'route_decision' | 'event_update' | 'helpful_received'
  /// | 'level_up' — ileride yenileri gelebilir.
  final String type;

  /// Tür bazlı yük: kind/id/title/name/level/count (hepsi dize).
  final Map<String, String> data;

  final String? readAt;
  final String createdAt;

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as String,
        type: json['type'] as String,
        data: ((json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{})
            .map((String k, dynamic v) => MapEntry(k, '$v')),
        readAt: json['readAt'] as String?,
        createdAt: json['createdAt'] as String,
      );
}
