import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/homework/providers/homework_provider.dart';
import 'package:ChillEast/features/homework/services/homework_service.dart';
import 'package:ChillEast/features/homework/services/homework_storage.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/providers/exam_provider.dart';
import 'package:ChillEast/features/exam/services/exam_service.dart';
import 'package:ChillEast/features/exam/services/exam_storage.dart';
import 'package:ChillEast/core/state/auth_state.dart';

class DelayedMockHomeworkService extends HomeworkService {
  final Completer<List<HomeworkModel>> completer = Completer<List<HomeworkModel>>();

  @override
  Future<List<HomeworkModel>> fetchHomeworkList(String studentId) {
    return completer.future;
  }
}

class FakeHomeworkStorage extends HomeworkStorage {
  List<HomeworkModel> items = [];

  @override
  Future<List<HomeworkModel>> readHomeworkList() async => List.from(items);

  @override
  Future<void> saveHomeworkList(List<HomeworkModel> list) async {
    items = List.from(list);
  }
}

class DelayedMockExamService extends ExamService {
  final Completer<List<ExamScheduleModel>> completer = Completer<List<ExamScheduleModel>>();

  @override
  Future<List<ExamScheduleModel>> fetchExams({
    List<ExamScheduleModel>? cachedExams,
    Dio? dioClient,
  }) {
    return completer.future;
  }
}

class FakeExamStorage extends ExamStorage {
  List<ExamScheduleModel> items = [];

  @override
  Future<List<ExamScheduleModel>> readExamList() async => List.from(items);

  @override
  Future<void> saveExamList(List<ExamScheduleModel> list) async {
    items = List.from(list);
  }

  @override
  Future<Set<String>> readExpiredExamIds() async => {};
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(super.ref) {
    state = const AuthState.authenticated(username: 'test_student');
  }

  @override
  Future<void> checkAuthStatus() async {
    state = const AuthState.authenticated(username: 'test_student');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '/tmp');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async => null);
  });

  group('Issue #27: Homework & Exam concurrent refresh anti-overwrite', () {
    test('HomeworkNotifier preserves manual homework created while network fetch is in-flight', () async {
      final mockService = DelayedMockHomeworkService();
      final fakeStorage = FakeHomeworkStorage();

      // 初始存在一条手动作业 H1
      final manual1 = HomeworkModel(
        id: 'manual_1',
        title: '初始手动作业',
        courseName: '操作系统',
        status: HomeworkStatus.pending,
        studentId: 'test_student',
        isManual: true,
      );
      fakeStorage.items = [manual1];

      final container = ProviderContainer(
        overrides: [
          homeworkServiceProvider.overrideWithValue(mockService),
          homeworkStorageProvider.overrideWithValue(fakeStorage),
          authStateProvider.overrideWith((ref) => FakeAuthNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(homeworkProvider.notifier);
      await container.pump();

      // 启动网络刷新（网络请求挂起）
      final refreshFuture = notifier.refresh('test_student');

      // 模拟在网络请求途中，用户在本地新增了一条手动作业
      await notifier.addManualHomework(
        title: '网飞途中新增的手动作业',
        courseName: '计算机网络',
      );

      // 现在网络请求返回爬取作业 S1
      final scraped1 = HomeworkModel(
        id: 'scraped_1',
        title: '教务系统作业',
        courseName: '数据库',
        status: HomeworkStatus.pending,
        studentId: 'test_student',
        isManual: false,
      );
      mockService.completer.complete([scraped1]);

      await refreshFuture;

      final result = container.read(homeworkProvider).value;
      expect(result, isNotNull);
      final titles = result!.map((h) => h.title).toList();

      // 验证：初始 H1、网络中途新增的手动作业以及爬取的 S1 均必须存在，新加手动作业绝未被旧快照覆盖！
      expect(titles, contains('初始手动作业'));
      expect(titles, contains('网飞途中新增的手动作业'));
      expect(titles, contains('教务系统作业'));
      expect(fakeStorage.items.map((h) => h.title), contains('网飞途中新增的手动作业'));
    });

    test('ExamNotifier preserves manual exam created while network fetch is in-flight', () async {
      final mockService = DelayedMockExamService();
      final fakeStorage = FakeExamStorage();

      final initialExam = ExamScheduleModel(
        id: 'manual_e1',
        title: '初始手动考试',
        courseName: '编译原理',
        time: DateTime.now().add(const Duration(days: 5)),
        isManual: true,
      );
      fakeStorage.items = [initialExam];

      final container = ProviderContainer(
        overrides: [
          examServiceProvider.overrideWithValue(mockService),
          examStorageProvider.overrideWithValue(fakeStorage),
          authStateProvider.overrideWith((ref) => FakeAuthNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(examProvider.notifier);
      await container.pump();

      final refreshFuture = notifier.refresh();

      // 模拟在网络爬取挂起时，用户添加了一门新考试
      await notifier.addManualExam(
        title: '并发新增的手动考试',
        courseName: '软件工程',
        time: DateTime.now().add(const Duration(days: 7)),
      );

      // 网络返回爬取考试
      final scrapedExam = ExamScheduleModel(
        id: 'scraped_e1',
        title: '教务期末考',
        courseName: '算法设计',
        time: DateTime.now().add(const Duration(days: 10)),
        isManual: false,
      );
      mockService.completer.complete([scrapedExam]);

      await refreshFuture;

      final result = container.read(examProvider).value;
      expect(result, isNotNull);
      final titles = result!.map((e) => e.title).toList();

      expect(titles, contains('初始手动考试'));
      expect(titles, contains('并发新增的手动考试'));
      expect(titles, contains('教务期末考'));
      expect(fakeStorage.items.map((e) => e.title), contains('并发新增的手动考试'));
    });
  });
}
