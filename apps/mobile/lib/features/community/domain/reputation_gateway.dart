import 'package:dockly_api/dockly_api.dart';

/// Denizci profili ağ geçidi — testte bellek içi sahte ile değiştirilir.
///
/// Buradaki her çağrı HESAP ister; arayüz kapısı (`requireAccount`) misafiri
/// buraya hiç düşürmez, sunucu da `@RequireAccount()` ile ikinci katmanı tutar.
abstract interface class ReputationGateway {
  Future<ReputationSummary> summary();
  Future<List<ContributionItem>> contributions();

  /// Moderasyon — yalnız `moderator` rolü. Rol yoksa [ForbiddenFailure] gelir.
  Future<Map<String, int>> moderationCounts();
  Future<List<ModerationItem>> moderationQueue({String? entityType});
  Future<void> decide({required String taskId, required bool approve, String? reason});
}
