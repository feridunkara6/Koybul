import 'package:dockly_mobile/features/launch/domain/launch_store.dart';

/// Testte `LaunchStore` yerine geçen sahte (bellek içi).
class FakeLaunchStore implements LaunchStore {
  FakeLaunchStore({this.done = false});

  bool done;
  int markCount = 0;

  @override
  Future<bool> isDone() async => done;

  @override
  Future<void> markDone() async {
    done = true;
    markCount += 1;
  }
}
