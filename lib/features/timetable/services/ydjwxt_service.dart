import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/services/ydjwxt_auth_service.dart';
import '../models/course_model.dart';
import '../parsers/ydjwxt_json_parser.dart';
import '../services/timetable_storage.dart';
import '../services/timetable_rule_service.dart';
import '../services/timetable_subscription_service.dart';
import '../utils/ics_generator.dart';

/// 课表同步结果模型
class TimetableSyncResult {
  final bool success;
  final int courseCount;
  final String? message;

  const TimetableSyncResult({
    required this.success,
    this.courseCount = 0,
    this.message,
  });
}

class YdjwxtService {
  final _logger = AppLogger.instance;
  final _authService = YdjwxtAuthService();
  String? _token;

  /// 单飞 (single-flight) 互斥锁：同一时间仅允许一个在途同步，并发调用直接复用该 Future
  static Future<TimetableSyncResult>? _syncInProgress;

  /// 全自动同步课表
  ///
  /// [onProgress] 进度回调
  /// [firstWeekMonday] 本学期第一周周一 (可选，若不传则从 API 自动解析)
  ///
  /// 同步是原子的：开始前先物理备份本地课表为 .bak，任何一步失败都会回滚，
  /// 保证旧课表不受损（调用方只需 catch 提示失败即可）。
  /// 并发保护：无论登录、课表页下拉、设置页还是 MCP 调用，同一时间仅允许一个在途同步，并发直接复用。
  Future<TimetableSyncResult> syncTimetable({
    required Function(String progress) onProgress,
    DateTime? firstWeekMonday,
  }) async {
    if (_syncInProgress != null) {
      _logger.i('⏳ Timetable sync already in progress, joining existing task...');
      onProgress('课表同步已在进行中...');
      return await _syncInProgress!;
    }

    final future = _doSyncTimetable(
      onProgress: onProgress,
      firstWeekMonday: firstWeekMonday,
    );
    _syncInProgress = future;

    try {
      return await future;
    } finally {
      _syncInProgress = null;
    }
  }

  Future<TimetableSyncResult> _doSyncTimetable({
    required Function(String progress) onProgress,
    DateTime? firstWeekMonday,
  }) async {
    final storage = TimetableStorage();

    TimetableBackup? backup;
    try {
      backup = await TimetableBackup.capture(storage);
    } catch (e) {
      _logger.w('⚠️ Failed to backup local timetable: $e');
    }

    try {
      _logger.i('🚀 Starting automatic timetable sync (YDJWXT)...');
      
      // 1. 获取 Token
      onProgress('正在进行身份验证...');
      _token = await _authService.getToken();
      
      _logger.i('✅ Token acquired, starting data fetch...');

      // 2. 预检：确定第一周周一的日期 (如果外部未提供)
      DateTime? calculatedFirstWeekMonday = firstWeekMonday;
      
      if (calculatedFirstWeekMonday == null) {
        onProgress('正在校准学期时间...');
        // 随便请求一周的数据（例如第一周）来获取日期参考
        final rawJson = await _fetchRawWeekJson(1);
        calculatedFirstWeekMonday = YdjwxtJsonParser.extractFirstWeekMonday(rawJson);
        _logger.i('📅 Automatically calculated firstWeekMonday: $calculatedFirstWeekMonday');
      }

      if (calculatedFirstWeekMonday == null) {
        // API 解析/本地元数据都拿不到时，按统一优先级解析
        //（自动同步开：元数据 > 手动设置 > 猜测；关：手动设置优先）
        calculatedFirstWeekMonday = await storage.resolveFirstWeekMonday();
        _logger.i('📅 Resolved firstWeekMonday: $calculatedFirstWeekMonday');
      }

      // 3. 并发获取 1-20 周的数据
      onProgress('正在同步全学期课表...');
      final fetchTasks = <Future<Map<String, dynamic>>>[];
      for (int i = 1; i <= 20; i++) {
        fetchTasks.add(_fetchRawWeekJson(i));
      }
      
      final results = await Future.wait(fetchTasks);
      
      final allWeeksData = <List<CourseModel>>[];
      for (var rawJson in results) {
        final weekData = YdjwxtJsonParser.parseWeekJson(rawJson);
        allWeeksData.add(weekData);
      }
      
      // 4. 解析与合并
      onProgress('正在整理课程数据...');
      final mergedCourses = YdjwxtJsonParser.mergeWeeks(allWeeksData);
      _logger.i('✨ Total unique courses merged: ${mergedCourses.length}');
      
      if (mergedCourses.isEmpty) {
        throw Exception('未能获取到有效的课程数据，请确认本学期是否有课。');
      }

      // 5. 生成并保存结果
      onProgress('正在保存到本地...');

      // 1. 保存原始课表数据（未经规则修改的底数）
      await storage.saveRawCourseList(mergedCourses);

      // 2. 立即根据本地保存的规则修改课程
      final ruleService = TimetableRuleService();
      final rules = await storage.readRules();
      final finalCourses = ruleService.applyRules(mergedCourses, rules);

      // 3. 生成基于修改后课程的 ICS
      final icsContent = IcsGenerator.generate(finalCourses, calculatedFirstWeekMonday);

      // 4. 保存 ICS 及修改后的课程列表
      await storage.saveTimetable(icsContent);
      await storage.saveCourseList(finalCourses);

      // 保存元数据
      await storage.saveMetadata(
        semester: AppConstants.defaultSemester,
        firstWeekMonday: calculatedFirstWeekMonday,
      );

      // 5. 课表云端订阅自动同步（若开启）：将调停后的 ICS 自动上传到 Cloudflare R2
      try {
        final subService = TimetableSubscriptionService(storage: storage);
        if (await subService.isEnabled()) {
          onProgress('正在同步课表订阅至云端...');
          await subService.uploadTimetable(icsContent: icsContent);
        }
      } catch (e) {
        _logger.w('⚠️ Uploading timetable subscription failed: $e');
      }

      if (backup != null) {
        await backup.cleanup();
      }

      final msg = '同步成功！已更新 ${finalCourses.length} 门课程';
      onProgress(msg);
      _logger.i('🎉 YDJWXT Sync Completed successfully (applied ${rules.length} local rules).');

      return TimetableSyncResult(
        success: true,
        courseCount: finalCourses.length,
        message: msg,
      );
    } catch (e) {
      _logger.e('❌ YDJWXT sync failed: $e');
      // 回滚到同步前的本地课表（仅从 .bak 还原 capture 时真实存在的文件）
      if (backup != null) await backup.restore(storage);
      rethrow;
    }
  }

