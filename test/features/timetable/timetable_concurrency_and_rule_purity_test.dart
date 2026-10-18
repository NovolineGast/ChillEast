import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_rule_service.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';
import 'package:ChillEast/features/timetable/services/ydjwxt_service.dart';

class InMemoryTimetableStorage extends TimetableStorage {
  List<CourseModel> rawList = [];
  List<CourseModel> courseList = [];
  List<TimetableRule> ruleList = [];
  String? ics;
  int saveRawCallCount = 0;

  @override
  Future<bool> hasRawCourseList() async => rawList.isNotEmpty;

  @override
  Future<List<CourseModel>> readRawCourseList() async => List.from(rawList);

  @override
  Future<void> saveRawCourseList(List<CourseModel> courses) async {
    saveRawCallCount++;
    rawList = List.from(courses);
  }

  @override
  Future<List<CourseModel>> readCourseList() async => List.from(courseList);

  @override
  Future<void> saveCourseList(List<CourseModel> courses) async {
    courseList = List.from(courses);
  }

  @override
  Future<List<TimetableRule>> readRules() async => List.from(ruleList);

  @override
  Future<void> saveRules(List<TimetableRule> rules) async {
    ruleList = List.from(rules);
  }

  @override
  Future<void> deleteRules() async {
    ruleList.clear();
  }

  @override
  Future<String?> readTimetable() async => ics;

  @override
  Future<void> saveTimetable(String content) async {
    ics = content;
  }

  @override
  Future<Map<String, dynamic>?> readMetadata() async => {
        'semester': '2026-2027-1',
        'firstWeekMonday': '2026-09-01T00:00:00.000',
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #30: TimetableRuleService raw cleanliness & anti-pollution', () {
    late InMemoryTimetableStorage storage;
    late TimetableRuleService ruleService;

    setUp(() {
      storage = InMemoryTimetableStorage();
      ruleService = TimetableRuleService(storage: storage);
    });

    test('customCourse in rule is marked with isCustom = true and does NOT pollute raw', () async {
      // 1. 设置原始课程 rawCourses
      const rawCourse = CourseModel(
        id: 'raw_1',
        name: '大学物理',
        teacher: '李老师',
        classroom: '一教101',
        weeks: '1-16(周)',
        periods: '01-02',
        dayOfWeek: 1,
        startPeriod: 1,
        endPeriod: 2,
        isCustom: false,
      );
      storage.rawList = [rawCourse];

      // 2. 添加一条自定义加课规则
      const customCourse = CourseModel(
        id: 'custom_99',
        name: '考研自习',
        teacher: '自己',
        classroom: '图书馆自习室',
        weeks: '1-16(周)',
        periods: '07-08',
        dayOfWeek: 2,
        startPeriod: 7,
        endPeriod: 8,
        isCustom: true,
      );
      final rule = TimetableRule.createCustomCourse(course: customCourse);
      await ruleService.addRule(rule);

      // 3. 验证应用规则后生成的课程包含该自定义课程，且 isCustom 为 true
      final courses = storage.courseList;
      expect(courses.any((c) => c.name == '考研自习' && c.isCustom), isTrue);

      // 4. 关键：rawList 绝对未被自定义课程污染！
      expect(storage.rawList.length, equals(1));
      expect(storage.rawList.first.name, equals('大学物理'));
      expect(storage.rawList.any((c) => c.isCustom), isFalse);
      expect(storage.saveRawCallCount, equals(0), reason: 'raw 基准绝不允许被重新覆盖保存');

      // 5. 清空规则后，课表恢复为纯净的教务 raw 课程，自定义课程完全消失
      await ruleService.clearAllRules();
      expect(storage.courseList.length, equals(1));
      expect(storage.courseList.first.name, equals('大学物理'));
      expect(storage.courseList.any((c) => c.name == '考研自习'), isFalse);
    });

    test('applyRulesAndRegenerate defense: sanitizes polluted raw courses with isCustom', () async {
      // 假定外部极端异常导致 raw 中渗入了 isCustom 的课程
      const rawCourse = CourseModel(
        id: 'raw_1',
        name: '毛概',
        teacher: '张老师',
        classroom: '二教201',
        weeks: '1-16(周)',
        periods: '03-04',
        dayOfWeek: 3,
        startPeriod: 3,
        endPeriod: 4,
        isCustom: false,
      );
      const pollutedCourse = CourseModel(
        id: 'polluted_custom',
        name: '非法注入自定义课程',
        teacher: '未知',
        classroom: '未知',
        weeks: '1-16(周)',
        periods: '01-02',
        dayOfWeek: 1,
        startPeriod: 1,
        endPeriod: 2,
        isCustom: true,
      );
      storage.rawList = [rawCourse, pollutedCourse];

      // 执行重新应用与生成
      final regenerated = await ruleService.applyRulesAndRegenerate();

      // 验证自愈防御：输出的课程列表中绝不包含非法渗入的自定义课程
      expect(regenerated.any((c) => c.name == '非法注入自定义课程'), isFalse);
      expect(regenerated.length, equals(1));
      expect(regenerated.first.name, equals('毛概'));
    });

    test('refuses to persist legacy courses containing custom courses as raw baseline', () async {
      // 本地无 rawList，但旧 courses.json 包含自定义课程，且有现存规则
      storage.rawList = [];
      storage.ruleList = [
        TimetableRule.createCustomCourse(
          course: const CourseModel(
            id: 'c_custom',
            name: '我的活动',
            teacher: '',
            classroom: '',
            weeks: '1-10(周)',
            periods: '01-02',
            dayOfWeek: 4,
            startPeriod: 1,
            endPeriod: 2,
            isCustom: true,
          ),
        ),
      ];
      storage.courseList = [
        const CourseModel(
          id: 'c_custom',
          name: '我的活动',
          teacher: '',
          classroom: '',
          weeks: '1-10(周)',
          periods: '01-02',
          dayOfWeek: 4,
          startPeriod: 1,
          endPeriod: 2,
          isCustom: true,
        ),
      ];

      await ruleService.applyRulesAndRegenerate();

      // 绝不能把带有自定义课程的旧 courses 固化为 raw 基准
      expect(storage.saveRawCallCount, equals(0));
      expect(storage.rawList, isEmpty);
    });
  });

  group('Issue #29: YdjwxtService sync mutex single-flight', () {
    test('concurrent syncTimetable calls join the same in-flight task without starting duplicates', () async {
      final service = YdjwxtService();

      // 在未配置实际网络凭证时，两个并发调用应该加入同一个 Future 并抛出相同的无 token 异常
      final progress1 = <String>[];
      final progress2 = <String>[];

      final future1 = service.syncTimetable(
        onProgress: (p) => progress1.add(p),
      );
      final future2 = service.syncTimetable(
        onProgress: (p) => progress2.add(p),
      );

      // future2 应复用在途任务，其进度回调应收到“已在进行中”
      expect(progress2, contains('课表同步已在进行中...'));

      // 两者都将安全结束（抛出未登录/Token为空异常）
      expect(future1, throwsA(anything));
      expect(future2, throwsA(anything));
    });
  });
}
