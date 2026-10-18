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

    test('concurrent saveMemories calls are serialized by write queue without corrupting JSON', () async {
      // Fire 25 concurrent save operations
      final futures = <Future<void>>[];
      for (int i = 0; i < 25; i++) {
        final batch = List.generate(
          i + 1,
          (idx) => AiMemoryItem(
            id: 'mem_${i}_$idx',
            content: 'Concurrent item $i-$idx',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        futures.add(storage.saveMemories(batch));
      }

      await Future.wait(futures);

      // Verify that the file exists and contains valid JSON with the final batch count
      final read = await storage.readMemories();
      expect(read.isNotEmpty, isTrue);
      // The last write had 25 items (0..24)
      expect(read.length, equals(25));
      expect(read.last.content, equals('Concurrent item 24-24'));
    });

    test('write queue continues processing subsequent tasks reliably', () async {
      // Test sequential queue execution when mixed with empty clearAll
      final op1 = storage.addMemory('第一条');
      final op2 = storage.clearAll();
      final op3 = storage.addMemory('第二条');

      await Future.wait([op1, op2, op3]);

      final read = await storage.readMemories();
      expect(read.length, equals(1));
      expect(read.first.content, equals('第二条'));
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
