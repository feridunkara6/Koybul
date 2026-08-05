import 'package:dockly_mobile/features/logbook/domain/log_entry.dart';

/// Testte `LogbookStore` yerine geçen sahte (bellek içi).
class FakeLogbookStore implements LogbookStore {
  List<LogEntry> data = <LogEntry>[];
  int saveCount = 0;

  @override
  Future<List<LogEntry>> load() async => data;

  @override
  Future<void> save(List<LogEntry> entries) async {
    saveCount++;
    data = entries;
  }
}
