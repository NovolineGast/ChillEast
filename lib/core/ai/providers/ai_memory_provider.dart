import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_memory_item.dart';
import '../services/ai_memory_storage.dart';

class AiMemoryNotifier extends StateNotifier<List<AiMemoryItem>> {
  final AiMemoryStorage _storage;

  AiMemoryNotifier({AiMemoryStorage? storage})
      : _storage = storage ?? AiMemoryStorage(),
        super([]) {
    loadMemories();
  }

  Future<void> loadMemories() async {
    final list = await _storage.readMemories();
    state = list;
  }

  Future<void> reloadFromStorage() async {
    await loadMemories();
  }

  Future<AiMemoryItem> addMemory(String content, {String? category}) async {
    final item = await _storage.addMemory(content, category: category);
    await loadMemories();
    return item;
  }

  Future<bool> deleteMemory(String id) async {
    final success = await _storage.deleteMemory(id);
    if (success) {
      await loadMemories();
    }
    return success;
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    state = [];
  }
}

final aiMemoryStorageProvider = Provider<AiMemoryStorage>((ref) {
  return AiMemoryStorage();
});

final aiMemoryProvider =
    StateNotifierProvider<AiMemoryNotifier, List<AiMemoryItem>>((ref) {
  final storage = ref.watch(aiMemoryStorageProvider);
  return AiMemoryNotifier(storage: storage);
});
