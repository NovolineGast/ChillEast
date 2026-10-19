import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timetable_storage.dart';

/// 标记是否正在执行后台静默课表同步
final timetableSyncInProgressProvider = StateProvider<bool>((ref) => false);

final timetableStatusProvider = StateNotifierProvider<TimetableStatusNotifier, bool>((ref) {
  return TimetableStatusNotifier();
});

class TimetableStatusNotifier extends StateNotifier<bool> {
  TimetableStatusNotifier() : super(false) {
    checkStatus();
  }

  Future<void> checkStatus({bool forceNotify = false}) async {
    final storage = TimetableStorage();
    final has = await storage.hasLocalTimetable();
    final courses = await storage.readCourseList();
    final nextState = has && courses.isNotEmpty;
    if (forceNotify && state == nextState) {
      state = !nextState;
    }
    state = nextState;
  }

  Future<void> refresh() async {
    await checkStatus(forceNotify: true);
  }
}

