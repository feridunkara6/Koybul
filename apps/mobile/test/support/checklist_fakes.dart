import 'package:dockly_mobile/features/checklist/domain/checklist_store.dart';

/// Testte `ChecklistStore` yerine geçen sahte (bellek içi).
class FakeChecklistStore implements ChecklistStore {
  String? day;
  int mask = 0;
  String? askDay;
  int saveCount = 0;

  @override
  Future<(String?, int)> loadChecks() async => (day, mask);

  @override
  Future<void> saveChecks(String dayKey, int newMask) async {
    saveCount++;
    day = dayKey;
    mask = newMask;
  }

  @override
  Future<String?> loadAskDay() async => askDay;

  @override
  Future<void> saveAskDay(String dayKey) async => askDay = dayKey;
}
