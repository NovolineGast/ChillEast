import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/ai/models/ai_memory_item.dart';
import 'package:ChillEast/core/ai/services/ai_memory_storage.dart';
import 'package:ChillEast/core/ai/providers/ai_memory_provider.dart';

void main() {
  late Directory tempDir;
  late AiMemoryStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_memory_test_');
    storage = AiMemoryStorage(baseDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AiMemoryStorage Tests', () {
    test('initially returns empty list', () async {
      final memories = await storage.readMemories();
      expect(memories, isEmpty);
    });

    test('addMemory saves and returns item', () async {
      final item = await storage.addMemory('住在沁苑十栋502', category: 'dorm');
      expect(item.content, '住在沁苑十栋502');
      expect(item.category, 'dorm');

      final readList = await storage.readMemories();
      expect(readList.length, 1);
      expect(readList.first.id, item.id);
      expect(readList.first.content, '住在沁苑十栋502');
    });

    test('addMemory de-duplicates identical content', () async {
      final item1 = await storage.addMemory('习惯上午去图书馆自习');
      final item2 = await storage.addMemory('习惯上午去图书馆自习');

      expect(item1.id, item2.id);
      final readList = await storage.readMemories();
      expect(readList.length, 1);
    });

    test('deleteMemory removes target item', () async {
      final item1 = await storage.addMemory('记忆1');
      final item2 = await storage.addMemory('记忆2');

      final deleted = await storage.deleteMemory(item1.id);
      expect(deleted, isTrue);

      final readList = await storage.readMemories();
      expect(readList.length, 1);
      expect(readList.first.id, item2.id);
    });

    test('clearAll clears all memories', () async {
      await storage.addMemory('记忆1');
      await storage.addMemory('记忆2');
      await storage.clearAll();

      final readList = await storage.readMemories();
      expect(readList, isEmpty);
    });
  });

  group('AiMemoryNotifier Tests', () {
    test('manages state reactively', () async {
      final notifier = AiMemoryNotifier(storage: storage);
      await notifier.loadMemories();
      expect(notifier.state, isEmpty);

      final added = await notifier.addMemory('备考六级', category: 'study');
      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, added.id);

      await notifier.deleteMemory(added.id);
      expect(notifier.state, isEmpty);
    });
  });
}
