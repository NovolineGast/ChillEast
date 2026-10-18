import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_provider.dart';
import '../state/locale_provider.dart';
import '../utils/secure_storage_helper.dart';
import '../../features/cloudisk/services/cloud_backup_manager.dart';
import '../../features/profile/providers/settings_provider.dart';
import '../../features/timetable/services/timetable_storage.dart';

/// 应用全局设置读取与管理服务
class AppSettingsService {
  final Ref? _ref;

  AppSettingsService([this._ref]);

  static const List<int> validCourseReminderMinutes = [
    0,
    5,
    10,
    20,
    30,
    40,
    50,
    60,
  ];

  static const List<double> validHomeworkReminderHours = [
    0.0,
    0.5,
    1.0,
    2.0,
    6.0,
    12.0,
    24.0,
    48.0,
  ];

  static const List<int> validLibraryReminderMinutes = [
    0,
    5,
    10,
    20,
    30,
    40,
    50,
    60,
  ];

  /// 获取当前所有设置项
  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final secure = SecureStorageHelper();
    final timetableStorage = TimetableStorage();

    final courseReminder = prefs.getInt('course_reminder_minutes') ?? 0;
    final hwReminder = prefs.getDouble('homework_reminder_hours') ?? 0.0;
    final libReminder = prefs.getInt('library_reminder_minutes') ?? 0;
    final courseLive = prefs.getBool('course_live_enabled') ?? false;
    final flymeLive = prefs.getBool('flyme_live_enabled') ?? false;
    final timetableSync = prefs.getBool(SettingsNotifier.timetableAutoSyncKey) ?? true;
    final cloudBackupSync = prefs.getBool(SettingsNotifier.cloudBackupAutoSyncKey) ?? false;
    final manualMonday = await timetableStorage.readManualFirstWeekMonday();
    final langCode = prefs.getString(LocaleNotifier.localeKey) ?? 'system';

    String? aiApiUrl;
    String? aiModel;
    bool hasCustomApiKey = false;
    try {
      aiApiUrl = await secure.getAiApiUrl();
      aiModel = await secure.getAiModel();
      final key = await secure.getAiApiKey();
      hasCustomApiKey = key != null && key.trim().isNotEmpty;
    } catch (_) {}

