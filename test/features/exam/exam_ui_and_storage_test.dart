import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/providers/exam_provider.dart';
import 'package:ChillEast/features/exam/services/exam_storage.dart';
import 'package:ChillEast/features/exam/screens/exam_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamStorage & Provider Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('exam_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ExamStorage persists and restores exam list correctly', () async {
      final storage = ExamStorage(baseDirectory: tempDir);
      final exams = [
        ExamScheduleModel(
          id: '10762596',
          title: '2026年9月10日补考试题',
          time: DateTime(2026, 9, 10, 19, 0),
          allTimes: [
            DateTime(2026, 9, 10, 19, 0),
            DateTime(2026, 9, 10, 19, 30),
          ],
          rawTimeStrs: ['2026-09-10 19:00', '2026-09-10 19:30'],
          status: '已完成',
        ),
      ];

      await storage.saveExamList(exams);
      final loaded = await storage.readExamList();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('10762596'));
      expect(loaded.first.title, equals('2026年9月10日补考试题'));
      // 时间显示为第一个出现的时间
      expect(loaded.first.time, equals(DateTime(2026, 9, 10, 19, 0)));

      // 验证过期 ID 集合存储
      await storage.saveExpiredExamIds({'10762596', '9473825'});
      final expired = await storage.readExpiredExamIds();
      expect(expired, contains('10762596'));
      expect(expired, contains('9473825'));

      // 验证删除
      await storage.deleteExamList();
      final afterDelete = await storage.readExamList();
      expect(afterDelete, isEmpty);
    });

    test('ExamScheduleModel supports manual exams, location and remarks', () async {
      final storage = ExamStorage(baseDirectory: tempDir);
      final exam = ExamScheduleModel(
        id: 'manual_123456',
        title: '大学英语期末口语考试',
        courseName: '大学英语',
        time: DateTime(2026, 11, 20, 14, 30),
        status: '待考',
        isManual: true,
        location: '文科楼402',
        remarks: '自带准考证和学生证',
      );

      await storage.saveExamList([exam]);
      final loaded = await storage.readExamList();
      expect(loaded.length, equals(1));
      expect(loaded.first.isManual, isTrue);
      expect(loaded.first.location, equals('文科楼402'));
      expect(loaded.first.remarks, equals('自带准考证和学生证'));
      expect(loaded.first.courseName, equals('大学英语'));
    });

    testWidgets('Renders upcoming exam card with first occurrence time', (tester) async {
      final mockExam = ExamScheduleModel(
        id: '9473825',
        title: '26年春形策期末考试',
        time: DateTime(2026, 5, 10, 17, 0),
        allTimes: [
          DateTime(2026, 5, 10, 17, 0),
          DateTime(2026, 5, 10, 23, 59),
        ],
        rawTimeStrs: ['2026-05-10 17:00', '2026-05-10 23:59'],
        status: '未交',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            examProvider.overrideWith((ref) => _MockExamNotifier(ref, [mockExam])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final timeStr = DateFormat('HH:mm').format(mockExam.time);
                  return Column(
                    children: [
                      Text(mockExam.title),
                      Text('考试时间: $timeStr'),
                      Text(mockExam.status),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('26年春形策期末考试'), findsOneWidget);
      expect(find.text('考试时间: 17:00'), findsOneWidget);
      expect(find.text('未交'), findsOneWidget);
    });

    testWidgets('ExamScreen renders AppBar with plus button and shows exam cards', (tester) async {
      final mockExam = ExamScheduleModel(
        id: 'manual_999',
        title: '编译原理期末考',
        courseName: '编译原理',
        time: DateTime.now().add(const Duration(days: 3)),
        status: '待考',
        isManual: true,
        location: '计算机楼B201',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            examProvider.overrideWith((ref) => _MockExamNotifier(ref, [mockExam])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: ExamScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证标题与加号按钮
      expect(find.text('考试安排'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // 验证考试卡片内容
      expect(find.text('编译原理'), findsOneWidget);
      expect(find.text('编译原理期末考'), findsOneWidget);
      expect(find.text('计算机楼B201'), findsOneWidget);
      expect(find.text('手动添加'), findsOneWidget);
      expect(find.text('待考'), findsOneWidget);

      // 点击加号打开添加考试弹窗
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('添加考试'), findsOneWidget);
      expect(find.text('考试名称'), findsOneWidget);
      expect(find.text('所属课程'), findsOneWidget);
    });
  });
}

class _MockExamNotifier extends ExamNotifier {
  _MockExamNotifier(super.ref, List<ExamScheduleModel> initial) {
    state = AsyncValue.data(initial);
  }
}
