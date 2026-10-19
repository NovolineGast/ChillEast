import '../../services/app_settings_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 应用设置查询与配置 (manage_settings)
class SettingsTool {
  static const String toolName = 'manage_settings';

  static McpTool create({
    AppSettingsService? service,
    String toolName = toolName,
  }) {
    final settingsService = service ?? AppSettingsService();

    return McpTool(
      name: toolName,
      description:
          '查询或修改应用系统设置。操作动作：\n'
          '- get：查询当前设置（包括课程/作业/图书馆通知提醒、实时活动开关、课表自动同步、云备份、语言、AI配置等）；\n'
          '- update：修改设置项（如设置课程提醒分钟数、作业提醒小时数、语言、开启/关闭自动同步等）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['get', 'update'],
            'description': '操作类型：get（获取当前设置，默认）、update（更新配置设置）。',
            'default': 'get',
          },
          'course_reminder_minutes': {
            'type': 'integer',
            'enum': [0, 5, 10, 20, 30, 40, 50, 60],
            'description':
                '课程提前提醒分钟数（0: 不提醒，可选 5, 10, 20, 30, 40, 50, 60）。',
          },
          'homework_reminder_hours': {
            'type': 'number',
            'enum': [0, 0.5, 1, 2, 6, 12, 24, 48],
            'description':
                '作业提前提醒小时数（0: 不提醒，可选 0.5, 1, 2, 6, 12, 24, 48）。',
          },
          'library_reminder_minutes': {
            'type': 'integer',
            'enum': [0, 5, 10, 20, 30, 40, 50, 60],
            'description':
                '图书馆座位提前提醒分钟数（0: 不提醒，可选 5, 10, 20, 30, 40, 50, 60）。',
          },
          'course_live_enabled': {
            'type': 'boolean',
            'description': 'Android 16+ Live Updates 实时活动总开关（开启时自动关闭 Flyme 实况）。',
          },
          'flyme_live_enabled': {
            'type': 'boolean',
            'description': 'Flyme 12+ 实况通知总开关（开启时自动关闭 AOSP 实时活动）。',
          },
          'timetable_auto_sync': {
            'type': 'boolean',
            'description': '课表自动同步总开关。',
          },
          'cloud_backup_auto_sync': {
            'type': 'boolean',
            'description': '数据自动同步云端备份总开关。',
          },
          'manual_first_week_monday': {
            'type': 'string',
            'description': '手动指定的本学期第一周周一（格式 YYYY-MM-DD，若非周一会自动校准为当周周一）。',
          },
          'language': {
            'type': 'string',
            'description':
                '应用语言代码或名称（如 "system", "zh", "en", "zh_HK", "zh_TW", "ja", "es", "fr", "pt", "ru", "yue", "wuu", "hsn", "gan", "zh_hefei"，也支持中文描述如 "简体中文"、"英文" 等）。',
          },
          'ai_api_url': {
            'type': 'string',
            'description': '自定义 AI 接口端点 URL（传空字符串表示重置恢复默认 Worker 中转）。',
          },
          'ai_model': {
            'type': 'string',
            'description': '自定义 AI 模型名称（传空字符串表示恢复跟随默认模型）。',
          },
          'ai_api_key': {
            'type': 'string',
            'description': '自定义 AI API Key（传空字符串表示清除自定义 Key 并使用默认）。',
          },
        },
      },
      handler: (arguments) async {
        String action = arguments['action']?.toString().trim().toLowerCase() ?? '';

        final settingKeys = [
          'course_reminder_minutes',
          'homework_reminder_hours',
          'library_reminder_minutes',
          'course_live_enabled',
          'flyme_live_enabled',
          'timetable_auto_sync',
          'timetable_auto_sync_enabled',
          'cloud_backup_auto_sync',
          'cloud_backup_auto_sync_enabled',
          'manual_first_week_monday',
          'language',
          'ai_api_url',
          'ai_model',
          'ai_api_key',
        ];

        // 智能推断：如果未明确传 action，但包含了具体设置字段，则自动判定为 update；否则判定为 get
        if (action.isEmpty) {
          final hasUpdateFields = settingKeys.any((k) => arguments.containsKey(k));
          action = hasUpdateFields ? 'update' : 'get';
        }

        if (action == 'get') {
          try {
            final current = await settingsService.getSettings();
            return McpToolResult.json({
              'success': true,
              'settings': current,
            });
          } catch (e) {
            return McpToolResult.error('获取设置失败: $e');
          }
        } else if (action == 'update') {
          try {
            final result = await settingsService.updateSettings(arguments);
            return McpToolResult.json({
              'success': true,
              'updated': result['updated'],
              'summary': result['summary'],
              'message': result['summary'].toString().isNotEmpty
                  ? '设置修改成功：${result['summary']}'
                  : '未提供需要更新的设置项',
              'current_settings': result['current_settings'],
            });
          } catch (e) {
            return McpToolResult.error('更新设置失败: $e');
          }
        } else {
          return McpToolResult.error('未知的操作 action: "$action"，请使用 "get" 或 "update"');
        }
      },
    );
  }
}
