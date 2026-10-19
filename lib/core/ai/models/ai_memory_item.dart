class AiMemoryItem {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? category;

  const AiMemoryItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (category != null && category!.isNotEmpty) 'category': category,
      };

  factory AiMemoryItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AiMemoryItem(
      id: json['id'] as String? ?? 'mem_${now.microsecondsSinceEpoch}',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? now
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? now
          : now,
      category: json['category'] as String?,
    );
  }

  AiMemoryItem copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
  }) {
    return AiMemoryItem(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiMemoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