  /// 获取单周课表原始 JSON
  Future<Map<String, dynamic>> _fetchRawWeekJson(int week) async {
    if (_token == null) throw Exception('Token is null');
    
    final dio = DioClient().dio;
    final url = '${AppConstants.ydjwxtApiUrl}?week=$week&kbjcmsid=';
    
    final response = await dio.post(
      url,
      options: Options(
        headers: {
          'token': _token,
          'User-Agent': AppConstants.ydjwxtUA,
          'Referer': 'https://ydjwxt.hunau.edu.cn/hnnydx/',
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://ydjwxt.hunau.edu.cn',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        return rawData;
      }
    }

    throw Exception('HTTP ${response.statusCode} while fetching week $week');
  }
}

/// 本地课表备份：同步失败时原样写回，保证旧数据不受损。
///
/// 回滚机制：在同步前 capture 时，直接将物理文件（current_timetable.ics, timetable_meta.json, courses.json, raw_courses.json）备份为 .bak 文件。
/// 若同步中途失败触发 rollback 时：仅当 capture 时文件物理存在时才从 .bak 还原，如果原先物理不存在才删除；
/// 严禁因读取 JSON 失败返回 null/[] 就武断调用 deleteTimetable()。
class TimetableBackup {
  static const List<String> targetFileNames = [
    'current_timetable.ics',
    'timetable_meta.json',
    'courses.json',
    'raw_courses.json',
  ];
  static const String backupExtension = '.bak';

  final String _baseDir;
  final Map<String, bool> _fileExisted;

  const TimetableBackup({
    required String baseDir,
    required Map<String, bool> fileExisted,
  })  : _baseDir = baseDir,
        _fileExisted = fileExisted;

  /// 在同步前 capture 时，直接将物理文件备份为 .bak 文件
  static Future<TimetableBackup> capture(TimetableStorage storage) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileExisted = <String, bool>{};

    for (final name in targetFileNames) {
      final file = File('${dir.path}/$name');
      final bakFile = File('${dir.path}/$name$backupExtension');
      final exists = await file.exists();
      fileExisted[name] = exists;

      if (exists) {
        try {
          await file.copy(bakFile.path);
        } catch (e) {
          AppLogger.instance.w('⚠️ Failed to backup file $name to $backupExtension: $e');
        }
      } else {
        // 原文件不存在，若残留旧 .sync_bak 则清理，防止误还原
        if (await bakFile.exists()) {
          try {
            await bakFile.delete();
          } catch (_) {}
        }
      }
    }

    return TimetableBackup(
      baseDir: dir.path,
      fileExisted: fileExisted,
    );
  }

  /// 若同步中途失败触发 rollback 时：
  /// 仅当 capture 时文件物理存在时才从 .bak 还原，如果原先物理不存在才删除；
  /// 严禁因读取 JSON 失败返回 null/[] 就武断调用 deleteTimetable()。
  Future<void> restore(TimetableStorage storage) async {
    try {
      for (final name in targetFileNames) {
        final file = File('$_baseDir/$name');
        final bakFile = File('$_baseDir/$name$backupExtension');
        final existed = _fileExisted[name] ?? false;

        if (existed) {
          if (await bakFile.exists()) {
            await bakFile.copy(file.path);
            await bakFile.delete();
          }
        } else {
          // 原先物理不存在：如果同步中途写了半截残留文件，删除该残留
          if (await file.exists()) {
            await file.delete();
          }
          if (await bakFile.exists()) {
            await bakFile.delete();
          }
        }
      }
    } catch (e) {
      AppLogger.instance.w('⚠️ Timetable rollback failed: $e');
    }
  }

  /// 同步成功后清理 .bak 文件
  Future<void> cleanup() async {
    try {
      for (final name in targetFileNames) {
        final bakFile = File('$_baseDir/$name$backupExtension');
        if (await bakFile.exists()) {
          await bakFile.delete();
        }
      }
    } catch (e) {
      AppLogger.instance.w('⚠️ Timetable backup cleanup failed: $e');
    }
  }
}
