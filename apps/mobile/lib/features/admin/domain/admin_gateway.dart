import 'package:dockly_api/dockly_api.dart'
    show
        AdminContentItem,
        AdminDealInput,
        AdminEventInput,
        AdminPremiumGrant,
        AdminStats,
        EventParticipantView;

/// YÖNETİM PANELİ ağ geçidi (kurucu talebi 2026-09-25) — testte sahteyle
/// değiştirilir; gerçek uygulama `/v1/admin/*` uçlarına gider.
abstract interface class AdminGateway {
  Future<AdminStats> stats();

  Future<AdminPremiumGrant> grantPremium({
    required String email,
    required int months,
  });

  // --- Etkinlik & fırsat yönetimi (V1, kurucu onayı 2026-10-23) ---

  Future<String> createEvent(AdminEventInput input);

  /// İptal — kayıtlılar uygulamada iptal şeridini görür (push V2).
  Future<void> cancelEvent(String eventId);

  Future<List<EventParticipantView>> participants(String eventId);

  Future<String> createDeal(AdminDealInput input);

  Future<void> setDealActive(String dealId, {required bool isActive});

  // --- İçerik yönetimi (kurucu talebi 2026-10-27) ---

  /// Tür: routes|questions|answers|notes|reviews|boats.
  Future<List<AdminContentItem>> listContent(String type);

  /// Yayından indirme (yumuşak silme) — veri sunucuda denetim için durur.
  Future<void> deleteContent({required String type, required String id});
}
