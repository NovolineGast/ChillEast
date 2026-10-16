import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/ai/models/ai_memory_item.dart';
import '../../../core/ai/providers/ai_memory_provider.dart';

class AiMemoryScreen extends ConsumerWidget {
  const AiMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF09C489);
    final memories = ref.watch(aiMemoryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Agent 记忆',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          if (memories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空所有记忆',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemoryDialog(context, ref),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加记忆', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: memories.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: memories.length,
              itemBuilder: (context, index) {
                // 最新的记忆排在前面
                final memory = memories[memories.length - 1 - index];
                return _buildMemoryCard(context, ref, memory, isDark);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[350],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无长期记忆',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在对话中提到您的宿舍、日常偏好、作息习惯或备考目标，Agent 会更主动为您添加并沉淀记忆；您也可以随时在此查看和删除记忆。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(
    BuildContext context,
    WidgetRef ref,
    AiMemoryItem item,
    bool isDark,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final dateStr = dateFormat.format(item.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.15),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.category != null && item.category!.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09C489).withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.category!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF09C489),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white38 : Colors.grey[500],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteMemory(context, ref, item),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            item.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF202124),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMemory(
    BuildContext context,
    WidgetRef ref,
    AiMemoryItem item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆', style: TextStyle(fontSize: 16)),
        content: Text('确定删除记忆「${item.content}」吗？删除后 Agent 将不再调用该信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(aiMemoryProvider.notifier).deleteMemory(item.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已删除该记忆'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有记忆', style: TextStyle(fontSize: 16)),
        content: const Text('确定清空所有沉淀的 Agent 长期记忆吗？此操作不可逆。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(aiMemoryProvider.notifier).clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已清空所有记忆'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('清空全部', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddMemoryDialog(BuildContext context, WidgetRef ref) {
    final contentController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加长期记忆', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contentController,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: '如：住在沁苑10栋502、备考六级、喜欢在总馆自习',
                labelText: '记忆内容',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                hintText: '如：宿舍 / 偏好 / 备考 / 个人 (可选)',
                labelText: '分类',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final text = contentController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final cat = categoryController.text.trim();
              await ref.read(aiMemoryProvider.notifier).addMemory(
                    text,
                    category: cat.isNotEmpty ? cat : null,
                  );
            },
            child: const Text('保存', style: TextStyle(color: Color(0xFF09C489))),
          ),
        ],
      ),
    );
  }
}
