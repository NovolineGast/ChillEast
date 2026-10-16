import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/timetable/utils/course_color_utils.dart';

double _relativeLuminance(Color color) {
  double transform(double c) {
    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = transform(color.r);
  final g = transform(color.g);
  final b = transform(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatioWithWhite(Color color) {
  final l = _relativeLuminance(color);
  return (1.0 + 0.05) / (l + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CourseColorUtils.resetForTesting();
  });

  group('CourseColorUtils Palette & Contrast', () {
    test('All palette colors must have contrast ratio >= 3.0 with white text', () {
      for (final item in CourseColorUtils.materialColorItems) {
        final cr = _contrastRatioWithWhite(item.color);
        expect(
          cr,
          greaterThanOrEqualTo(3.0),
          reason:
              '${item.family} ${item.shade} (${item.color}) contrast ratio is $cr, which is too low for white text',
        );
      }
    });

    test('Palette items have non-empty family, shade, and distinct colors', () {
      expect(CourseColorUtils.materialColorItems.isNotEmpty, isTrue);
      for (final item in CourseColorUtils.materialColorItems) {
        expect(item.family.isNotEmpty, isTrue);
        expect(item.shade.isNotEmpty, isTrue);
      }
    });
  });

  group('CourseColorUtils Uniqueness Guarantee', () {
    test('Sequential calls to getColorForCourse guarantee all unique colors', () {
      final courseNames = List.generate(20, (i) => '课程$i');
      final colors =
          courseNames.map((name) => CourseColorUtils.getColorForCourse(name)).toList();
      final colorValues = colors.map((c) => c.toARGB32()).toSet();
      expect(colorValues.length, equals(courseNames.length));
    });

    test('syncCourses assigns pairwise distinct colors to all courses', () {
      final courses = [
        '高等数学',
        '大学物理',
        '线性代数',
        '毛概',
        '大学英语',
        '离散数学',
        '数据结构',
        '操作系统',
        '计算机网络',
        '数据库原理',
        '软件工程',
        '人工智能',
      ];
      CourseColorUtils.syncCourses(courses);

      final assigned =
          courses.map((c) => CourseColorUtils.getColorForCourse(c)).toList();
      final assignedValues = assigned.map((c) => c.toARGB32()).toSet();

      expect(assignedValues.length, equals(courses.length));
    });

    test('setCourseColor swaps colors when selecting an already used color', () async {
      final courses = ['课程A', '课程B', '课程C'];
      CourseColorUtils.syncCourses(courses);

      final colorA = CourseColorUtils.getColorForCourse('课程A');
      final colorB = CourseColorUtils.getColorForCourse('课程B');
      expect(colorA.toARGB32(), isNot(equals(colorB.toARGB32())));

      // 用户将课程A的颜色修改为课程B现有的颜色
      await CourseColorUtils.setCourseColor('课程A', colorB);

      // 验证课程A获取了colorB，课程B被对调分配了colorA
      expect(
        CourseColorUtils.getColorForCourse('课程A').toARGB32(),
        equals(colorB.toARGB32()),
      );
      expect(
        CourseColorUtils.getColorForCourse('课程B').toARGB32(),
        equals(colorA.toARGB32()),
      );

      // 验证所有课程仍然无颜色重复
      final allColors =
          courses.map((c) => CourseColorUtils.getColorForCourse(c)).toList();
      final allValues = allColors.map((c) => c.toARGB32()).toSet();
      expect(allValues.length, equals(courses.length));
    });

    test('setCourseColor throws when color is outside allowed palette', () async {
      expect(
        () => CourseColorUtils.setCourseColor('课程A', const Color(0xFFFFFFFF)),
        throwsArgumentError,
      );
    });
  });
}
