import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/ai/ai_service.dart';
import 'package:ChillEast/features/profile/screens/ai_settings_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiAssistantService normalizeModelsUrl Tests', () {
    test('default URL normalizes to /models', () {
      final url = AiAssistantService.normalizeModelsUrl(null);
      expect(url, equals('${AiAssistantService.defaultApiUrl}/models'));
    });

    test('strips /chat/completions and appends /models', () {
      final url = AiAssistantService.normalizeModelsUrl(
        'https://api.openai.com/v1/chat/completions',
      );
      expect(url, equals('https://api.openai.com/v1/models'));
    });

    test('handles trailing slashes', () {
      final url = AiAssistantService.normalizeModelsUrl(
        'https://api.deepseek.com/v1///',
      );
      expect(url, equals('https://api.deepseek.com/v1/models'));
    });

    test('preserves already normalized /models URL', () {
      final url = AiAssistantService.normalizeModelsUrl(
        'https://api.siliconflow.cn/v1/models',
      );
      expect(url, equals('https://api.siliconflow.cn/v1/models'));
    });
  });

  group('AiSettingsScreen UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildTestWidget({required Widget child}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );
    }

    testWidgets('renders test connection button and model fetch chip', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: const AiSettingsScreen()));
      await tester.pumpAndSettle();

      // Verify Test Connection button exists
      expect(find.text('测试联通'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_tethering_rounded), findsOneWidget);

      // Verify Model Fetch chip exists
      expect(find.text('获取模型列表'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    });

    testWidgets('tapping test connection without key shows warning snackbar', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: const AiSettingsScreen()));
      await tester.pumpAndSettle();

      final testBtn = find.text('测试联通');
      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      expect(find.text('请先配置 API Key'), findsOneWidget);
    });

    testWidgets('tapping fetch models without key shows warning snackbar', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: const AiSettingsScreen()));
      await tester.pumpAndSettle();

      final fetchChip = find.text('获取模型列表');
      await tester.tap(fetchChip);
      await tester.pumpAndSettle();

      expect(find.text('请先配置 API Key'), findsOneWidget);
    });
  });

  group('AiAssistantService validation tests', () {
    test('fetchModels throws when apiKey is empty', () async {
      final service = AiAssistantService();
      expect(
        () => service.fetchModels(apiKey: ''),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('未配置 API Key'),
        )),
      );
    });

    test('testConnection throws when apiKey is empty', () async {
      final service = AiAssistantService();
      expect(
        () => service.testConnection(apiKey: ''),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('未配置 API Key'),
        )),
      );
    });
  });
}
