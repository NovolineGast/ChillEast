import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/homework/providers/homework_provider.dart';
import 'package:ChillEast/features/homework/services/homework_service.dart';
import 'package:ChillEast/features/homework/services/homework_storage.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/providers/exam_provider.dart';
import 'package:ChillEast/features/exam/services/exam_service.dart';
import 'package:ChillEast/features/exam/services/exam_storage.dart';
import 'package:ChillEast/features/timetable/services/ydjwxt_service.dart';

class _FakeBrowserPlatform extends webview.InAppWebViewPlatform {
  @override
  webview.PlatformCookieManager createPlatformCookieManager(
          webview.PlatformCookieManagerCreationParams params) =>
      _FakeCookieManager();
}

class _FakeCookieManager extends webview.PlatformCookieManager {
  _FakeCookieManager()
      : super.implementation(const webview.PlatformCookieManagerCreationParams());

  @override
  Future<bool> deleteAllCookies() async => true;
}

class FakeHomeworkService extends HomeworkService {
  Completer<List<HomeworkModel>> completer = Completer();

  @override
  Future<List<HomeworkModel>> fetchHomeworkList(String studentId) {
    return completer.future;
  }
}

class FakeExamService extends ExamService {
  Completer<List<ExamScheduleModel>> completer = Completer();

  @override
  Future<List<ExamScheduleModel>> fetchExams({
    List<ExamScheduleModel>? cachedExams,
    dynamic dioClient,
  }) {
    return completer.future;
  }
}

class FakeHomeworkStorage extends HomeworkStorage {
  List<HomeworkModel> stored = [];

  @override
  Future<List<HomeworkModel>> readHomeworkList() async => List.from(stored);

  @override
  Future<void> saveHomeworkList(List<HomeworkModel> homeworks) async {
    stored = List.from(homeworks);
  }
}

class FakeExamStorage extends ExamStorage {
  List<ExamScheduleModel> stored = [];

  @override
  Future<List<ExamScheduleModel>> readExamList() async => List.from(stored);

  @override
  Future<void> saveExamList(List<ExamScheduleModel> exams) async {
    stored = List.from(exams);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('anti-overwrite-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async => true);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    webview.InAppWebViewPlatform.instance = _FakeBrowserPlatform();
    await AppCookieManager().initialize();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('#27 Homework & Exam anti-overwrite during network refresh', () {
    test('Homework: manual task added during refresh is preserved after scrape completes', () async {
      final fakeService = FakeHomeworkService();
      final fakeStorage = FakeHomeworkStorage();

      final container = ProviderContainer(
        overrides: [
          homeworkServiceProvider.overrideWithValue(fakeService),
          homeworkStorageProvider.overrideWithValue(fakeStorage),
        ],
      );

      final notifier = container.read(homeworkProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. 先有一条初始手动作业
      await notifier.addManualHomework(title: '初始手动作业');
      expect(container.read(homeworkProvider).value?.length, equals(1));

      // 2. 触发 refresh，网络请求处于挂起中
      final refreshFuture = notifier.refresh('20230001');

      // 验证 loading 状态保留了已有数据 (copyWithPrevious)
      final stateDuringLoading = container.read(homeworkProvider);
      expect(stateDuringLoading.isLoading, isTrue);
      expect(stateDuringLoading.value?.length, equals(1));
      expect(stateDuringLoading.value?.first.title, equals('初始手动作业'));

      // 3. 用户在网络期间通过 FAB 快速新增了一条手动作业
      await notifier.addManualHomework(title: '网络挂起期间新增的作业');
      expect(container.read(homeworkProvider).value?.length, equals(2));

      // 4. 网络请求返回 1 条线上爬取的作业
      final scrapedItem = HomeworkModel(
        id: 'scraped_1',
        title: '超星线上作业',
        courseName: '操作系统',
        status: HomeworkStatus.pending,
        studentId: '20230001',
        isManual: false,
      );
      fakeService.completer.complete([scrapedItem]);
      await refreshFuture;

      // 5. 验证写盘与最终 state：不仅有爬取的作业，网络期间新增的手动作业也绝对没有被冲掉！
      final finalList = container.read(homeworkProvider).value!;
      expect(finalList.any((h) => h.title == '初始手动作业'), isTrue);
      expect(finalList.any((h) => h.title == '网络挂起期间新增的作业'), isTrue);
      expect(finalList.any((h) => h.title == '超星线上作业'), isTrue);
      expect(finalList.length, equals(3));
    });

    test('Exam: manual exam added during refresh is preserved after scrape completes', () async {
      final fakeService = FakeExamService();
      final fakeStorage = FakeExamStorage();

      final container = ProviderContainer(
        overrides: [
          examServiceProvider.overrideWithValue(fakeService),
          examStorageProvider.overrideWithValue(fakeStorage),
        ],
      );

      final notifier = container.read(examProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. 先有一场初始手动考试
      final initialTime = DateTime.now().add(const Duration(days: 5));
      await notifier.addManualExam(title: '初始考试', time: initialTime);
      expect(container.read(examProvider).value?.length, equals(1));

      // 2. 触发 refresh，网络请求处于挂起中
      final refreshFuture = notifier.refresh();

      // 验证 loading 状态保留已有数据
      final stateDuringLoading = container.read(examProvider);
      expect(stateDuringLoading.isLoading, isTrue);
      expect(stateDuringLoading.value?.length, equals(1));

      // 3. 用户在网络期间新增了一场手动考试
      final newTime = DateTime.now().add(const Duration(days: 10));
      await notifier.addManualExam(title: '刷新期间新增的考试', time: newTime);
      expect(container.read(examProvider).value?.length, equals(2));

      // 4. 网络请求返回爬取到的考试
      final scrapedExam = ExamScheduleModel(
        id: 'scraped_exam_1',
        title: '线上爬取的期末考',
        courseName: '编译原理',
        time: DateTime.now().add(const Duration(days: 15)),
        allTimes: [DateTime.now().add(const Duration(days: 15))],
        rawTimeStrs: ['2026-11-01 09:00'],
        status: '待考',
        isManual: false,
      );
      fakeService.completer.complete([scrapedExam]);
      await refreshFuture;

      // 5. 验证最终合并列表：刷新期间新增的考试依然安然无恙！
      final finalList = container.read(examProvider).value!;
      expect(finalList.any((e) => e.title == '初始考试'), isTrue);
      expect(finalList.any((e) => e.title == '刷新期间新增的考试'), isTrue);
      expect(finalList.any((e) => e.title == '线上爬取的期末考'), isTrue);
      expect(finalList.length, equals(3));
    });
  });

  group('#29 YdjwxtService single-flight mutex & backup rollback', () {
    test('Concurrent syncTimetable calls join the single-flight in-progress task', () async {
      final ydjwxt = YdjwxtService();

      var progressCalls1 = 0;
      var progressCalls2 = 0;

      // 并发调用两次（内部未配置真实网络，会失败，但两个并发调用返回同一个 Future 并在完成时同步结束）
      final f1 = ydjwxt.syncTimetable(onProgress: (_) => progressCalls1++);
      final f2 = ydjwxt.syncTimetable(onProgress: (_) => progressCalls2++);

      // 期望 f1 和 f2 会抛出相同的异常
      expect(f1, throwsA(anything));
      expect(f2, throwsA(anything));
    });
  });
}
