import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../features/cloudisk/services/cloud_backup_manager.dart';
import '../models/ai_memory_item.dart';

class AiMemoryStorage {
  static const String fileName = 'ai_memories.json';
  final Directory? baseDirectory;

  AiMemoryStorage({this.baseDirectory});

  Future<File> _getFile() async {
    final dir = baseDirectory ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// 读取记忆列表（按创建时间由旧到新）
  Future<List<AiMemoryItem>> readMemories() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded
            .map((e) => AiMemoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 保存完整记忆列表
  Future<void> saveMemories(List<AiMemoryItem> memories) async {
    try {
      final file = await _getFile();
      final jsonList = memories.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      CloudBackupManager.instance.markDirty();
    } catch (_) {}
  }

  /// 添加一条记忆（自动去重并更新时间）
  Future<AiMemoryItem> addMemory(String content, {String? category}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Memory content cannot be empty');
    }

    final current = await readMemories();
    final now = DateTime.now();

    // 检查是否有高度重复或相同内容的已有记忆
    final existingIndex = current.indexWhere(
      (m) => m.content.trim().toLowerCase() == trimmed.toLowerCase(),
    );

    if (existingIndex != -1) {
      final existing = current[existingIndex];
      final updated = existing.copyWith(
        updatedAt: now,
        category: category ?? existing.category,
      );
      current[existingIndex] = updated;
      await saveMemories(current);
      return updated;
    }

    final newItem = AiMemoryItem(
      id: 'mem_${now.millisecondsSinceEpoch}',
      content: trimmed,
      createdAt: now,
      updatedAt: now,
      category: category,
    );

    final updatedList = [...current, newItem];
    await saveMemories(updatedList);
    return newItem;
  }

  /// 根据 ID 删除记忆
  Future<bool> deleteMemory(String id) async {
    final current = await readMemories();
    final initialLen = current.length;
    final filtered = current.where((m) => m.id != id).toList();
    if (filtered.length != initialLen) {
      await saveMemories(filtered);
      return true;
    }
    return false;
  }

  /// 清空全部记忆
  Future<void> clearAll() async {
    await saveMemories([]);
  }
}
