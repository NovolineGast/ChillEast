import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/mcp/tools/exam_tool.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/services/exam_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamQueryTool MCP Tests', () {
    late Directory tempDir;
    late ExamStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('mcp_exam_test_');
      storage = ExamStorage(baseDirectory: tempDir);

      // 准备测试数据：一场本学期秋季考试，一场下学期春季考试（均在今天及之后，可正常储存）
      final autumnExam = ExamScheduleModel(
        id: '10762596',
        title: '2026年11月10日期中考试题',
        courseName: '高数',
        time: DateTime(2026, 11, 10, 19, 0),
        status: '已完成',
      );
      final springExam = ExamScheduleModel(
        id: '9473825',
        title: '27年春形策期末考试',
        courseName: '形势与政策',
        time: DateTime(2027, 3, 10, 17, 0),
        status: '未交',
      );

      await storage.saveExamList([autumnExam, springExam]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('query_exams default filters to current semester only', () async {
      final tool = ExamQueryTool.create(storage: storage);
      expect(tool.name, equals('query_exams'));

      final result = await tool.handler({});
      expect(result.isError, isFalse);

      final data = jsonDecode(result.content.first.text!) as Map<String, dynamic>;
      expect(data['currentSemesterOnly'], isTrue);
      final exams = data['exams'] as List<dynamic>;

      // 当前系统时间为 2026 年秋季学期，只应包含本学期秋季的考试
      expect(exams.length, equals(1));
      expect(exams[0]['title'], equals('2026年11月10日期中考试题'));
      expect(exams[0]['time'], equals('2026-11-10 19:00'));
    });

    test('query_exams with currentSemesterOnly=false returns all exams', () async {
      final tool = ExamQueryTool.create(storage: storage);

      final result = await tool.handler({'currentSemesterOnly': false});
      expect(result.isError, isFalse);

      final data = jsonDecode(result.content.first.text!) as Map<String, dynamic>;
      final exams = data['exams'] as List<dynamic>;
      expect(exams.length, equals(2));
    });

    test('query_exams keyword search filters correctly', () async {
      final tool = ExamQueryTool.create(storage: storage);

      final result = await tool.handler({
        'currentSemesterOnly': false,
        'keyword': '形策',
      });
      expect(result.isError, isFalse);

      final data = jsonDecode(result.content.first.text!) as Map<String, dynamic>;
      final exams = data['exams'] as List<dynamic>;
      expect(exams.length, equals(1));
      expect(exams[0]['title'], contains('形策'));
    });

    test('query_exam_schedule alias is supported', () {
      final aliasTool = ExamQueryTool.create(
        storage: storage,
        toolName: 'query_exam_schedule',
      );
      expect(aliasTool.name, equals('query_exam_schedule'));
    });
  });

  group('ExamAddTool MCP Tests', () {
    late Directory tempDir;
    late ExamStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('mcp_exam_add_test_');
      storage = ExamStorage(baseDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('add_exam successfully adds exam and triggers onChanged', () async {
      bool changed = false;
      final tool = ExamAddTool.create(
        storage: storage,
        onChanged: () async {
          changed = true;
        },
      );

      expect(tool.name, equals('add_exam'));

      final result = await tool.handler({
        'title': '大学物理下期末考试',
        'courseName': '大学物理',
        'time': '2026-11-25 09:00:00',
        'location': '理学楼301',
        'remarks': '带计算器',
      });

      expect(result.isError, isFalse);
      expect(changed, isTrue);

      final data = jsonDecode(result.content.first.text!) as Map<String, dynamic>;
      expect(data['summary'], contains('大学物理下期末考试'));
      expect(data['exam']['location'], equals('理学楼301'));
      expect(data['exam']['remarks'], equals('带计算器'));

      final exams = await storage.readExamList();
      expect(exams.length, equals(1));
      expect(exams.first.title, equals('大学物理下期末考试'));
      expect(exams.first.isManual, isTrue);
      expect(exams.first.location, equals('理学楼301'));
      expect(exams.first.remarks, equals('带计算器'));
    });

    test('add_exam validates required arguments', () async {
      final tool = ExamAddTool.create(storage: storage);

      final noTitle = await tool.handler({'time': '2026-11-25 09:00:00'});
      expect(noTitle.isError, isTrue);

      final noTime = await tool.handler({'title': '大学物理'});
      expect(noTime.isError, isTrue);

      final invalidTime = await tool.handler({
        'title': '大学物理',
        'time': 'not_a_date',
      });
      expect(invalidTime.isError, isTrue);
    });

    test('add_exam_schedule alias is supported', () {
      final aliasTool = ExamAddTool.create(
        storage: storage,
        toolName: 'add_exam_schedule',
      );
      expect(aliasTool.name, equals('add_exam_schedule'));
    });
  });
}
