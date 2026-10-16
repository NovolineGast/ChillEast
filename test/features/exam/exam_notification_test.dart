import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/services/notification_service.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Exam Reminders Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('scheduleExamReminders handles empty list or 0 reminder minutes gracefully', () async {
      final service = NotificationService();
      // 0 分钟不调度
      await expectLater(
        service.scheduleExamReminders([], 0),
        completes,
      );

      final exam = ExamScheduleModel(
        id: 'exam_1',
        title: '大学英语期末考试',
        time: DateTime.now().add(const Duration(days: 2)),
      );

      // 0 分钟不调度
      await expectLater(
        service.scheduleExamReminders([exam], 0),
        completes,
      );

      // 负数不调度
      await expectLater(
        service.scheduleExamReminders([exam], -10),
        completes,
      );
    });
  });
}
