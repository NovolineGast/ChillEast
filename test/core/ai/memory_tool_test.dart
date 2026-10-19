import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/ai/services/ai_memory_storage.dart';
import 'package:ChillEast/core/mcp/tools/memory_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late AiMemoryStorage storage;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('memory_tool_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => testDir.path,
    );
    storage = AiMemoryStorage(baseDirectory: testDir);
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('Memory MCP Tools', () {
    test('MemoryAddTool saves a memory and returns confirmation', () async {
      final tool = MemoryAddTool.create(storage: storage);
      expect(tool.name, 'add_memory');

      final res = await tool.execute({
        'content': '用户住在东湖校区10栋502',
        'category': 'dormitory',
      });

      expect(res.isError, isFalse);
      final json = jsonDecode(res.content.first.text!) as Map<String, dynamic>;
      expect(json['status'], 'success');
      expect(json['memory']['category'], 'dormitory');
      expect(json['memory']['content'], '用户住在东湖校区10栋502');

      final all = await storage.readMemories();
      expect(all.length, 1);
      expect(all.first.content, '用户住在东湖校区10栋502');
      expect(all.first.category, 'dormitory');
    });

    test('MemoryQueryTool queries memories with or without filter', () async {
      await storage.addMemory('喜欢在二食堂吃饭', category: 'preference');
      await storage.addMemory('目标是考过六级', category: 'study');

      final queryTool = MemoryQueryTool.create(storage: storage);
      expect(queryTool.name, 'query_memories');

      final allRes = await queryTool.execute({});
      expect(allRes.isError, isFalse);
      final allJson = jsonDecode(allRes.content.first.text!) as Map<String, dynamic>;
      expect(allJson['count'], 2);

      final filterRes = await queryTool.execute({'keyword': '六级'});
      expect(filterRes.isError, isFalse);
      final filterJson = jsonDecode(filterRes.content.first.text!) as Map<String, dynamic>;
      expect(filterJson['count'], 1);
      expect((filterJson['memories'] as List).first['content'], '目标是考过六级');
    });

    test('MemoryDeleteTool deletes memory by id or exact content', () async {
      final item = await storage.addMemory('经常晚上11点睡觉', category: 'habit');
      final deleteTool = MemoryDeleteTool.create(storage: storage);
      expect(deleteTool.name, 'delete_memory');

      final res = await deleteTool.execute({'id': item.id});
      expect(res.isError, isFalse);
      final json = jsonDecode(res.content.first.text!) as Map<String, dynamic>;
      expect(json['status'], 'success');
      expect(json['deletedId'], item.id);

      final remaining = await storage.readMemories();
      expect(remaining.isEmpty, isTrue);
    });
  });
}
