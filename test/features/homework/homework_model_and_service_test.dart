import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/core/network/dio_client.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/homework/services/homework_service.dart';

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

class _MockDioAdapter implements HttpClientAdapter {
  int statusCode = 200;
  String responseData = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      responseData,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('hw-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    webview.InAppWebViewPlatform.instance = _FakeBrowserPlatform();
    await AppCookieManager().initialize();
    await DioClient().initialize();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  group('HomeworkModel Tests', () {
    test('toJson and fromJson serialize properly', () {
      final now = DateTime.now();
      final model = HomeworkModel(
        id: 'hw001',
        courseName: '《高等数学》',
        title: '课后习题1',
        endTime: now,
        status: HomeworkStatus.pending,
        studentId: '202440800000',
        rawTimeStr: '剩余12小时',
        dataUrl: 'https://example.com/hw',
        isManual: true,
        createdAt: now,
        remarks: '重点复习',
      );

      final json = model.toJson();
      expect(json['id'], 'hw001');
      expect(json['status'], HomeworkStatus.pending.index);
      expect(json['isManual'], isTrue);

      final revived = HomeworkModel.fromJson(json);
      expect(revived.id, 'hw001');
      expect(revived.courseName, '《高等数学》');
      expect(revived.title, '课后习题1');
      expect(revived.status, HomeworkStatus.pending);
      expect(revived.isManual, isTrue);
      expect(revived.remarks, '重点复习');
    });

    test('copyWith updates specified fields', () {
      final model = HomeworkModel(
        id: '1',
        courseName: 'A',
        title: 'T1',
        status: HomeworkStatus.pending,
        studentId: '100',
      );

      final updated = model.copyWith(
        title: 'T2',
        status: HomeworkStatus.completed,
        remarks: '已批改',
      );

      expect(updated.id, '1');
      expect(updated.title, 'T2');
      expect(updated.status, HomeworkStatus.completed);
      expect(updated.remarks, '已批改');
    });
  });

  group('HomeworkService HTML Parsing and URL Transformation', () {
    late _MockDioAdapter adapter;
    late HomeworkService service;

    setUp(() {
      adapter = _MockDioAdapter();
      DioClient().dio.httpClientAdapter = adapter;
      service = HomeworkService();
    });

    test('fetchHomeworkList parses pending, completed, and archived items', () async {
      adapter.statusCode = 200;
      adapter.responseData = '''
      <!DOCTYPE html>
      <html>
      <body>
        <ul>
          <!-- 1. 待完成作业 (带有剩余小时和分钟, Android端URL需要转换) -->
          <li onclick="goTask(1)" data="https://mooc1-api.chaoxing.com/mooc-ans/android/mtaskmsgspecial?taskrefId=51740957&msgId=0&courseId=261566913&userId=100000000&clazzId=142140293&type=work&enc_task=642d4dfcd6c101ee5f32b86ec2212f91">
            <div class="spanImg"><img src="https://static.chaoxing.com/task-work.png" /></div>
            <div role="option">
              <p>第1次作业</p>
              <span class="status">未提交</span>
              <span>《高等数学》</span>
              <span>剩余194小时34分钟</span>
            </div>
          </li>

          <!-- 2. 已完成作业 -->
          <li onclick="goTask(2)" data="https://example.com/task2">
            <div class="spanImg"><img src="https://static.chaoxing.com/task-work.png" /></div>
            <div role="option">
              <p>第2次作业</p>
              <span class="status">已提交</span>
              <span>《大学物理》</span>
            </div>
          </li>

          <!-- 3. 已归档/已截止作业 (灰色图标) -->
          <li onclick="goTask(3)" data="https://example.com/task3">
            <div class="spanImg"><img src="https://static.chaoxing.com/task-work-gray.png" /></div>
            <div role="option">
              <p>第3次作业</p>
              <span class="status">未提交</span>
              <span>《线性代数》</span>
            </div>
          </li>

          <!-- 4. 剩余天数和小时 -->
          <li onclick="goTask(4)" data="https://example.com/task4">
            <div class="spanImg"><img src="https://static.chaoxing.com/task-work.png" /></div>
            <div role="option">
              <p>第4次作业</p>
              <span class="status">未提交</span>
              <span>《概率论》</span>
              <span>剩余3天5小时</span>
            </div>
          </li>

          <!-- 5. 剩余仅分钟 -->
          <li onclick="goTask(5)" data="">
            <div class="spanImg"><img src="https://static.chaoxing.com/task-work.png" /></div>
            <div role="option">
              <p>第5次作业</p>
              <span class="status">未提交</span>
              <span>《离散数学》</span>
              <span>剩余45分钟</span>
            </div>
          </li>

          <!-- 6. 无效项，没有 role="option"，应跳过 -->
          <li onclick="goTask(6)">
            <div>无效内容</div>
          </li>
        </ul>
      </body>
      </html>
      ''';

      final list = await service.fetchHomeworkList('202440800000');
      expect(list.length, 5);

      // 1. Pending with converted URL
      expect(list[0].title, '第1次作业');
      expect(list[0].courseName, '《高等数学》');
      expect(list[0].status, HomeworkStatus.pending);
      expect(list[0].dataUrl, contains('/work/phone/task-work?taskrefId=51740957'));
      expect(list[0].dataUrl, contains('classId=142140293'));
      expect(list[0].endTime, isNotNull);

      // 2. Completed
      expect(list[1].title, '第2次作业');
      expect(list[1].courseName, '《大学物理》');
      expect(list[1].status, HomeworkStatus.completed);

      // 3. Archived (gray)
      expect(list[2].title, '第3次作业');
      expect(list[2].status, HomeworkStatus.archived);

      // 4. Days and hours
      expect(list[3].title, '第4次作业');
      expect(list[3].status, HomeworkStatus.pending);
      expect(list[3].endTime, isNotNull);

      // 5. Minutes only & empty dataUrl fallback id
      expect(list[4].title, '第5次作业');
      expect(list[4].id, '《离散数学》|第5次作业');
    });

    test('fetchHomeworkList throws when server status is not 200', () async {
      adapter.statusCode = 500;
      adapter.responseData = 'Internal Server Error';

      expect(
        () => service.fetchHomeworkList('202440800000'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
