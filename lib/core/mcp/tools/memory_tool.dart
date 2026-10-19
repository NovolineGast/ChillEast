import '../../ai/services/ai_memory_storage.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 添加/保存记忆 (add_memory)
class MemoryAddTool {
  static const String toolName = 'add_memory';

  static McpTool create({
    AiMemoryStorage? storage,
    Future<void> Function()? onChanged,
    String toolName = toolName,
  }) {
    final memoryStorage = storage ?? AiMemoryStorage();

    return McpTool(
      name: toolName,
      description:
          '沉淀并保存关于用户的长期记忆。当用户在对话中提到其个人信息（如宿舍楼栋/房间号、学号/专业/年级、常去自习地点、饮食喜好、作息习惯、备考目标、特殊提醒偏好等），或者用户明确要求“记住……”时，必须主动调用本工具将信息保存为记忆，以便后续对话中随时调用。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description':
                '需要沉淀保存的记忆事实或偏好内容（必填，精炼描述，例如“住在沁苑10栋502”、“平时喜欢在图书馆五楼自习”、“备考英语六级”）。',
          },
          'category': {
            'type': 'string',
            'description':
                '记忆分类（可选，如 dorm(宿舍)、preference(喜好习惯)、study(学习备考)、personal(个人信息)、schedule(作息安排) 等）。',
          },
        },
        'required': ['content'],
      },
      handler: (arguments) async {
        final content = arguments['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          return McpToolResult.error('记忆内容不能为空');
        }

        final category = arguments['category'] as String?;
        final saved = await memoryStorage.addMemory(content.trim(), category: category?.trim());

        if (onChanged != null) {
          await onChanged();
        }

        return McpToolResult.json({
          'status': 'success',
          'summary': '已成功记住：「${saved.content}」',
          'memory': saved.toJson(),
        });
      },
    );
  }
}

/// MCP Tool: 查询记忆 (query_memories)
class MemoryQueryTool {
  static const String toolName = 'query_memories';

  static McpTool create({
    AiMemoryStorage? storage,
    String toolName = toolName,
  }) {
    final memoryStorage = storage ?? AiMemoryStorage();

    return McpTool(
      name: toolName,
      description: '查询当前关于用户已保存的长期记忆列表，支持按关键词筛选。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'keyword': {
            'type': 'string',
            'description': '筛选记忆关键词（可选，留空则返回全部记忆）。',
          },
        },
      },
      handler: (arguments) async {
        final keyword = arguments['keyword'] as String?;
        var list = await memoryStorage.readMemories();

        if (keyword != null && keyword.trim().isNotEmpty) {
          final kw = keyword.trim().toLowerCase();
          list = list
              .where((m) =>
                  m.content.toLowerCase().contains(kw) ||
                  (m.category != null && m.category!.toLowerCase().contains(kw)))
              .toList();
        }

        return McpToolResult.json({
          'count': list.length,
          'memories': list.map((m) => m.toJson()).toList(),
        });
      },
    );
  }
}

/// MCP Tool: 删除记忆 (delete_memory)
class MemoryDeleteTool {
  static const String toolName = 'delete_memory';

  static McpTool create({
    AiMemoryStorage? storage,
    Future<void> Function()? onChanged,
    String toolName = toolName,
  }) {
    final memoryStorage = storage ?? AiMemoryStorage();

    return McpTool(
      name: toolName,
      description: '当用户要求遗忘或删除某条记忆时调用本工具。支持按记忆 ID 或内容关键词查找并删除。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '要删除的记忆 ID（如果已知）。',
          },
          'keyword': {
            'type': 'string',
            'description': '若不知道 ID，可提供记忆关键词（如“沁苑10栋502”）。',
          },
        },
      },
      handler: (arguments) async {
        final id = arguments['id'] as String?;
        final keyword = arguments['keyword'] as String?;

        if ((id == null || id.isEmpty) && (keyword == null || keyword.isEmpty)) {
          return McpToolResult.error('必须提供 id 或 keyword 来指定要删除的记忆');
        }

        final list = await memoryStorage.readMemories();
        String? targetId = id;

        if (targetId == null || targetId.isEmpty) {
          final kw = keyword!.trim().toLowerCase();
          final match = list.firstWhere(
            (m) => m.content.toLowerCase().contains(kw),
            orElse: () => throw StateError('not_found'),
          );
          targetId = match.id;
        }

        final success = await memoryStorage.deleteMemory(targetId);
        if (success && onChanged != null) {
          await onChanged();
        }

        if (success) {
          return McpToolResult.json({
            'status': 'success',
            'message': '已成功删除该条记忆',
            'deletedId': targetId,
          });
        } else {
          return McpToolResult.error('未找到要删除的对应记忆');
        }
      },
    );
  }
}
