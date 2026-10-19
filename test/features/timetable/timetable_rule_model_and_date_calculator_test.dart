import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/utils/date_calculator.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

Widget _buildLocalizedWidget(Widget Function(BuildContext) builder) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Builder(builder: builder),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimetableRule Factory & Serialization Tests', () {
    test('createReschedule with period range and actions', () {
      final rule = TimetableRule.createReschedule(
        sourceWeek: 3,
        sourceDayOfWeek: 1,
        targetWeek: 4,
        targetDayOfWeek: 2,
        courseName: '大学英语',
        sourceStartPeriod: 1,
        sourceEndPeriod: 2,
        targetStartPeriod: 3,
        targetEndPeriod: 4,
        isSwap: true,
      );

      expect(rule.type, TimetableRuleType.reschedule);
      expect(rule.description, contains('《大学英语》'));
      expect(rule.description, contains('1-2节 → 第4周周二3-4节'));
      expect(rule.data['isSwap'], isTrue);

      // JSON roundtrip
      final json = rule.toJson();
      final revived = TimetableRule.fromJson(json);
      expect(revived.id, rule.id);
      expect(revived.type, TimetableRuleType.reschedule);
      expect(revived.data['courseName'], '大学英语');

      // Copy mode without periods
      final copyRule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 3,
        targetWeek: 6,
        targetDayOfWeek: 4,
        action: 'copy',
      );
      expect(copyRule.description, contains('（复制）'));

      // Move mode
      final moveRule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 3,
        targetWeek: 6,
        targetDayOfWeek: 4,
        action: 'move',
      );
      expect(moveRule.description, contains('（平移）'));
    });

    test('createSuspension variations', () {
      // 1. Whole semester / multiple weeks Mon-Sun
      final r1 = TimetableRule.createSuspension(
        startWeek: 1,
        endWeek: 4,
        startDayOfWeek: 1,
        endDayOfWeek: 7,
      );
      expect(r1.description, '第1-4周停课');

      // 2. Single whole week
      final r2 = TimetableRule.createSuspension(
        startWeek: 2,
        endWeek: 2,
        startDayOfWeek: 1,
        endDayOfWeek: 7,
      );
      expect(r2.description, '第2周停课');

      // 3. Single day
      final r3 = TimetableRule.createSuspension(
        startWeek: 3,
        endWeek: 3,
        dayOfWeek: 2,
      );
      expect(r3.description, '第3周周二停课');

      // 4. Same week range with periods and course
      final r4 = TimetableRule.createSuspension(
        startWeek: 5,
        endWeek: 5,
        startDayOfWeek: 1,
        endDayOfWeek: 3,
        courseName: '高等数学',
        startPeriod: 1,
        endPeriod: 2,
      );
      expect(r4.description, '《高等数学》第5周周一至周三 1-2节停课');

      // 5. Cross weeks range
      final r5 = TimetableRule.createSuspension(
        startWeek: 6,
        endWeek: 7,
        startDayOfWeek: 5,
        endDayOfWeek: 2,
      );
      expect(r5.description, '第6周周五至第7周周二停课');
    });

    test('createCustomCourse and customCourse getter', () {
      final course = CourseModel(
        id: 'c1',
        name: '形势与政策',
        teacher: '李老师',
        classroom: '十教南201',
        periods: '5-6节',
        dayOfWeek: 3,
        startPeriod: 5,
        endPeriod: 6,
        weeks: '1-8(周)',
      );

      final rule = TimetableRule.createCustomCourse(course: course);
      expect(rule.type, TimetableRuleType.customCourse);
      expect(rule.description, contains('加课：形势与政策'));
      expect(rule.customCourse, isNotNull);
      expect(rule.customCourse?.isCustom, isTrue);
      expect(rule.customCourse?.name, '形势与政策');

      // customCourse on other rule type returns null
      final suspension = TimetableRule.createSuspension(startWeek: 1, endWeek: 2);
      expect(suspension.customCourse, isNull);
    });

    testWidgets('TimetableRuleL10n getLocalizedDescription produces localized strings', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_buildLocalizedWidget((context) {
        ctx = context;
        return const SizedBox();
      }));

      // Reschedule with periods
      final rReschedulePeriods = TimetableRule.createReschedule(
        sourceWeek: 1, sourceDayOfWeek: 1,
        targetWeek: 2, targetDayOfWeek: 2,
        sourceStartPeriod: 1, sourceEndPeriod: 2,
        targetStartPeriod: 3, targetEndPeriod: 4,
        courseName: '物理',
      );
      expect(rReschedulePeriods.getLocalizedDescription(ctx), contains('物理'));

      // Reschedule without periods (copy, swap, move)
      final rCopy = TimetableRule.createReschedule(
        sourceWeek: 1, sourceDayOfWeek: 1,
        targetWeek: 2, targetDayOfWeek: 2,
        action: 'copy',
      );
      expect(rCopy.getLocalizedDescription(ctx), isNotEmpty);

      final rSwap = TimetableRule.createReschedule(
        sourceWeek: 1, sourceDayOfWeek: 1,
        targetWeek: 2, targetDayOfWeek: 2,
        isSwap: true,
      );
      expect(rSwap.getLocalizedDescription(ctx), isNotEmpty);

      // Suspension variations
      final rSusp1 = TimetableRule.createSuspension(startWeek: 1, endWeek: 1, dayOfWeek: 1);
      expect(rSusp1.getLocalizedDescription(ctx), isNotEmpty);

      final rSusp2 = TimetableRule.createSuspension(startWeek: 1, endWeek: 2, startDayOfWeek: 1, endDayOfWeek: 5);
      expect(rSusp2.getLocalizedDescription(ctx), isNotEmpty);

      // Custom course
      final course = CourseModel(
        id: 'c2', name: '体育', teacher: '王老师', classroom: '操场',
        dayOfWeek: 4, startPeriod: 1, endPeriod: 2, periods: '1-2节', weeks: '1-16周',
      );
      final rAdd = TimetableRule.createCustomCourse(course: course);
      expect(rAdd.getLocalizedDescription(ctx), contains('体育'));
    });
  });

  group('DateCalculator Tests', () {
    test('calculateDate handles Mondays and non-Monday offsets', () {
      final monday = DateTime(2026, 9, 7); // Monday
      // Week 1, Monday
      final d1 = DateCalculator.calculateDate(firstWeekMonday: monday, weekNumber: 1, dayOfWeek: 1);
      expect(d1.year, 2026);
      expect(d1.month, 9);
      expect(d1.day, 7);

      // Week 1, Sunday (dayOfWeek 7)
      final d7 = DateCalculator.calculateDate(firstWeekMonday: monday, weekNumber: 1, dayOfWeek: 7);
      expect(d7.day, 13);

      // Week 2, Wednesday (dayOfWeek 3)
      final w2d3 = DateCalculator.calculateDate(firstWeekMonday: monday, weekNumber: 2, dayOfWeek: 3);
      expect(w2d3.day, 16);

      // If user passed a Wednesday as firstWeekMonday, it normalizes to Monday
      final wednesday = DateTime(2026, 9, 9);
      final normalized = DateCalculator.calculateDate(firstWeekMonday: wednesday, weekNumber: 1, dayOfWeek: 1);
      expect(normalized.day, 7);
    });

    test('getSectionTime and getBigSectionTimeRange', () {
      // All 12 sections have valid start/end times
      for (int i = 1; i <= 12; i++) {
        final time = DateCalculator.getSectionTime(i);
        expect(time['start'], isNotNull);
        expect(time['end'], isNotNull);
        expect(time['start']!.hour, greaterThan(0));
      }

      // Out of range section returns 0:00
      final invalid = DateCalculator.getSectionTime(99);
      expect(invalid['start']!.hour, 0);

      // Big section ranges 1..6
      expect(DateCalculator.getBigSectionTimeRange(1), '08:00-09:40');
      expect(DateCalculator.getBigSectionTimeRange(2), '10:05-11:45');
      expect(DateCalculator.getBigSectionTimeRange(3), '14:30-16:10');
      expect(DateCalculator.getBigSectionTimeRange(4), '16:35-18:15');
      expect(DateCalculator.getBigSectionTimeRange(5), '19:30-21:10');
      expect(DateCalculator.getBigSectionTimeRange(6), '21:20-23:00');
      expect(DateCalculator.getBigSectionTimeRange(7), '');
    });

    test('calculateDurationMinutes calculates section span correctly', () {
      // Section 1-2: 08:00 to 09:40 = 100 minutes
      expect(DateCalculator.calculateDurationMinutes(1, 2), 100);

      // Handles reversed argument order
      expect(DateCalculator.calculateDurationMinutes(2, 1), 100);
    });

    test('getCurrentWeekNumber, getWeekMonday, getWeekSunday, formatDateRange', () {
      final monday = DateTime(2026, 9, 7);

      // Before semester
      final before = DateTime(2026, 9, 1);
      expect(DateCalculator.getCurrentWeekNumber(monday, before), 0);

      // Week 1
      final week1 = DateTime(2026, 9, 10);
      expect(DateCalculator.getCurrentWeekNumber(monday, week1), 1);

      // Week 3
      final week3 = DateTime(2026, 9, 23);
      expect(DateCalculator.getCurrentWeekNumber(monday, week3), 3);

      // Week monday and sunday
      final w2Mon = DateCalculator.getWeekMonday(monday, 2);
      expect(w2Mon.day, 14);

      final w2Sun = DateCalculator.getWeekSunday(monday, 2);
      expect(w2Sun.day, 20);

      // formatDateRange
      expect(DateCalculator.formatDateRange(w2Mon, w2Sun), '9月14日-9月20日');
    });
  });
}
