import 'package:dockly_mobile/features/boat/domain/maintenance.dart';

/// Bellek içi bakım deposu — gerçek `shared_preferences`'a gitmez.
class FakeMaintenanceStore implements MaintenanceStore {
  List<MaintenanceRecord> data = <MaintenanceRecord>[];
  int saveCount = 0;

  @override
  Future<List<MaintenanceRecord>> load() async => data;

  @override
  Future<void> save(List<MaintenanceRecord> records) async {
    saveCount++;
    data = records;
  }
}
