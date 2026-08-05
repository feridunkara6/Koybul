import 'package:dockly_mobile/features/route/domain/saved_route.dart';

/// Testte `SavedRoutesStore` yerine geçen sahte (bellek içi).
class FakeSavedRoutesStore implements SavedRoutesStore {
  List<SavedRoute> data = <SavedRoute>[];
  int saveCount = 0;

  @override
  Future<List<SavedRoute>> load() async => data;

  @override
  Future<void> save(List<SavedRoute> routes) async {
    saveCount++;
    data = routes;
  }
}
