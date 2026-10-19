import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/home/utils/feed_sorter.dart';
import 'package:ChillEast/features/library/models/library_models.dart';
import 'package:ChillEast/features/leave/models/leave_models.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';

void main() {
  group('FeedSorter sortFeedItems', () {
    test('returns manual order when autoSort is false', () {
      final manual = ['feed_quick', 'feed_balance', 'feed_agenda'];
      final result = FeedSorter.sortFeedItems(
        autoSort: false,
        manualOrder: manual,
        hasLibraryP0: true,
        hasLeaveP1: true,
        hasAgendaP2: true,
        hasHomeworkP3: true,
        hasBalanceP4: true,
      );
      expect(result, equals(manual));
    });

    test('returns default order when autoSort is true and no boosted priorities', () {
      final result = FeedSorter.sortFeedItems(
        autoSort: true,
        manualOrder: ['feed_quick'],
        hasLibraryP0: false,
        hasLeaveP1: false,
        hasAgendaP2: false,
        hasHomeworkP3: false,
        hasBalanceP4: false,
      );
      expect(result, equals([
        'feed_quick',
        'feed_library',
        'feed_agenda',
        'feed_homework',
        'feed_leave',
        'feed_repair',
        'feed_questionnaire',
        'feed_balance',
      ]));
    });

    test('boosts library to p0 when hasLibraryP0 is true', () {
      final result = FeedSorter.sortFeedItems(
        autoSort: true,
        manualOrder: [],
        hasLibraryP0: true,
        hasLeaveP1: false,
        hasAgendaP2: false,
        hasHomeworkP3: false,
        hasBalanceP4: false,
      );
      expect(result, equals([
        'feed_quick',
        'feed_library',
        'feed_agenda',
        'feed_homework',
        'feed_leave',
        'feed_repair',
        'feed_questionnaire',
        'feed_balance',
      ]));
    });

    test('boosts leave to p1 and balance to p4', () {
      final result = FeedSorter.sortFeedItems(
        autoSort: true,
        manualOrder: [],
        hasLibraryP0: false,
        hasLeaveP1: true,
        hasAgendaP2: false,
        hasHomeworkP3: false,
        hasBalanceP4: true,
      );
      expect(result, equals([
        'feed_quick',
        'feed_leave',
        'feed_balance',
        'feed_library',
        'feed_agenda',
        'feed_homework',
        'feed_repair',
        'feed_questionnaire',
      ]));
    });

    test('correctly orders all priorities p0 -> p1 -> p2 -> p3 -> p4', () {
      final result = FeedSorter.sortFeedItems(
        autoSort: true,
        manualOrder: [],
        hasLibraryP0: true,
        hasLeaveP1: true,
        hasAgendaP2: true,
        hasHomeworkP3: true,
        hasBalanceP4: true,
      );
      expect(result, equals([
        'feed_quick',
        'feed_library',
        'feed_leave',
        'feed_agenda',
        'feed_homework',
        'feed_balance',
        'feed_repair',
        'feed_questionnaire',
      ]));
    });
  });

  group('FeedSorter condition checkers', () {
    test('checkLibraryP0 triggers between -10 min and +20 min', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      final reserveAt10 = LibraryReserveModel(
        id: 1,
        roomId: 101,
        deptId: 1,
        seatNum: 'A01',
        startTime: DateTime(2026, 10, 17, 10, 5), // 5 min in future -> within 10 min before
        endTime: DateTime(2026, 10, 17, 12, 0),
        status: 0,
        firstLevelName: 'Room',
        secondLevelName: '',
        thirdLevelName: '',
        today: '2026-10-17',
      );

      expect(FeedSorter.checkLibraryP0(reserves: [reserveAt10], currentTime: now), isTrue);

      // 15 min after startTime -> within 20 min after
      final nowAfter = DateTime(2026, 10, 17, 10, 20);
      expect(FeedSorter.checkLibraryP0(reserves: [reserveAt10], currentTime: nowAfter), isTrue);

      // 25 min after startTime -> beyond 20 min
      final nowTooLate = DateTime(2026, 10, 17, 10, 31);
      expect(FeedSorter.checkLibraryP0(reserves: [reserveAt10], currentTime: nowTooLate), isFalse);

      // 15 min before startTime -> earlier than 10 min before
      final nowTooEarly = DateTime(2026, 10, 17, 9, 45);
      expect(FeedSorter.checkLibraryP0(reserves: [reserveAt10], currentTime: nowTooEarly), isFalse);
    });

    test('checkLeaveP1 triggers when leave is approved and before endTime', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      const approvedLeave = LeaveRecord(
        id: '1',
        typeName: '事假',
        startTime: '2026-10-17 08:00',
        endTime: '2026-10-17 18:00',
        auditStatus: '9',
        auditResultName: '同意',
      );
      expect(FeedSorter.checkLeaveP1(leaves: [approvedLeave], currentTime: now), isTrue);

      const rejectedLeave = LeaveRecord(
        id: '2',
        typeName: '事假',
        startTime: '2026-10-17 08:00',
        endTime: '2026-10-17 18:00',
        auditStatus: '9',
        auditResultName: '不通过',
      );
      expect(FeedSorter.checkLeaveP1(leaves: [rejectedLeave], currentTime: now), isFalse);

      const expiredLeave = LeaveRecord(
        id: '3',
        typeName: '事假',
        startTime: '2026-10-16 08:00',
        endTime: '2026-10-16 18:00',
        auditStatus: '9',
        auditResultName: '通过',
      );
      expect(FeedSorter.checkLeaveP1(leaves: [expiredLeave], currentTime: now), isFalse);
    });

    test('checkAgendaP2 triggers within 60 minutes before course or exam start', () {
      // Period 1 start time is 08:00
      const course = CourseModel(
        id: '1',
        name: '操作系统',
        teacher: '张老师',
        classroom: 'A101',
        weeks: '1-16',
        periods: '01-02',
        dayOfWeek: 6,
        startPeriod: 1,
        endPeriod: 2,
      );

      final nowAt730 = DateTime(2026, 10, 17, 7, 30);
      expect(
        FeedSorter.checkAgendaP2(
          courses: [course],
          exams: [],
          previewDate: DateTime(2026, 10, 17),
          currentTime: nowAt730,
        ),
        isTrue,
      );

      final nowAt630 = DateTime(2026, 10, 17, 6, 30); // 90 min before
      expect(
        FeedSorter.checkAgendaP2(
          courses: [course],
          exams: [],
          previewDate: DateTime(2026, 10, 17),
          currentTime: nowAt630,
        ),
        isFalse,
      );

      // Exam test: starts at 15:00
      final exam = ExamScheduleModel(
        id: 'exam_1',
        title: '期末考',
        courseName: '计算机网络',
        time: DateTime(2026, 10, 17, 15, 0),
        location: 'B201',
      );

      final nowAt1430 = DateTime(2026, 10, 17, 14, 30);
      expect(
        FeedSorter.checkAgendaP2(
          courses: [],
          exams: [exam],
          currentTime: nowAt1430,
        ),
        isTrue,
      );
    });

    test('checkHomeworkP3 triggers within 48 hours before deadline', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      final hwDueIn24h = HomeworkModel(
        id: '1',
        studentId: 'test_student',
        title: '算法大作业',
        courseName: '算法分析',
        endTime: DateTime(2026, 10, 18, 10, 0),
        status: HomeworkStatus.pending,
      );
      expect(FeedSorter.checkHomeworkP3(homeworks: [hwDueIn24h], currentTime: now), isTrue);

      final hwDueIn72h = HomeworkModel(
        id: '2',
        studentId: 'test_student',
        title: '数据库实验',
        courseName: '数据库原理',
        endTime: DateTime(2026, 10, 20, 11, 0),
        status: HomeworkStatus.pending,
      );
      expect(FeedSorter.checkHomeworkP3(homeworks: [hwDueIn72h], currentTime: now), isFalse);

      final hwCompleted = HomeworkModel(
        id: '3',
        studentId: 'test_student',
        title: '已完成作业',
        courseName: '软件工程',
        endTime: DateTime(2026, 10, 18, 10, 0),
        status: HomeworkStatus.completed,
      );
      expect(FeedSorter.checkHomeworkP3(homeworks: [hwCompleted], currentTime: now), isFalse);
    });

    test('checkBalanceP4 triggers when balance <= 10', () {
      final lowInfo = ElectricityBalanceInfo(balance: '9.50');
      expect(FeedSorter.checkBalanceP4(balances: [lowInfo]), isTrue);

      final boundaryInfo = ElectricityBalanceInfo(balance: '10.00');
      expect(FeedSorter.checkBalanceP4(balances: [boundaryInfo]), isTrue);

      final normalInfo = ElectricityBalanceInfo(balance: '15.00');
      expect(FeedSorter.checkBalanceP4(balances: [normalInfo]), isFalse);
    });
  });
}
