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

    testWidgets('renders test connection button when not default config', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: const AiSettingsScreen()));
      await tester.pumpAndSettle();

      // Default config: test connection button is hidden
      expect(find.text('测试连接'), findsNothing);

      // Enter a custom API Key so it is not default config
      await tester.enterText(find.byType(TextField).at(2), 'custom_key');
      await tester.pumpAndSettle();

      // Verify Test Connection button exists
      expect(find.text('测试连接'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_tethering_rounded), findsOneWidget);
    });

    testWidgets('tapping test connection without key shows warning snackbar', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: const AiSettingsScreen()));
      await tester.pumpAndSettle();

      // Enter custom apiUrl so it is not default config, but leave apiKey empty
      await tester.enterText(find.byType(TextField).at(0), 'https://custom.api.com/v1');
      await tester.pumpAndSettle();

      final testBtn = find.text('测试连接');
      expect(testBtn, findsOneWidget);
      await tester.tap(testBtn);
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
