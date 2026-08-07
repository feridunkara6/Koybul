import 'package:dockly_mobile/features/deck/domain/sea_trip_log.dart';

/// Bellek içi seyir deposu — gerçek `shared_preferences`'a gitmez.
class FakeTripStore implements SeaTripLogStore {
  List<SeaTripLog> data = <SeaTripLog>[];
  ActiveTrip? active;
  int saveCount = 0;

  @override
  Future<List<SeaTripLog>> load() async => data;

  @override
  Future<void> save(List<SeaTripLog> trips) async {
    saveCount++;
    data = trips;
  }

  @override
  Future<ActiveTrip?> loadActive() async => active;

  @override
  Future<void> saveActive(ActiveTrip? trip) async {
    active = trip;
  }
}