    return {
      'notifications': {
        'course_reminder_minutes': courseReminder,
        'homework_reminder_hours': hwReminder,
        'library_reminder_minutes': libReminder,
        'course_live_enabled': courseLive,
        'flyme_live_enabled': flymeLive,
      },
      'timetable': {
        'timetable_auto_sync': timetableSync,
        'manual_first_week_monday':
            manualMonday?.toIso8601String().split('T').first,
      },
      'sync': {
        'cloud_backup_auto_sync': cloudBackupSync,
      },
      'language': {
        'code': langCode,
      },
      'ai': {
        'api_url': (aiApiUrl != null && aiApiUrl.isNotEmpty)
            ? aiApiUrl
            : '（跟随默认系统 Worker）',
        'model': (aiModel != null && aiModel.isNotEmpty)
            ? aiModel
            : '（跟随默认）',
        'has_custom_api_key': hasCustomApiKey,
      },
    };
  }

  /// 更新设置项
  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> updates,
  ) async {
    final updatedEntries = <String, dynamic>{};
    final notices = <String>[];
    final prefs = await SharedPreferences.getInstance();
    final ref = _ref;

    // 1. 课程提前提醒分钟数
    if (updates.containsKey('course_reminder_minutes')) {
      final raw = updates['course_reminder_minutes'];
      if (raw is num) {
        final snapped = _snapToNearestInt(raw.toInt(), validCourseReminderMinutes);
        if (ref != null) {
          await ref.read(settingsProvider.notifier).setReminderMinutes(snapped);
        } else {
          await prefs.setInt('course_reminder_minutes', snapped);
        }
        updatedEntries['course_reminder_minutes'] = snapped;
        if (snapped != raw.toInt()) {
          notices.add('课程提前提醒已校准为最接近的可选值: ${snapped}分钟');
        } else {
          notices.add('课程提前提醒已设置为: ${snapped == 0 ? "不提醒" : "$snapped分钟"}');
        }
      }
    }

    // 2. 作业提前提醒小时数
    if (updates.containsKey('homework_reminder_hours')) {
      final raw = updates['homework_reminder_hours'];
      if (raw is num) {
        final snapped = _snapToNearestDouble(
          raw.toDouble(),
          validHomeworkReminderHours,
        );
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setHomeworkReminderHours(snapped);
        } else {
          await prefs.setDouble('homework_reminder_hours', snapped);
        }
        updatedEntries['homework_reminder_hours'] = snapped;
        if (snapped != raw.toDouble()) {
          notices.add('作业提前提醒已校准为最接近的可选值: ${snapped}小时');
        } else {
          notices.add('作业提前提醒已设置为: ${snapped == 0 ? "不提醒" : "$snapped小时"}');
        }
      }
    }

    // 3. 图书馆座位提前提醒分钟数
    if (updates.containsKey('library_reminder_minutes')) {
      final raw = updates['library_reminder_minutes'];
      if (raw is num) {
        final snapped =
            _snapToNearestInt(raw.toInt(), validLibraryReminderMinutes);
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setLibraryReminderMinutes(snapped);
        } else {
          await prefs.setInt('library_reminder_minutes', snapped);
        }
        updatedEntries['library_reminder_minutes'] = snapped;
        if (snapped != raw.toInt()) {
          notices.add('图书馆座位提前提醒已校准为: ${snapped}分钟');
        } else {
          notices.add('图书馆座位提前提醒已设置为: ${snapped == 0 ? "不提醒" : "$snapped分钟"}');
        }
      }
    }

    // 4. Android 实时活动 (Live Updates)
    if (updates.containsKey('course_live_enabled')) {
      final raw = updates['course_live_enabled'];
      if (raw is bool) {
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setCourseLiveEnabled(raw);
        } else {
          await prefs.setBool('course_live_enabled', raw);
          if (raw) await prefs.setBool('flyme_live_enabled', false);
        }
        updatedEntries['course_live_enabled'] = raw;
        notices.add('Android 实时活动 (Live Updates) 已${raw ? "开启" : "关闭"}');
      }
    }

    // 5. Flyme 实况通知
    if (updates.containsKey('flyme_live_enabled')) {
      final raw = updates['flyme_live_enabled'];
      if (raw is bool) {
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setFlymeLiveEnabled(raw);
        } else {
          await prefs.setBool('flyme_live_enabled', raw);
          if (raw) await prefs.setBool('course_live_enabled', false);
        }
        updatedEntries['flyme_live_enabled'] = raw;
        notices.add('Flyme 12+ 实况通知已${raw ? "开启" : "关闭"}');
      }
    }

    // 6. 课表自动同步开关
    if (updates.containsKey('timetable_auto_sync') ||
        updates.containsKey('timetable_auto_sync_enabled')) {
      final raw = updates['timetable_auto_sync'] ??
          updates['timetable_auto_sync_enabled'];
      if (raw is bool) {
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setTimetableAutoSyncEnabled(raw);
        } else {
          await prefs.setBool(SettingsNotifier.timetableAutoSyncKey, raw);
        }
        updatedEntries['timetable_auto_sync'] = raw;
        notices.add('课表自动同步已${raw ? "开启" : "关闭"}');
      }
    }

    // 7. 云备份自动同步开关
    if (updates.containsKey('cloud_backup_auto_sync') ||
        updates.containsKey('cloud_backup_auto_sync_enabled')) {
      final raw = updates['cloud_backup_auto_sync'] ??
          updates['cloud_backup_auto_sync_enabled'];
      if (raw is bool) {
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setCloudBackupAutoSyncEnabled(raw);
        } else {
          await prefs.setBool(SettingsNotifier.cloudBackupAutoSyncKey, raw);
        }
        updatedEntries['cloud_backup_auto_sync'] = raw;
        notices.add('数据自动同步云端备份已${raw ? "开启" : "关闭"}');
      }
    }

    // 8. 手动指定本学期第一周周一
    if (updates.containsKey('manual_first_week_monday')) {
      final raw = updates['manual_first_week_monday']?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed == null) {
          throw FormatException('无法解析开学第一周周一日期: "$raw"，请使用 YYYY-MM-DD 格式');
        }
        // 自动校准到周一
        final monday = parsed.subtract(Duration(days: parsed.weekday - 1));
        final mondayDateOnly = DateTime(monday.year, monday.month, monday.day);
        if (ref != null) {
          await ref
              .read(settingsProvider.notifier)
              .setManualFirstWeekMonday(mondayDateOnly);
        } else {
          await TimetableStorage().saveManualFirstWeekMonday(mondayDateOnly);
        }
        final isoStr = mondayDateOnly.toIso8601String().split('T').first;
        updatedEntries['manual_first_week_monday'] = isoStr;
        if (parsed.weekday != 1) {
          notices.add('开学日期已自动校准为当周周一 ($isoStr)');
        } else {
          notices.add('本学期第一周周一已设置为: $isoStr');
        }
      }
    }

    // 9. 界面语言
    if (updates.containsKey('language')) {
      final raw = updates['language']?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        final code = _normalizeLanguageCode(raw);
        if (code != null) {
          if (ref != null) {
            await ref.read(localeProvider.notifier).setLocaleByCode(code);
          } else {
            await prefs.setString(LocaleNotifier.localeKey, code);
          }
          updatedEntries['language'] = code;
          notices.add('应用语言已设置为: $code');
        } else {
          notices.add('不支持的语言代码: $raw');
        }
      }
    }

    // 10. AI 接口端点
    if (updates.containsKey('ai_api_url')) {
      final raw = updates['ai_api_url']?.toString().trim() ?? '';
      if (ref != null) {
        await ref.read(aiAssistantProvider.notifier).setApiUrl(raw);
      } else {
        final secure = SecureStorageHelper();
        raw.isNotEmpty
            ? await secure.saveAiApiUrl(raw)
            : await secure.clearAiApiUrl();
      }
      updatedEntries['ai_api_url'] =
          raw.isNotEmpty ? raw : '（已恢复默认 Worker 中转）';
      notices.add('AI 接口端点已更新');
    }

    // 11. AI 模型名称
    if (updates.containsKey('ai_model')) {
      final raw = updates['ai_model']?.toString().trim() ?? '';
      if (ref != null) {
        await ref.read(aiAssistantProvider.notifier).setModel(raw);
      } else {
        final secure = SecureStorageHelper();
        raw.isNotEmpty
            ? await secure.saveAiModel(raw)
            : await secure.clearAiModel();
      }
      updatedEntries['ai_model'] =
          raw.isNotEmpty ? raw : '（已恢复默认模型）';
      notices.add('AI 模型名称已更新');
    }

    // 12. AI API Key
    if (updates.containsKey('ai_api_key')) {
      final raw = updates['ai_api_key']?.toString().trim() ?? '';
      if (ref != null) {
        if (raw.isNotEmpty) {
          await ref.read(aiAssistantProvider.notifier).setApiKey(raw);
        } else {
          await ref.read(aiAssistantProvider.notifier).resetToDefaults();
        }
      } else {
        final secure = SecureStorageHelper();
        raw.isNotEmpty
            ? await secure.saveAiApiKey(raw)
            : await secure.clearAiApiKey();
      }
      updatedEntries['ai_api_key'] =
          raw.isNotEmpty ? '（已设置自定义 API Key）' : '（已清除/使用默认）';
      notices.add('AI API Key 已更新');
    }

    CloudBackupManager.instance.markDirty();

    final currentSettings = await getSettings();

    return {
      'updated': updatedEntries,
      'summary': notices.join('；'),
      'current_settings': currentSettings,
    };
  }

  int _snapToNearestInt(int value, List<int> validValues) {
    if (validValues.contains(value)) return value;
    int closest = validValues.first;
    int minDiff = (value - closest).abs();
    for (final v in validValues) {
      final diff = (value - v).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = v;
      }
    }
    return closest;
  }

  double _snapToNearestDouble(double value, List<double> validValues) {
    if (validValues.contains(value)) return value;
    double closest = validValues.first;
    double minDiff = (value - closest).abs();
    for (final v in validValues) {
      final diff = (value - v).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = v;
      }
    }
    return closest;
  }

  String? _normalizeLanguageCode(String input) {
    final lower = input.trim().toLowerCase();
    switch (lower) {
      case 'system':
      case '跟随系统':
      case '跟隨系統':
      case '系统默认':
      case '系統默認':
      case 'follow system':
        return 'system';
      case 'zh':
      case 'zh-cn':
      case 'zh_cn':
      case '中文':
      case '简体':
      case '简体中文':
      case 'chinese':
      case 'simplified chinese':
        return 'zh';
      case 'zh_hk':
      case 'zh-hk':
      case '香港繁体':
      case '繁体中文（中国香港）':
      case '繁體中文（中國香港）':
        return 'zh_HK';
      case 'zh_tw':
      case 'zh-tw':
      case '繁体':
      case '繁体中文':
      case '繁體中文':
      case 'traditional chinese':
        return 'zh_TW';
      case 'zh_hefei':
      case '合肥':
      case '合肥话':
        return 'zh_hefei';
      case 'en':
      case '英文':
      case '英语':
      case 'english':
        return 'en';
      case 'ja':
      case '日语':
      case '日文':
      case 'japanese':
        return 'ja';
      case 'es':
      case '西语':
      case '西班牙语':
      case 'spanish':
        return 'es';
      case 'fr':
      case '法语':
      case 'french':
        return 'fr';
      case 'pt':
      case '葡语':
      case '葡萄牙语':
      case 'portuguese':
        return 'pt';
      case 'ru':
      case '俄语':
      case 'russian':
        return 'ru';
      case 'yue':
      case '粤语':
      case '广州话':
      case '广东话':
      case 'cantonese':
        return 'yue';
      case 'wuu':
      case '吴语':
      case '苏州话':
      case '上海话':
        return 'wuu';
      case 'hsn':
      case '湘语':
      case '长沙话':
      case '湖南话':
        return 'hsn';
      case 'gan':
      case '赣语':
      case '南昌话':
      case '江西话':
        return 'gan';
      default:
        final trimmed = input.trim();
        if (LocaleNotifier.supportedLanguages.any((o) => o.code == trimmed)) {
          return trimmed;
        }
        return null;
    }
  }
}
