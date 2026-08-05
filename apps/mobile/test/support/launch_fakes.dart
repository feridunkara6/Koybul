import 'package:dockly_mobile/features/launch/domain/launch_store.dart';

/// Testte `LaunchStore` yerine geçen sahte (bellek içi).
class FakeLaunchStore implements LaunchStore {
  FakeLaunchStore({this.done = false, this.savedStep = 0});

  bool done;
  int markCount = 0;
  int savedStep;

  @override
  Future<bool> isDone() async => done;

  @override
  Future<void> markDone() async {
    done = true;
    savedStep = 0;
    markCount += 1;
  }

  @override
  Future<int> step() async => savedStep;

  @override
  Future<void> setStep(int value) async => savedStep = value;
}
