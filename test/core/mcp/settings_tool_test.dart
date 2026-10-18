import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/mcp/mcp.dart';
import 'package:ChillEast/core/state/locale_provider.dart';
import 'package:ChillEast/core/utils/secure_storage_helper.dart';
import 'package:ChillEast/features/profile/providers/settings_provider.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late TimetableStorage timetableStorage;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('settings-tool-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    timetableStorage = TimetableStorage();
    await timetableStorage.clearManualFirstWeekMonday();
  });

  group('SettingsTool MCP Tests', () {
    test('Tool schema and metadata validation', () {
      final tool = SettingsTool.create();

      expect(tool.name, equals('manage_settings'));
      expect(tool.description, contains('查询或修改应用系统设置'));
      expect(tool.inputSchema['type'], equals('object'));

      final props = tool.inputSchema['properties'] as Map<String, dynamic>;
      expect(props.containsKey('action'), isTrue);
      expect(props.containsKey('course_reminder_minutes'), isTrue);
      expect(props.containsKey('homework_reminder_hours'), isTrue);
      expect(props.containsKey('library_reminder_minutes'), isTrue);
      expect(props.containsKey('course_live_enabled'), isTrue);
      expect(props.containsKey('flyme_live_enabled'), isTrue);
      expect(props.containsKey('timetable_auto_sync'), isTrue);
      expect(props.containsKey('cloud_backup_auto_sync'), isTrue);
      expect(props.containsKey('manual_first_week_monday'), isTrue);
      expect(props.containsKey('language'), isTrue);
      expect(props.containsKey('ai_api_url'), isTrue);
      expect(props.containsKey('ai_model'), isTrue);
      expect(props.containsKey('ai_api_key'), isTrue);
    });

    test('Support alias tool names', () {
      final configTool = SettingsTool.create(toolName: 'configure_settings');
      expect(configTool.name, equals('configure_settings'));

      final queryTool = SettingsTool.create(toolName: 'query_settings');
      expect(queryTool.name, equals('query_settings'));
    });

    test('Action get returns initial settings', () async {
      final tool = SettingsTool.create();

      final result = await tool.execute({'action': 'get'});

      expect(result.isError, isFalse);
      expect(result.content.length, equals(1));
      final text = result.content.first.text;
      expect(text, contains('"notifications"'));
      expect(text, contains('"timetable"'));
      expect(text, contains('"sync"'));
      expect(text, contains('"language"'));
      expect(text, contains('"ai"'));
    });

    test('Default action is get when omitted or empty', () async {
      final tool = SettingsTool.create();

      final result = await tool.execute({});

      expect(result.isError, isFalse);
      expect(result.content.first.text, contains('"settings"'));
    });

    test('Action update snaps and persists reminder durations', () async {
      final tool = SettingsTool.create();

      // Test snapping: 18 -> 20 minutes, 1.8 -> 2.0 hours, 28 -> 30 minutes
      final result = await tool.execute({
        'action': 'update',
        'course_reminder_minutes': 18,
        'homework_reminder_hours': 1.8,
        'library_reminder_minutes': 28,
      });

      expect(result.isError, isFalse);
      final text = result.content.first.text;
      expect(text, contains('设置修改成功'));
      expect(text, contains('20分钟'));
      expect(text, contains('2.0小时'));
      expect(text, contains('30分钟'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('course_reminder_minutes'), equals(20));
      expect(prefs.getDouble('homework_reminder_hours'), equals(2.0));
      expect(prefs.getInt('library_reminder_minutes'), equals(30));
    });

    test('Action update configures Live Updates mutually exclusively', () async {
      final tool = SettingsTool.create();

      // Enable Course Live Updates
      final res1 = await tool.execute({
        'action': 'update',
        'course_live_enabled': true,
      });
      expect(res1.isError, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('course_live_enabled'), isTrue);
      expect(prefs.getBool('flyme_live_enabled'), isFalse);

      // Now enable Flyme Live -> should disable course_live_enabled
      final res2 = await tool.execute({
        'action': 'update',
        'flyme_live_enabled': true,
      });
      expect(res2.isError, isFalse);
      expect(prefs.getBool('flyme_live_enabled'), isTrue);
      expect(prefs.getBool('course_live_enabled'), isFalse);
    });

    test('Action update configures sync switches', () async {
      final tool = SettingsTool.create();

      final result = await tool.execute({
        'action': 'update',
        'timetable_auto_sync': false,
        'cloud_backup_auto_sync': true,
      });

      expect(result.isError, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SettingsNotifier.timetableAutoSyncKey), isFalse);
      expect(prefs.getBool(SettingsNotifier.cloudBackupAutoSyncKey), isTrue);
    });

    test('Action update auto-calibrates manual_first_week_monday to Monday', () async {
      final tool = SettingsTool.create();

      // 2026-03-04 is Wednesday -> snaps to 2026-03-02 (Monday)
      final result = await tool.execute({
        'action': 'update',
        'manual_first_week_monday': '2026-03-04',
      });

      expect(result.isError, isFalse);
      expect(result.content.first.text, contains('2026-03-02'));

      final saved = await timetableStorage.readManualFirstWeekMonday();
      expect(saved, isNotNull);
      expect(saved!.year, equals(2026));
      expect(saved.month, equals(3));
      expect(saved.day, equals(2));
      expect(saved.weekday, equals(DateTime.monday));
    });

    test('Action update normalizes language codes and Chinese names', () async {
      final tool = SettingsTool.create();

      // Update with '英文' -> 'en'
      final res1 = await tool.execute({
        'action': 'update',
        'language': '英文',
      });
      expect(res1.isError, isFalse);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('en'));

      // Update with 'zh-CN' -> 'zh'
      final res2 = await tool.execute({
        'action': 'update',
        'language': 'zh-CN',
      });
      expect(res2.isError, isFalse);
      await prefs.reload();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('zh'));

      // Update with '跟隨系統' -> 'system'
      final res3 = await tool.execute({
        'action': 'update',
        'language': '跟隨系統',
      });
      expect(res3.isError, isFalse);
      await prefs.reload();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('system'));
    });

    test('Action update configures custom AI options', () async {
      final tool = SettingsTool.create();

      final result = await tool.execute({
        'action': 'update',
        'ai_api_url': 'https://api.openai.com/v1',
        'ai_model': 'gpt-4o',
        'ai_api_key': 'sk-testkey12345',
      });

      expect(result.isError, isFalse);
      expect(result.content.first.text, contains('AI 接口端点已更新'));

      final secure = SecureStorageHelper();
      expect(await secure.getAiApiUrl(), equals('https://api.openai.com/v1'));
      expect(await secure.getAiModel(), equals('gpt-4o'));
      expect(await secure.getAiApiKey(), equals('sk-testkey12345'));

      // Clear AI options with empty strings
      final resetResult = await tool.execute({
        'action': 'update',
        'ai_api_url': '',
        'ai_model': '',
        'ai_api_key': '',
      });
      expect(resetResult.isError, isFalse);
      expect(await secure.getAiApiUrl(), isNull);
      expect(await secure.getAiModel(), isNull);
      expect(await secure.getAiApiKey(), isNull);
    });

    test('Action update without fields notifies user', () async {
      final tool = SettingsTool.create();

      final result = await tool.execute({'action': 'update'});

      expect(result.isError, isFalse);
      expect(result.content.first.text, contains('未提供需要更新的设置项'));
    });

    test('Action update handles invalid date format gracefully', () async {
      final tool = SettingsTool.create();

      final result = await tool.execute({
        'action': 'update',
        'manual_first_week_monday': 'invalid-date',
      });

      expect(result.isError, isTrue);
      expect(result.content.first.text, contains('更新设置失败'));
      expect(result.content.first.text, contains('无法解析开学第一周周一日期'));
    });
  });
}
