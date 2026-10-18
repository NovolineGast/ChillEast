import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/services/app_settings_service.dart';
import 'package:ChillEast/core/state/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late AppSettingsService settingsService;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('app-settings-test-');
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
    settingsService = AppSettingsService();
  });

  group('AppSettingsService Language Code Validation & Normalization', () {
    test('Valid standard codes are accepted and persisted', () async {
      final validCodes = [
        'zh', 'en', 'ja', 'es', 'fr', 'pt', 'ru',
        'yue', 'wuu', 'hsn', 'gan', 'system',
      ];

      for (final code in validCodes) {
        final result = await settingsService.updateSettings({'language': code});
        final prefs = await SharedPreferences.getInstance();

        expect(prefs.getString(LocaleNotifier.localeKey), equals(code));
        final summary = result['summary'] as String? ?? '';
        expect(summary, contains('应用语言已设置为: $code'));
      }
    });

    test('Chinese language names are mapped to standard codes', () async {
      final mapping = {
        '简体中文': 'zh',
        '中文': 'zh',
        '英文': 'en',
        '英语': 'en',
        '日语': 'ja',
        '日文': 'ja',
        '西语': 'es',
        '西班牙语': 'es',
        '法语': 'fr',
        '葡语': 'pt',
        '葡萄牙语': 'pt',
        '俄语': 'ru',
        '粤语': 'yue',
        '广州话': 'yue',
        '广东话': 'yue',
        '吴语': 'wuu',
        '上海话': 'wuu',
        '苏州话': 'wuu',
        '湘语': 'hsn',
        '长沙话': 'hsn',
        '湖南话': 'hsn',
        '赣语': 'gan',
        '南昌话': 'gan',
        '江西话': 'gan',
        '跟随系统': 'system',
        '系统默认': 'system',
      };

      for (final entry in mapping.entries) {
        final result = await settingsService.updateSettings({'language': entry.key});
        final prefs = await SharedPreferences.getInstance();

        expect(prefs.getString(LocaleNotifier.localeKey), equals(entry.value),
            reason: '${entry.key} should map to ${entry.value}');
        final summary = result['summary'] as String? ?? '';
        expect(summary, contains('应用语言已设置为: ${entry.value}'));
      }
    });

    test('Regional codes and dialect aliases are mapped correctly', () async {
      final regionalMapping = {
        'zh-CN': 'zh',
        'zh_cn': 'zh',
        'simplified chinese': 'zh',
        'zh-HK': 'zh_HK',
        'zh_hk': 'zh_HK',
        '香港繁体': 'zh_HK',
        '繁体中文（中国香港）': 'zh_HK',
        'zh-TW': 'zh_TW',
        'zh_tw': 'zh_TW',
        '繁体': 'zh_TW',
        '繁体中文': 'zh_TW',
        'traditional chinese': 'zh_TW',
        'zh_hefei': 'zh_hefei',
        '合肥话': 'zh_hefei',
        '合肥': 'zh_hefei',
      };

      for (final entry in regionalMapping.entries) {
        await settingsService.updateSettings({'language': entry.key});
        final prefs = await SharedPreferences.getInstance();

        expect(prefs.getString(LocaleNotifier.localeKey), equals(entry.value),
            reason: '${entry.key} should map to ${entry.value}');
      }
    });

    test('Case-insensitivity and whitespace trimming work as expected', () async {
      await settingsService.updateSettings({'language': '  EN  '});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('en'));

      await settingsService.updateSettings({'language': '  ZH-cn  '});
      expect(prefs.getString(LocaleNotifier.localeKey), equals('zh'));

      await settingsService.updateSettings({'language': '  Follow System  '});
      expect(prefs.getString(LocaleNotifier.localeKey), equals('system'));
    });

    test('Invalid or unsupported language codes are rejected with notice without mutating preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocaleNotifier.localeKey, 'zh');

      final invalidCodes = ['klingon', 'elvish', 'invalid_123', 'xyz_99', 'unknown-lang'];

      for (final badCode in invalidCodes) {
        final result = await settingsService.updateSettings({'language': badCode});

        // Preference remains unchanged
        expect(prefs.getString(LocaleNotifier.localeKey), equals('zh'));

        // Result contains notice about unsupported code
        final summary = result['summary'] as String? ?? '';
        expect(summary, contains('不支持的语言代码: $badCode'),
            reason: '$badCode should be reported as unsupported');

        // updatedEntries does not include language
        final updated = result['updated'] as Map<String, dynamic>? ?? {};
        expect(updated.containsKey('language'), isFalse);
      }
    });

    test('getSettings reports current language code', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocaleNotifier.localeKey, 'ja');

      final currentSettings = await settingsService.getSettings();
      expect(currentSettings['language']?['code'], equals('ja'));
    });
  });
}
