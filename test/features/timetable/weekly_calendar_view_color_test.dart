import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/utils/course_color_utils.dart';
import 'package:ChillEast/features/timetable/widgets/weekly_calendar_view.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CourseColorUtils.resetForTesting();
  });

  Widget buildTestWidget({
    required List<CourseModel> courses,
    bool showEndTime = false,
    VoidCallback? onColorChanged,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WeeklyCalendarView(
          courses: courses,
          firstWeekMonday:
              DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
          showEndTime: showEndTime,
          onCourseColorChanged: onColorChanged,
        ),
      ),
    );
  }

  testWidgets('Tap course opens detail dialog with course color and allows color picking',
      (tester) async {
    const testCourse = CourseModel(
      id: '1',
      name: '高等数学',
      teacher: '张老师',
      classroom: '理科楼101',
      weeks: '1-16',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    );

    bool callbackTriggered = false;

    await tester.pumpWidget(buildTestWidget(
      courses: [testCourse],
      onColorChanged: () {
        callbackTriggered = true;
      },
    ));
    await tester.pumpAndSettle();

    // Verify course name is shown on grid
    expect(find.text('高等数学'), findsWidgets);

    // Tap the course card
    await tester.tap(find.text('高等数学').first);
    await tester.pumpAndSettle();

    // Verify detail dialog is shown
    expect(find.text('教师:'), findsOneWidget);
    expect(find.text('张老师'), findsOneWidget);
    expect(find.text('修改颜色'), findsOneWidget);

    // Tap "修改颜色" to open Material UI color picker
    await tester.tap(find.text('修改颜色'));
    await tester.pumpAndSettle();

    // Verify color picker dialog is opened
    expect(find.text('选择课程颜色'), findsOneWidget);

    // Pick an visible color swatch (e.g. Red 600 or Red 700)
    final targetItem = CourseColorUtils.materialColorItems.firstWhere(
      (item) => item.color.toARGB32() != CourseColorUtils.getColorForCourse('高等数学').toARGB32(),
    );
    final colorTooltipFinder =
        find.byTooltip('${targetItem.family} ${targetItem.shade}');
    expect(colorTooltipFinder, findsOneWidget);

    await tester.tap(colorTooltipFinder);
    await tester.pumpAndSettle();

    // Verify color picker dialog has closed
    expect(find.text('选择课程颜色'), findsNothing);

    // Verify callback was triggered
    expect(callbackTriggered, isTrue);

    // Verify course color was updated
    expect(
      CourseColorUtils.getColorForCourse('高等数学').toARGB32(),
      equals(targetItem.color.toARGB32()),
    );

    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Overlapping courses show conflict icon at bottom right',
      (tester) async {
    const course1 = CourseModel(
      id: '1',
      name: '物理实验',
      teacher: '李老师',
      classroom: '实训楼201',
      weeks: '1-16',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    );
    const course2 = CourseModel(
      id: '2',
      name: '思想道德',
      teacher: '王老师',
      classroom: '公教楼302',
      weeks: '1-16',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    );

    await tester.pumpWidget(buildTestWidget(courses: [course1, course2]));
    await tester.pumpAndSettle();

    // Conflict layer icon
    final iconFinder = find.byIcon(Icons.layers_rounded);
    expect(iconFinder, findsWidgets);

    // Verify Positioned widget wrapping the icon has bottom == 0 and right == 0
    final positionedFinder = find.ancestor(
      of: iconFinder.first,
      matching: find.byWidgetPredicate(
        (w) => w is Positioned && w.child is Icon,
      ),
    );
    final Positioned positioned = tester.widget(positionedFinder.first);
    expect(positioned.bottom, equals(0));
    expect(positioned.right, equals(0));
    expect(positioned.top, isNull);
  });

  testWidgets('WeeklyCalendarView respects showEndTime setting', (tester) async {
    const testCourse = CourseModel(
      id: '1',
      name: '高等数学',
      teacher: '张老师',
      classroom: '理科楼101',
      weeks: '1-16',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    );

    // 默认 showEndTime: false，只显示上课时间，不显示下课时间
    await tester.pumpWidget(buildTestWidget(courses: [testCourse], showEndTime: false));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:40'), findsNothing);

    // showEndTime: true 时，同时显示下课时间
    await tester.pumpWidget(buildTestWidget(courses: [testCourse], showEndTime: true));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:40'), findsOneWidget);
  });
}
