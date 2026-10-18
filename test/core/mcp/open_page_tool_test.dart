import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/mcp/tools/open_page_tool.dart';
import 'package:ChillEast/core/services/app_navigator.dart';

void main() {
  group('OpenPageTool MCP Tests', () {
    test('Tool schema and metadata validation', () {
      final tool = OpenPageTool.create();
      expect(tool.name, 'open_page');
      expect(tool.description.contains('打开应用内的具体页面'), isTrue);

      final schema = tool.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['required'], contains('page'));
      expect((schema['properties'] as Map).containsKey('page'), isTrue);
      expect((schema['properties'] as Map).containsKey('params'), isTrue);
    });

    test('Support alias tool names', () {
      final tool1 = OpenPageTool.create(toolName: 'navigate_to_page');
      expect(tool1.name, 'navigate_to_page');

      final tool2 = OpenPageTool.create(toolName: 'open_screen');
      expect(tool2.name, 'open_screen');
    });

    test('Open page fails when page argument is empty', () async {
      final tool = OpenPageTool.create();
      final result = await tool.execute({'page': '   '});
      expect(result.isError, isTrue);
      expect(result.content.first.text, contains('未指定要打开的页面'));
    });

    test('Open page fails when page identifier is unknown', () async {
      final tool = OpenPageTool.create();
      final result = await tool.execute({'page': 'completely_unknown_page_xyz'});
      expect(result.isError, isTrue);
      expect(result.content.first.text, contains('未知页面'));
      expect(result.content.first.text, contains('score'));
    });

    test('Open valid page with custom navigationHandler', () async {
      String? navigatedPage;
      Map<String, dynamic>? navigatedParams;

      final tool = OpenPageTool.create(
        navigationHandler: (page, {params}) async {
          navigatedPage = page;
          navigatedParams = params;
          return true;
        },
      );

      final result = await tool.execute({
        'page': 'score',
        'params': {'tab': 'latest'},
      });

      expect(result.isError, isFalse);
      expect(navigatedPage, 'score');
      expect(navigatedParams?['tab'], 'latest');

      final text = result.content.first.text ?? '';
      expect(text, contains('成绩查询'));
      expect(text, contains('已成功打开'));
    });

    test('Open page with Chinese aliases', () async {
      final navigatedList = <String>[];

      final tool = OpenPageTool.create(
        navigationHandler: (page, {params}) async {
          navigatedList.add(page);
          return true;
        },
      );

      final tests = [
        {'input': '课表', 'expectedId': 'timetable', 'expectedTitle': '课表'},
        {'input': '查成绩', 'expectedId': 'score', 'expectedTitle': '成绩查询'},
        {'input': '图书馆', 'expectedId': 'library', 'expectedTitle': '图书馆'},
        {'input': '图书检索', 'expectedId': 'library_search', 'expectedTitle': '图书检索'},
        {'input': '电费充值', 'expectedId': 'electricity_recharge', 'expectedTitle': '电费充值'},
        {'input': '通知设置', 'expectedId': 'notification_settings', 'expectedTitle': '通知提醒设置'},
        {'input': '课表设置', 'expectedId': 'timetable_settings', 'expectedTitle': '课表设置'},
        {'input': '语言设置', 'expectedId': 'language_settings', 'expectedTitle': '语言设置'},
        {'input': 'AI助理设置', 'expectedId': 'ai_settings', 'expectedTitle': 'AI 助理设置'},
        {'input': 'AI记忆', 'expectedId': 'ai_memory', 'expectedTitle': 'AI 记忆管理'},
      ];

      for (final t in tests) {
        final result = await tool.execute({'page': t['input']});
        expect(result.isError, isFalse);
        final text = result.content.first.text ?? '';
        expect(text, contains(t['expectedTitle']!));
      }

      expect(navigatedList.length, tests.length);
    });

    test('Handles navigationHandler failure gracefully', () async {
      final tool = OpenPageTool.create(
        navigationHandler: (page, {params}) async => false,
      );

      final result = await tool.execute({'page': 'settings'});
      expect(result.isError, isTrue);
      expect(result.content.first.text, contains('打开「设置主页」页面失败'));
    });

    test('AppNavigator normalizes and creates widgets correctly', () {
      expect(AppNavigator.normalizePageId('home'), 'home');
      expect(AppNavigator.normalizePageId('主页'), 'home');
      expect(AppNavigator.normalizePageId('课表页面'), 'timetable');
      expect(AppNavigator.normalizePageId('成绩查询界面'), 'score');

      final info = AppNavigator.getPageInfo('notification_settings');
      expect(info, isNotNull);
      expect(info!.title, '通知提醒设置');

      final searchWidget = AppNavigator.createScreenWidget('library_search', {'keyword': '计算机网络'});
      expect(searchWidget, isNotNull);
    });
  });
}
