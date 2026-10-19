import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/timetable/utils/course_color_utils.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CourseColorUtils.resetForTesting();
  });

  group('CourseColorUtils 700 Palette Specification', () {
    test('Contains exactly 19 colors and all are shade 700', () {
      expect(CourseColorUtils.materialColorItems.length, equals(19));
      expect(CourseColorUtils.selectablePalette.length, equals(19));
      expect(CourseColorUtils.defaultPaletteOrder.length, equals(19));

      for (final item in CourseColorUtils.materialColorItems) {
        expect(item.shade, equals('700'));
      }
    });

    test('Contains the exact 19 Material UI color families', () {
      const expectedFamilies = {
        'Red',
        'Pink',
        'Purple',
        'Deep Purple',
        'Indigo',
        'Blue',
        'Light Blue',
        'Cyan',
        'Teal',
        'Green',
        'Light Green',
        'Lime',
        'Yellow',
        'Amber',
        'Orange',
        'Deep Orange',
        'Brown',
        'Grey',
        'Blue Grey',
      };

      final actualFamilies =
          CourseColorUtils.materialColorItems.map((item) => item.family).toSet();
      expect(actualFamilies, equals(expectedFamilies));
    });

    test('All 19 palette colors are distinct', () {
      final colorValues = CourseColorUtils.selectablePalette
          .map((c) => c.toARGB32())
          .toSet();
      expect(colorValues.length, equals(19));
    });
  });

  group('CourseColorUtils Uniqueness Guarantee', () {
    test('Sequential calls to getColorForCourse guarantee all unique colors for 19 courses', () {
      final courseNames = List.generate(19, (i) => '课程$i');
      final colors =
          courseNames.map((name) => CourseColorUtils.getColorForCourse(name)).toList();
      final colorValues = colors.map((c) => c.toARGB32()).toSet();
      expect(colorValues.length, equals(19));
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

    test('setCourseColor throws when color is outside 19 700-shade palette', () async {
      expect(
        () => CourseColorUtils.setCourseColor('课程A', const Color(0xFFFFFFFF)),
        throwsArgumentError,
      );
    });
  });
}
