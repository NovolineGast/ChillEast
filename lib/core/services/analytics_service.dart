import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 匿名活跃度统计服务
///
/// 隐私规范 (Zero-PII)：
/// - 每次启动时仅在用户开启开关的前提下，向 analysis.soilzhu.su 发送一次匿名心跳。
/// - 仅上报本地随机生成的 UUID、应用版本号与运行平台 (Android/iOS/等)，绝不收集任何个人信息与硬件标识。
/// - 该配置及 UUID 仅保存在设备本地，不参与任何云端同步或备份导出。
class AnalyticsService {
  AnalyticsService._();

  static const String _pingUrl = 'https://analysis.soilzhu.su/api/v1/ping';
  static const String enabledKey = 'local_analytics_enabled';
  static const String uuidKey = 'local_anonymous_uuid';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  /// 生成标准 RFC 4122 v4 UUID（纯随机数，不依赖任何硬件标识）
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

  /// 检查是否开启了匿名统计（默认开启）
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 设置匿名统计开关（仅在本地生效）
  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledKey, enabled);
    } catch (_) {}
  }

  /// 获取或生成本地匿名设备 UUID
  static Future<String> getOrCreateUuid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uuid = prefs.getString(uuidKey);
      if (uuid != null && uuid.trim().isNotEmpty) {
        return uuid.trim();
      }
      uuid = generateUuid();
      await prefs.setString(uuidKey, uuid);
      return uuid;
    } catch (_) {
      return generateUuid();
    }
  }

  /// 启动时“叮一下”发送匿名活跃心跳
  static Future<void> ping() async {
    try {
      final enabled = await isEnabled();
      if (!enabled) return;

      final uuid = await getOrCreateUuid();
      final packageInfo = await PackageInfo.fromPlatform();

      await _dio.post(
        _pingUrl,
        data: {
          'uuid': uuid,
          'version': packageInfo.version,
          'platform': Platform.operatingSystem,
        },
      );
    } catch (_) {
      // 静默处理，网络故障或服务端异常绝不影响应用主流程
    }
  }
}
