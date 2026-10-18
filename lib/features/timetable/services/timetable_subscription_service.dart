import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';
import 'timetable_storage.dart';
import 'timetable_rule_service.dart';

/// 课表云端订阅与在线同步服务 (Cloudflare R2)。
///
/// 订阅 URL 格式：`https://ics.chilleast.soilzhu.su/{uuid}/timetable.ics`
/// 导入日历 URL 格式：`webcal://ics.chilleast.soilzhu.su/{uuid}/timetable.ics`
class TimetableSubscriptionService {
  static const String subscriptionEnabledKey =
      'timetable_subscription_enabled';
  static const String subscriptionUuidKey = 'timetable_subscription_uuid';
  static const String baseUrl = 'https://ics.chilleast.soilzhu.su';

  final TimetableStorage _storage;
  final Dio _dio;
  final _logger = AppLogger.instance;

  TimetableSubscriptionService({
    TimetableStorage? storage,
    Dio? dio,
  })  : _storage = storage ?? TimetableStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                validateStatus: (status) => status != null && status < 500,
              ),
            );

  /// 生成标准 RFC 4122 v4 UUID
  static String generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant RFC 4122
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// 检查是否开启了课表云端订阅
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(subscriptionEnabledKey) ?? false;
  }

  /// 获取本地保存的订阅 UUID
  Future<String?> getUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(subscriptionUuidKey);
  }

  /// 获取或生成 UUID（无则自动生成并持久化）
  Future<String> getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(subscriptionUuidKey);
    if (uuid != null && uuid.trim().isNotEmpty) {
      return uuid.trim();
    }

    uuid = generateUuid();
    await prefs.setString(subscriptionUuidKey, uuid);
    _logger.i('Generated new timetable subscription UUID: $uuid');
    CloudBackupManager.instance.markDirty();
    return uuid;
  }

  /// 构造 HTTP 订阅 URL
  static String buildSubscriptionUrl(String uuid) {
    return '$baseUrl/$uuid/timetable.ics';
  }

  /// 构造 webcal:// 协议 URL（用于系统日历直接调起订阅）
  static String buildWebcalUrl(String uuid) {
    final uri = Uri.parse(buildSubscriptionUrl(uuid));
    return 'webcal://${uri.host}${uri.path}';
  }

  /// 设置开启或关闭课表订阅
  Future<bool> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(subscriptionEnabledKey, enabled);

    if (enabled) {
      await getOrCreateUuid();
      // 开启时立即重新生成应用了调停规则的最新 ICS 并上传
      try {
        final regenerated =
            await TimetableRuleService(storage: _storage).applyRulesAndRegenerate();
        if (regenerated.isNotEmpty) {
          final ics = await _storage.readTimetable();
          if (ics != null) {
            await uploadTimetable(icsContent: ics);
          }
        } else {
          await uploadTimetable();
        }
      } catch (e) {
        _logger.w('Regenerate timetable on enable subscription failed: $e');
        await uploadTimetable();
      }
    } else {
      // 关闭时删除 R2 上的订阅 ICS 文件
      await deleteRemoteTimetable();
    }

    CloudBackupManager.instance.markDirty();
    return enabled;
  }

  /// 重置订阅 UUID（旧链接作废，生成新链接并重新推送）
  Future<String> resetUuid() async {
    final oldUuid = await getUuid();
    if (oldUuid != null && oldUuid.isNotEmpty) {
      await deleteRemoteTimetable(targetUuid: oldUuid);
    }

    final newUuid = generateUuid();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(subscriptionUuidKey, newUuid);

    final enabled = await isEnabled();
    if (enabled) {
      await uploadTimetable();
    }

    CloudBackupManager.instance.markDirty();
    return newUuid;
  }

  /// 上传课表到云端供订阅
  ///
  /// [icsContent] 可选，若不传则从本地读取已调停的最新 ICS
  Future<bool> uploadTimetable({String? icsContent}) async {
    final enabled = await isEnabled();
    if (!enabled) {
      _logger.d('Timetable subscription disabled, skip uploading.');
      return false;
    }

    final uuid = await getOrCreateUuid();
    String? content = icsContent;
    if (content == null || content.isEmpty) {
      content = await _storage.readTimetable();
    }

    if (content == null || content.isEmpty) {
      _logger.w('No timetable ICS content available to upload for subscription.');
      return false;
    }

    final url = buildSubscriptionUrl(uuid);
    _logger.i('Uploading timetable ICS to subscription URL: $url');

    final headers = <String, dynamic>{
      'Content-Type': 'text/calendar; charset=utf-8',
    };
    const apiKey = String.fromEnvironment('DEFAULT_AI_API_KEY', defaultValue: '');
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    try {
      final response = await _dio.put(
        url,
        data: content,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        _logger.i('Timetable subscription uploaded successfully.');
        return true;
      } else {
        _logger.w(
          'Failed to upload timetable subscription: HTTP ${response.statusCode} - ${response.data}',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error uploading timetable subscription: $e');
      return false;
    }
  }

  /// 从云端删除订阅的课表文件
  Future<bool> deleteRemoteTimetable({String? targetUuid}) async {
    final uuid = targetUuid ?? await getUuid();
    if (uuid == null || uuid.trim().isEmpty) return true;

    final url = buildSubscriptionUrl(uuid.trim());
    _logger.i('Deleting timetable subscription from cloud: $url');

    final headers = <String, dynamic>{};
    const apiKey = String.fromEnvironment('DEFAULT_AI_API_KEY', defaultValue: '');
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    try {
      final response = await _dio.delete(
        url,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 || response.statusCode == 404) {
        _logger.i('Remote timetable subscription deleted successfully.');
        return true;
      } else {
        _logger.w(
          'Failed to delete remote timetable subscription: HTTP ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error deleting remote timetable subscription: $e');
      return false;
    }
  }

  /// 登出时清理本地日历订阅配置与 UUID
  Future<void> clearSubscriptionOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(subscriptionEnabledKey);
      await prefs.remove(subscriptionUuidKey);
      _logger.d('🧹 Cleared timetable subscription on logout');
    } catch (e) {
      _logger.w('Failed to clear timetable subscription on logout: $e');
    }
  }
}
